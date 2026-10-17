#!/usr/bin/env python3
"""Host-side bootstrap and a fail-closed ai-jail -> ai-memory -> CLI launcher.

Requires Python 3.11+. No third-party Python dependencies. Never reads auth.json
or prints credential values. Configuration writes are atomic, backed up, and
limited to known fields. AI installation is Linux only; no macOS dotfiles
are replaced.
"""

import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import socket
import stat
import subprocess
import sys
import tarfile
import tempfile
import tomllib
import urllib.request
import urllib.parse

REPO = Path(__file__).resolve().parent.parent
HOME = Path.home()
CONFIG = HOME / ".config/ai-stack"
MEMORY = HOME / ".local/share/ai-memory"
# Keep writable client caches/spools separate from the native executable and
# the host server's data. ai-jail rejects overlapping RO/RW map destinations.
CLIENT = HOME / ".local/share/ai-stack/memory"
ROOTS = (HOME / "Dev/sympla", HOME / "Documents/gcrm/Linear")
VERSIONS = json.loads((REPO / "ai/versions.json").read_text())
DRY = False


def fail(message):
  raise RuntimeError(message)


def announce(message):
  print(message, flush=True)


def run(args, **kwargs):
  # Commands logged here contain paths/options, never tokens.
  announce(("[preview] " if DRY else "[run] ") + shlex.join(map(str, args)))
  if not DRY:
    return subprocess.run(list(map(str, args)), check=True, **kwargs)


def exec_or_preview(command):
  if DRY:
    # ai-jail's own --dry-run prints resolved --setenv values, including secrets.
    # Preview our names-only invocation instead of asking it to dump the env.
    announce("[preview; environment values not expanded] " + shlex.join(command))
    return
  os.execv(command[0], command)


def backup(path):
  stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
  target = HOME / ".local/state/dotfiles/backups" / stamp / path.relative_to(HOME)
  target.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
  shutil.copy2(path, target)
  target.chmod(0o600)


def write(path, content, mode=0o600):
  if path.exists() and path.read_text() == content:
    return
  if path.is_symlink():
    # Updating through a symlink could write outside HOME or modify the repo.
    fail(f"Refusing to replace symlinked config: {path}")
  announce(f"{'[preview]' if DRY else '[write]'} {path}")
  if DRY:
    return
  path.parent.mkdir(parents=True, exist_ok=True)
  if path.exists():
    backup(path)
    mode = stat.S_IMODE(path.stat().st_mode) & 0o600
  fd, name = tempfile.mkstemp(prefix=".dotfiles-", dir=path.parent)
  try:
    os.fchmod(fd, mode)
    with os.fdopen(fd, "w") as stream:
      stream.write(content)
    os.replace(name, path)
  finally:
    if os.path.exists(name):
      os.unlink(name)


def link(source, target):
  if target.is_symlink() and target.resolve() == source.resolve():
    return
  if target.exists() or target.is_symlink():
    fail(f"Conflicting path (preserved): {target}; move it aside before configuring")
  announce(f"{'[preview]' if DRY else '[link]'} {target} -> {source}")
  if not DRY:
    target.parent.mkdir(parents=True, exist_ok=True)
    target.symlink_to(source, target_is_directory=source.is_dir())


def json_write(path, data):
  write(path, json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def load_json(path):
  # JSONC is intentionally not rewritten with a lossy parser.
  return json.loads(path.read_text()) if path.exists() else {}


def native_memory():
  candidates = [MEMORY / "native-runner/ai-memory"]
  exe = shutil.which("ai-memory")
  if exe:
    candidates.append(Path(exe))
  for path in candidates:
    if path.is_file() and os.access(path, os.X_OK):
      with path.open("rb") as stream:
        if stream.read(4) == b"\x7fELF":
          return path.resolve()
  fail("Native ai-memory client missing. Run setup.sh ai install on the host first.")


def endpoint_key(server):
  return server.get("url", "").split("?", 1)[0].rstrip("/")


def server_name(servers, canonical, definition):
  matches = [name for name, server in servers.items()
             if isinstance(server, dict) and endpoint_key(server) == endpoint_key(definition)]
  if len(matches) > 1:
    fail(f"Multiple MCP entries for {canonical}; resolve duplicates first")
  if matches:
    return matches[0]
  # Keep casing/identifiers that permission rules and cached OAuth may use.
  matches = [name for name in servers if name.lower().replace("-lpm", "") == canonical]
  if len(matches) > 1:
    fail(f"Ambiguous MCP name: {canonical}")
  return matches[0] if matches else canonical


def replace_toml_table(text, table, values):
  lines = text.splitlines(keepends=True)
  start = None
  end = len(lines)
  for index, line in enumerate(lines):
    match = re.match(r"^\s*\[([^\[\]]+)\]\s*(?:#.*)?$", line.strip())
    if match:
      # Our server names contain only bare TOML key characters.
      if match[1] == table:
        start = index
      elif start is not None:
        end = index
        break
  block = f"[{table}]\n" + "".join(f"{key} = {json.dumps(value)}\n" for key, value in values.items()) + "\n"
  if start is None:
    return text.rstrip() + "\n\n" + block
  return "".join(lines[:start]) + block + "".join(lines[end:])


def configure_mcp():
  manifest = load_json(REPO / "ai/mcp-servers.json")
  jsonc = HOME / ".config/opencode/opencode.jsonc"
  if jsonc.exists() and re.search(r'"mcp"\s*:', jsonc.read_text()):
    fail(f"MCP definitions also exist in {jsonc}; reconcile them before applying the manifest")
  paths = {"opencode": HOME / ".config/opencode/opencode.json",
           "kimi": HOME / ".kimi-code/mcp.json"}
  for harness, path in paths.items():
    data = load_json(path)
    if harness == "opencode":
      data.setdefault("$schema", "https://opencode.ai/config.json")
      mcp = data.setdefault("mcp", {})
      if any(key not in {"servers", "timeout"} for key in mcp):
        fail(f"MCP V1 migration needed in {path}; refusing to guess")
      servers = mcp.setdefault("servers", {})
    else:
      servers = data.setdefault("mcpServers", {})
    for canonical, definition in manifest.items():
      name = server_name(servers, canonical, definition)
      server = servers.setdefault(name, {})
      server["url"] = definition.get("kimi_url", definition["url"]) if harness == "kimi" else definition["url"]
      if harness == "opencode":
        server["type"] = "remote"
        if canonical == "ai-memory":
          server["oauth"] = False
    json_write(path, data)

  path = HOME / ".codex/config.toml"
  text = path.read_text() if path.exists() else ""
  data = tomllib.loads(text)
  servers = data.get("mcp_servers", {})
  for canonical, definition in manifest.items():
    name = server_name(servers, canonical, definition)
    if not re.fullmatch(r"[A-Za-z0-9_-]+", name):
      fail(f"Unsupported quoted Codex server name: {name}")
    old = servers.get(name, {})
    if old.get("url") == definition["url"]:
      continue
    # Preserve arbitrary fields by editing only the URL inside this table.
    if any(isinstance(v, dict) for v in old.values()):
      fail(f"Nested Codex server settings need manual review: {name}")
    text = replace_toml_table(text, f"mcp_servers.{name}", {**old, "url": definition["url"]})
  tomllib.loads(text)
  write(path, text)


def import_skills():
  source = HOME / ".config/opencode/skills"
  target = REPO / "ai/skills"
  for skill in sorted(source.iterdir()) if source.exists() else []:
    if not skill.is_dir() or not (skill / "SKILL.md").is_file():
      continue
    if skill.is_symlink():
      continue
    dest = target / skill.name
    if dest.exists():
      continue
    if any(p.is_symlink() for p in skill.rglob("*")):
      fail(f"Inspect skill symlinks before importing: {skill}")
    announce(f"{'[preview]' if DRY else '[import]'} unchanged skill: {skill.name}")
    if not DRY:
      shutil.copytree(skill, dest)


def configure_skills():
  shared = CONFIG / "skills"
  canonical = REPO / "ai/skills"
  for skill in sorted(canonical.iterdir()):
    if skill.is_dir() and (skill / "SKILL.md").is_file():
      link(skill, shared / skill.name)
  roots = [HOME / ".config/opencode/skills", HOME / ".codex/skills", HOME / ".kimi-code/skills"]
  # Use per-skill links. Do not delete built-ins or unrelated local skills.
  skills = {p.name: p for p in shared.iterdir()} if shared.exists() else {}
  skills.update({p.name: shared / p.name for p in canonical.iterdir() if p.is_dir()})
  for name, skill in sorted(skills.items()):
    if not ((skill / "SKILL.md").is_file() or (canonical / name / "SKILL.md").is_file()):
      continue
    for root in roots:
      dest = root / name
      if dest.exists() and not dest.is_symlink():
        # Only adopt an existing directory when every byte matches canonical.
        original = canonical / name
        files = lambda p: {str(f.relative_to(p)): f.read_bytes() for f in p.rglob("*") if f.is_file()}
        if not original.is_dir() or files(original) != files(dest):
          fail(f"Different local skill preserved: {dest}")
        announce(f"{'[preview]' if DRY else '[adopt]'} {dest}")
        if not DRY:
          stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
          saved = HOME / ".local/state/dotfiles/backups" / stamp / dest.relative_to(HOME)
          saved.parent.mkdir(parents=True, exist_ok=True)
          shutil.move(dest, saved)
        else:
          continue
      link(skill, dest)


def configure_shell():
  link(REPO, CONFIG / "repo")
  source = REPO / "chezmoi/dot_config/ai-stack/ai-stack.zsh"
  target = CONFIG / "ai-stack.zsh"
  # chezmoi owns this fragment on the new path. Keep the old configure command
  # useful during migration, but do not compete with an installed chezmoi.
  if not shutil.which("chezmoi") and not target.exists():
    write(target, source.read_text(), mode=0o644)
  path = HOME / ".zshrc"
  text = path.read_text() if path.exists() else ""
  # Only retire the two known broad legacy launch aliases.
  text = re.sub(r"^alias jail-(?:spec|code)=.*\n?", "", text, flags=re.M)
  marker = "# dotfiles: managed AI launchers"
  text = text.replace('source "$HOME/.config/ai-stack/repo/ai/ai-stack.zsh"',
                      'source "$HOME/.config/ai-stack/ai-stack.zsh"')
  if marker not in text:
    text = text.rstrip() + f'\n\n{marker}\n[[ ! -f "$HOME/.config/ai-stack/ai-stack.zsh" ]] || source "$HOME/.config/ai-stack/ai-stack.zsh"\n'
  write(path, text)


def clean_legacy_jails():
  # Only clean the three previously reviewed personal configs. Preserve any
  # masks/denies/other policy fields, and never scan/rewrite nested repositories.
  keys = {"command", "rw_maps", "network", "ssh", "private_home", "terminal_passthrough", "agent_state"}
  for path in [HOME / ".ai-jail", *(root / ".ai-jail" for root in ROOTS)]:
    if not path.exists():
      continue
    text = path.read_text()
    data = tomllib.loads(text)
    if set(data) - keys:
      fail(f"Extra ai-jail policy preserved; review manually: {path}")
    allowed = {str(p) for p in ROOTS} | {str(HOME / ".kimi-code")}
    if any(str(Path(p).expanduser()) not in allowed for p in data.get("rw_maps", [])):
      fail(f"Unrecognized ai-jail maps preserved: {path}")
    write(path, '# Personal launches are managed by ~/.config/ai-stack/repo.\n# Project files may still add stricter masks/denies in individual checkouts.\n')


def wire_hooks():
  native = native_memory()
  state_path = CONFIG / "hooks-state.json"
  state = load_json(state_path)
  outputs = {"codex": HOME / ".codex/hooks.json", "kimi-code": HOME / ".kimi-code/config.toml",
             "opencode2": HOME / ".config/opencode/plugins/ai-memory-opencode2.ts"}
  digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else ""
  version = subprocess.check_output([native, "--version"], text=True).strip()
  env = {**os.environ, "AI_MEMORY_DATA_DIR": str(CLIENT), "AI_MEMORY_SERVER_URL": "http://127.0.0.1:49374"}
  token = MEMORY / "native-runner/server-token"
  if token.is_file():
    env["AI_MEMORY_AUTH__BEARER_TOKEN_FILE"] = str(token)
  for agent, path in outputs.items():
    expected = {"version": version, "hash": digest(path), "client": str(CLIENT)}
    if expected["hash"] and state.get(agent) == expected:
      continue
    run([native, "install-hooks", "--agent", agent, "--apply", "--server-url", env["AI_MEMORY_SERVER_URL"]], env=env)
    if not DRY:
      state[agent] = {"version": version, "hash": digest(path), "client": str(CLIENT)}
  run([native, "install-skills", "--target-dir", CONFIG / "skills"], env=env)
  if not DRY:
    json_write(state_path, state)


def configure(args):
  # Compatibility for the pre-chezmoi AI setup. In the new workflow, chezmoi
  # is the only owner of this config file.
  if not shutil.which("chezmoi"):
    configure_usagebar()
  if args.import_skills:
    import_skills()
  configure_mcp()
  configure_shell()
  if args.clean_legacy_jails:
    clean_legacy_jails()
  if args.hooks:
    wire_hooks()
  if not DRY:
    CLIENT.mkdir(parents=True, exist_ok=True)
  configure_skills()
  announce("Configured. Host-side login: command codex login; command kimi login; command opencode auth login; glab auth login --git-protocol https.")
  announce("For MCP OAuth: use each native CLI on the host (OpenCode: /mcps). Then start a new zsh.")


def download_release(repo, tag, asset, target, binary_name):
  if DRY:
    announce(f"[preview] Download/check SHA256: {repo}@{tag}/{asset} -> {target}")
    return
  base = f"https://github.com/{repo}/releases/download/{urllib.parse.quote(tag, safe='')}/{asset}"
  with tempfile.TemporaryDirectory(prefix="dotfiles-download-") as tmp:
    archive = Path(tmp) / asset
    urllib.request.urlretrieve(base, archive)
    checksum = urllib.request.urlopen(base + ".sha256", timeout=30).read().decode().split()[0]
    if not re.fullmatch("[a-fA-F0-9]{64}", checksum) or hashlib.sha256(archive.read_bytes()).hexdigest() != checksum.lower():
      fail(f"Checksum mismatch: {asset}")
    with tarfile.open(archive) as tar:
      members = [m for m in tar.getmembers() if Path(m.name).name == binary_name and m.isfile()]
      if len(members) != 1:
        fail(f"Ambiguous binary in archive: {asset}")
      payload = tar.extractfile(members[0]).read()
      hooks = []
      if binary_name == "ai-memory":
        for member in tar.getmembers():
          parts = Path(member.name).parts
          if member.isfile() and parts and parts[0] == "hooks" and ".." not in parts:
            hooks.append((Path(*parts), tar.extractfile(member).read()))
    if target.exists():
      fail(f"Will not overwrite an installed executable: {target}")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(payload)
    target.chmod(0o755)
    for relative, contents in hooks:
      hook = target.parent / relative
      if hook.exists():
        fail(f"Existing hook file preserved: {hook}")
      hook.parent.mkdir(parents=True, exist_ok=True)
      hook.write_bytes(contents)
      hook.chmod(0o700)


def install(args):
  if platform.system() != "Linux" or platform.machine() not in {"x86_64", "aarch64"}:
    fail("AI CLI installer currently supports Linux x86_64/arm64 only")
  ensure_node()
  if DRY and not shutil.which("npm"):
    announce("[preview] Remaining tools will be installed after nvm provisions Node/npm; rerun without --dry-run to install")
    return
  if not shutil.which("npm"):
    fail("nvm did not provide npm; check your existing nvm default version")
  major = int(subprocess.check_output(["node", "-p", "process.versions.node.split('.')[0]"], text=True))
  if major < 20:
    fail("Node.js 20+ required")
  local_bin = HOME / ".local/bin"
  x86 = platform.machine() == "x86_64"
  rust_arch = "x86_64" if x86 else "aarch64"
  arch = "x64" if x86 else "arm64"
  if not shutil.which("ai-jail"):
    if x86:
      download_release("akitaonrails/ai-jail", "v" + VERSIONS["ai-jail"], f"ai-jail-linux-{rust_arch}.tar.gz", local_bin / "ai-jail", "ai-jail")
    elif shutil.which("cargo"):
      run(["cargo", "install", "ai-jail", "--version", VERSIONS["ai-jail"], "--locked"])
    else:
      fail("ai-jail has no pinned arm64 release asset; install cargo via Ansible and retry")
  try:
    native_memory()
  except RuntimeError:
    target = MEMORY / "native-runner/ai-memory"
    download_release("akitaonrails/ai-memory", "v" + VERSIONS["ai-memory"], f"ai-memory-linux-{rust_arch}.tar.gz", target, "ai-memory")
    if not shutil.which("ai-memory"):
      link(target, local_bin / "ai-memory")
  if not shutil.which("kimi"):
    download_release("MoonshotAI/kimi-code", "@moonshot-ai/kimi-code@" + VERSIONS["kimi"], f"kimi-code-linux-{arch}.tar.gz", HOME / ".kimi-code/bin/kimi", "kimi")
  for tool, package in [("codex", "@openai/codex"), ("opencode", "@opencode/cli")]:
    if not shutil.which(tool):
      run(["npm", "install", "--global", "--prefix", HOME / ".local", f"{package}@{VERSIONS[tool]}"])
  if not shutil.which("ai-usagebar"):
    download_release("akitaonrails/ai-usagebar", "v" + VERSIONS["ai-usagebar"], f"ai-usagebar-linux-{rust_arch}.tar.gz", local_bin / "ai-usagebar", "ai-usagebar")
  announce("Existing tools were not upgraded. Run configure, server (only if needed), then check.")


def configure_usagebar():
  source = REPO / "chezmoi/dot_config/ai-usagebar/private_config.toml"
  # Reviewable template carries preferences and env references, not auth data.
  data = tomllib.loads(source.read_text())
  def validate(value):
    if isinstance(value, dict):
      for key, child in value.items():
        if re.search(r"(?:^|_)(?:api_key|token|secret|password)$", key):
          fail("Inline secret field in tracked usagebar config; use an environment reference instead")
        validate(child)
    elif isinstance(value, list):
      for child in value:
        validate(child)
  validate(data)
  target = HOME / ".config/ai-usagebar/config.toml"
  if target.exists():
    if tomllib.loads(target.read_text()) != data:
      announce(f"[keep] Local ai-usagebar settings differ; preserved: {target}")
    return
  write(target, source.read_text())


def ensure_node():
  nvm = Path(os.environ.get("NVM_DIR", str(HOME / ".nvm"))).expanduser()
  fresh = not (nvm / "nvm.sh").is_file()
  if fresh:
    if nvm.exists():
      fail(f"Existing nvm directory has no nvm.sh; preserved for manual review: {nvm}")
    announce(f"{'[preview]' if DRY else '[install]'} nvm {VERSIONS['nvm']} -> {nvm}")
    if not DRY:
      url = f"https://api.github.com/repos/nvm-sh/nvm/tarball/v{VERSIONS['nvm']}"
      with tempfile.TemporaryDirectory(prefix="dotfiles-nvm-") as tmp:
        archive = Path(tmp) / "nvm.tar.gz"
        urllib.request.urlretrieve(url, archive)
        if hashlib.sha256(archive.read_bytes()).hexdigest() != VERSIONS["nvm_archive_sha256"]:
          fail("nvm archive checksum mismatch")
        extract = Path(tmp) / "extract"
        with tarfile.open(archive) as tar:
          tar.extractall(extract, filter="data")
        entries = list(extract.iterdir())
        if len(entries) != 1 or not (entries[0] / "nvm.sh").is_file():
          fail("Unexpected nvm archive layout")
        nvm.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(entries[0], nvm)
  # Keep an existing active Node and existing nvm defaults unchanged. On a new
  # install, nvm verifies the Node download and creates a pinned default alias.
  if fresh or not shutil.which("node") or not shutil.which("npm"):
    script = '. "$1/nvm.sh"; nvm install "$2"; '
    if fresh:
      script += 'nvm alias default "$2"; '
    run(["bash", "-ec", script, "dotfiles", nvm, VERSIONS["node"]], env={**os.environ, "NVM_DIR": str(nvm)})
    if not DRY:
      node = subprocess.check_output(["bash", "-ec", '. "$1/nvm.sh"; nvm which default', "dotfiles", nvm],
                                     text=True, env={**os.environ, "NVM_DIR": str(nvm)}).strip()
      os.environ["PATH"] = str(Path(node).parent) + os.pathsep + os.environ.get("PATH", "")
  # Subsequent installs in this process must see newly installed CLI binaries.
  os.environ["PATH"] = os.environ.get("PATH", "") + os.pathsep + os.pathsep.join(str(HOME / p) for p in [".local/bin", ".kimi-code/bin"])


def server(args):
  try:
    with socket.create_connection(("127.0.0.1", 49374), timeout=2):
      announce("A service already listens on 127.0.0.1:49374. Leaving it untouched; verify with check.")
      return
  except OSError:
    pass
  wrapper = shutil.which("ai-memory")
  if wrapper:
    with Path(wrapper).open("rb") as stream:
      if stream.read(2) == b"#!":
        fail("Existing ai-memory wrapper deployment is offline. Start its host server; refusing to create a second native server")
  # Native setup owns service creation and its approval prompt. No Docker in jail.
  run([native_memory(), "setup", "--agent", "codex", "--agent", "kimi-code", "--agent", "opencode2"])


def launch_command(harness, native_args, here=False):
  if platform.system() != "Linux":
    fail("Managed sandbox launcher currently targets Linux")
  cwd = Path.cwd().resolve()
  if here:
    broad_paths = {Path("/"), Path("/tmp"), Path("/var"), Path("/usr"), Path("/etc"),
                   Path("/opt"), Path("/mnt"), Path("/media"), Path("/run"),
                   Path("/proc"), Path("/sys"), Path("/dev"), HOME}
    if cwd in broad_paths or cwd in HOME.parents:
      fail("jail-here refuses HOME, its ancestors, and broad system directories; choose a specific project directory")
    if any(cwd == root or cwd in root.parents for root in ROOTS):
      fail("jail-here refuses a parent of a configured workspace; choose a specific project directory")
    roots = [cwd]
  else:
    roots = [root.resolve(strict=True) for root in ROOTS]
    if any(root == HOME or root in HOME.parents for root in roots):
      fail("Workspace resolves to HOME or an ancestor; refusing broad writable access")
    if not any(cwd == root or root in cwd.parents for root in roots):
      fail("Start inside ~/Dev/sympla or ~/Documents/gcrm/Linear (or a subdirectory), never HOME")
  harness = "opencode" if harness == "opencode2" else harness
  native = native_memory()
  tool = shutil.which(harness)
  jail = shutil.which("ai-jail")
  if not tool or not jail:
    fail(f"Missing ai-jail or {harness}; run install first")
  tool = Path(tool).resolve()
  flags = [jail, "--private-home", "--no-agent-state", "--no-network", "--no-inherit-env",
           "--no-ssh", "--no-docker", "--no-systemd-user", "--no-toolchains", "--no-mise",
           "--no-terminal-passthrough", "--no-save-config", "--forward-port", "49374"]
  # Forward names only, never literal secret values in argv or tracked config.
  # glab's active credential may be in the host environment rather than YAML.
  if os.environ.get("GITLAB_TOKEN"):
    flags += ["--env", "GITLAB_TOKEN"]
  elif os.environ.get("OAUTH_TOKEN"):
    flags += ["--env", "OAUTH_TOKEN"]
  if os.environ.get("AI_MEMORY_AUTH_TOKEN"):
    flags += ["--env", "AI_MEMORY_AUTH_TOKEN"]
  api_keys = {"codex": ["OPENAI_API_KEY"], "kimi": ["MOONSHOT_API_KEY"], "opencode": ["OPENAI_API_KEY"]}
  for key in api_keys[harness]:
    if os.environ.get(key):
      flags += ["--env", key]
  for line in (REPO / "ai/allowed-hosts.txt").read_text().splitlines():
    host = line.split("#", 1)[0].strip()
    if host:
      if not re.fullmatch(r"[a-z0-9]+(?:[.-][a-z0-9]+)*", host):
        fail("Invalid allowlist hostname")
      flags += ["--allow-host", host]

  def mount(path, writable=False):
    if path.exists():
      flags.extend(["--rw-map" if writable else "--map", str(path)])

  for root in roots:
    mount(root, True)
  mount(CLIENT, True)
  mount(MEMORY / "native-runner")
  mount(MEMORY / "hooks")
  mount(native.parent)
  jail_tool = tool
  if harness == "kimi" and HOME / ".kimi-code" in tool.parents:
    # Kimi installs its binary *inside* its writable state root. Put the binary
    # at an independent RO destination and deny the original bin directory;
    # otherwise an RO bin/ map would cause ai-jail to drop the entire RW state.
    jail_tool = Path("/tmp/.ai-stack-kimi")
    flags += ["--map", f"{tool}:{jail_tool}", "--deny-path", str(tool.parent)]
  else:
    mount(tool.parent)
  if "node_modules" in tool.parts:
    index = tool.parts.index("node_modules")
    # Include the whole package (vendor binaries, JS imports, dependencies),
    # not only its bin/ entry point. Scoped npm packages have two name parts.
    length = index + (3 if tool.parts[index + 1].startswith("@") else 2)
    mount(Path(*tool.parts[:length]))
  mount(CONFIG)
  mount(REPO / "ai/skills")
  # Codex's npm launcher needs both Node and its complete installed package.
  node = shutil.which("node")
  if node:
    node = Path(node).resolve()
    mount(node.parent.parent)
  states = {"codex": [HOME / ".codex"], "kimi": [HOME / ".kimi-code"],
            "opencode": [HOME / ".config/opencode", HOME / ".local/share/opencode", HOME / ".local/state/opencode", HOME / ".cache/opencode"]}
  for path in states[harness]:
    mount(path, True)
  # Skill links resolve to read-only CONFIG/repo mounts. Do not add a nested
  # RO mount under the RW state root: ai-jail rejects BOTH overlapping maps.
  glab_config = HOME / ".config/glab-cli"
  if glab_config.is_dir():
    flags += ["--map", f"{glab_config}:/tmp/.ai-stack-glab-source"]
  flags += ["--map", f"{REPO / 'ai/sandbox-entry.sh'}:/tmp/.ai-stack-entry.sh"]
  # A jail-local Git config replaces the host config so HTTPS credentials and
  # rewrites never change host repos, remotes, or the user's credential helpers.
  git_config = CONFIG / "gitconfig"
  if not git_config.is_file():
    fail("Missing sandbox Git config; run configure first")
  flags += ["--map", f"{git_config}:{HOME / '.gitconfig'}"]
  env = ["NO_PROXY=127.0.0.1,localhost,::1", "no_proxy=127.0.0.1,localhost,::1",
         f"AI_MEMORY_DATA_DIR={CLIENT}", "AI_MEMORY_SERVER_URL=http://127.0.0.1:49374",
         "AI_MEMORY_RUN_AUTOWIRE=false", "GIT_TERMINAL_PROMPT=0"]
  if (MEMORY / "native-runner/server-token").is_file():
    env.append(f"AI_MEMORY_AUTH__BEARER_TOKEN_FILE={MEMORY / 'native-runner/server-token'}")
  if harness == "opencode":
    # Never connect a jailed UI to a host service that executes outside the jail.
    if any(arg == "--server" or arg.startswith("--server=") for arg in native_args):
      fail("--server is not allowed in managed launches; use the private server")
    native_args = ["--standalone", *native_args]
  return flags + ["--", "/usr/bin/env", *env, "/bin/sh", "/tmp/.ai-stack-entry.sh", str(native), "run", "--require-server", "--no-autowire",
                  "--executable", str(jail_tool), harness, *native_args]


def configure_git():
  # Read only identity fields, not host credential configuration or includes.
  identity = {}
  for key in ["user.name", "user.email"]:
    result = subprocess.run(["git", "config", "--global", "--get", key], text=True, capture_output=True)
    if result.returncode == 0:
      identity[key.split(".")[1]] = result.stdout.strip()
  text = "# Sandbox only; host remotes and helpers are unchanged.\n"
  if identity:
    text += "[user]\n" + "".join(f"  {key} = {json.dumps(value)}\n" for key, value in identity.items())
  text += ('[url "https://gitlab.com/"]\n  insteadOf = git@gitlab.com:\n  insteadOf = ssh://git@gitlab.com/\n'
           '[credential "https://gitlab.com"]\n  helper =\n  helper = !glab auth git-credential\n')
  write(CONFIG / "gitconfig", text)


def check(args):
  failed = False
  for name in ["ai-jail", "codex", "kimi", "opencode", "ai-usagebar", "node", "npm", "git", "glab", "bwrap", "zsh"]:
    exe = shutil.which(name)
    announce(f"{'OK' if exe else 'MISSING'} {name}: {exe or 'install on host'}")
    failed |= not bool(exe)
  for root in ROOTS:
    announce(f"{'OK' if root.is_dir() else 'MISSING'} workspace: {root}")
    failed |= not root.is_dir()
  try:
    native = native_memory()
    run([native, "status"], env={**os.environ, "AI_MEMORY_DATA_DIR": str(MEMORY)})
  except (RuntimeError, subprocess.CalledProcessError):
    failed = True
  if failed:
    fail("Preflight incomplete; resolve the missing prerequisites before launching")
  if args.sandbox:
    for harness in ["codex", "kimi", "opencode"]:
      command = [sys.executable, __file__, "probe"]
      if args.auth:
        command.append("--auth")
      command.append(harness)
      run(command, cwd=ROOTS[0])
  announce("Preflight passed. This is NOT proof of model/MCP OAuth or hook capture. See ai/README.md for live checks.")


def probe(args):
  """Use the exact launcher mounts/network, without starting a model or session."""
  command = launch_command(args.harness, [])
  split = command.index("--")
  # Keep the inner env overrides (including the installed-version NO_PROXY fix).
  env_end = command.index(str(native_memory()), split)
  tool = command[command.index("--executable", env_end) + 1]
  code = '''
import http.client, json, os, pathlib, socket, subprocess, uuid
home = pathlib.Path.home()
for root in [home / "Dev/sympla", home / "Documents/gcrm/Linear"]:
  target = root / (".ai-stack-probe-" + uuid.uuid4().hex)
  try:
    with target.open("x") as stream: stream.write("probe")
    assert target.read_text() == "probe"
  finally:
    if target.exists(): target.unlink()
  print("OK workspace read/write:", root)
for path in [home / ".ssh", home / ".zshrc", home / ".aws", pathlib.Path("/var/run/docker.sock")]:
  assert not path.exists(), "Unexpected exposure: " + str(path)
print("OK unrelated home/SSH/Docker hidden")
client = home / ".local/share/ai-stack/memory"
target = client / (".probe-" + uuid.uuid4().hex)
try:
  with target.open("x") as stream: stream.write("probe")
finally:
  if target.exists(): target.unlink()
print("OK persistent ai-memory client writable")
state_roots = {"codex": home / ".codex", "kimi": home / ".kimi-code", "opencode": home / ".config/opencode"}
active = state_roots[os.environ["AI_STACK_PROBE_HARNESS"]]
target = active / (".probe-" + uuid.uuid4().hex)
try:
  with target.open("x") as stream: stream.write("probe")
finally:
  if target.exists(): target.unlink()
print("OK active harness state writable:", active)
for name in json.loads(os.environ["AI_STACK_PROBE_SKILLS"]):
  skill = active / "skills" / name / "SKILL.md"
  assert skill.is_file(), "Shared custom skill missing: " + name
  try:
    fd = os.open(skill, os.O_WRONLY)
  except OSError:
    pass
  else:
    os.close(fd)
    raise AssertionError("Shared skill unexpectedly writable: " + name)
print("OK canonical custom skills present and read-only")
version = subprocess.run([os.environ["AI_STACK_PROBE_TOOL"], "--version"], text=True, capture_output=True, timeout=20)
assert version.returncode == 0, "Harness executable/runtime failed"
print("OK harness executable:", version.stdout.strip().splitlines()[0])
for path in [home / ".config/ai-stack/gitconfig", home / ".local/share/ai-memory/native-runner/ai-memory"]:
  try:
    fd = os.open(path, os.O_WRONLY)
  except OSError:
    pass
  else:
    os.close(fd)
    raise AssertionError("Expected read-only: " + str(path))
print("OK policy and native runner read-only")
connection = http.client.HTTPConnection("127.0.0.1", 49374, timeout=8)
connection.request("GET", "/health")
response = connection.getresponse()
assert response.status < 500, response.status
response.read()
print("OK ai-memory loopback relay:", response.status)
connection.close()
result = subprocess.run(["curl", "--silent", "--show-error", "--max-time", "15", "--output", "/dev/null", "--write-out", "%{http_code}", "https://gitlab.com"], text=True, capture_output=True)
assert result.returncode == 0, "Allowed proxy request failed"
print("OK allowed GitLab HTTPS:", result.stdout)
result = subprocess.run(["curl", "--silent", "--max-time", "10", "--output", "/dev/null", "https://example.com"], capture_output=True)
assert result.returncode != 0, "Unlisted domain unexpectedly reachable"
print("OK unlisted domain blocked")
try:
  connection = socket.create_connection(("1.1.1.1", 443), timeout=0.5)
except OSError:
  pass
else:
  connection.close()
  raise AssertionError("Raw external TCP unexpectedly reachable")
print("OK direct external TCP blocked")
result = subprocess.run(["git", "config", "--get-all", "url.https://gitlab.com/.insteadOf"], text=True, capture_output=True)
assert "git@gitlab.com:" in result.stdout
print("OK sandbox-only HTTPS Git rewrite")
if os.environ["AI_STACK_PROBE_AUTH"] == "1":
  result = subprocess.run(["glab", "api", "--hostname", "gitlab.com", "user", "--silent"], capture_output=True, timeout=20)
  assert result.returncode == 0, "GitLab API authentication failed; sign in on host"
  result = subprocess.run(["git", "credential", "fill"], input="protocol=https\\nhost=gitlab.com\\n\\n", text=True, capture_output=True, timeout=20)
  assert result.returncode == 0 and "password=" in result.stdout, "Git credential helper unavailable"
  print("OK authenticated GitLab API and Git credential helper (no credentials printed)")
'''
  skills = sorted(p.name for p in (CONFIG / "skills").iterdir() if (p / "SKILL.md").is_file())
  command = command[:env_end] + ["/usr/bin/env", f"AI_STACK_PROBE_HARNESS={args.harness}", f"AI_STACK_PROBE_TOOL={tool}",
                               f"AI_STACK_PROBE_SKILLS={json.dumps(skills)}",
                               f"AI_STACK_PROBE_AUTH={int(args.auth)}", "/usr/bin/python3", "-c", code]
  command.insert(1, "--exec")
  exec_or_preview(command)


def main():
  global DRY
  parser = argparse.ArgumentParser(description=__doc__)
  sub = parser.add_subparsers(dest="action", required=True)
  for name in ["install", "configure", "server", "check"]:
    item = sub.add_parser(name)
    item.add_argument("--dry-run", action="store_true", help="Preview without writes, downloads, or services")
    if name == "configure":
      item.add_argument("--import-skills", action="store_true", help="Copy existing custom OpenCode skills into repo, unchanged")
      item.add_argument("--hooks", action="store_true", help="Install ai-memory hooks and managed skills on the host")
      item.add_argument("--clean-legacy-jails", action="store_true", help="Back up and retire the three reviewed old .ai-jail configs")
    if name == "check":
      item.add_argument("--sandbox", action="store_true", help="Run live filesystem/network probes for all harnesses (no models)")
      item.add_argument("--auth", action="store_true", help="With --sandbox, verify GitLab API and credential helper")
  item = sub.add_parser("launch")
  item.add_argument("--dry-run", action="store_true")
  item.add_argument("harness", choices=["codex", "kimi", "opencode", "opencode2"])
  item.add_argument("native_args", nargs=argparse.REMAINDER)
  item = sub.add_parser("launch-here", help="Launch with only the current directory writable")
  item.add_argument("--dry-run", action="store_true")
  item.add_argument("harness", choices=["codex", "kimi", "opencode", "opencode2"])
  item.add_argument("native_args", nargs=argparse.REMAINDER)
  item = sub.add_parser("probe", help="Live filesystem/network checks without starting a model")
  item.add_argument("--dry-run", action="store_true")
  item.add_argument("--auth", action="store_true")
  item.add_argument("harness", choices=["codex", "kimi", "opencode"])
  args = parser.parse_args()
  DRY = args.dry_run
  if args.action == "probe":
    probe(args)
    return
  if args.action in {"launch", "launch-here"}:
    cmd = launch_command(args.harness, args.native_args, here=args.action == "launch-here")
    exec_or_preview(cmd)
    return
  if args.action == "configure":
    configure_git()
  {"install": install, "configure": configure, "server": server, "check": check}[args.action](args)


if __name__ == "__main__":
  try:
    main()
  except (RuntimeError, ValueError, OSError, subprocess.CalledProcessError) as error:
    print(f"ERROR: {error}", file=sys.stderr)
    sys.exit(1)
