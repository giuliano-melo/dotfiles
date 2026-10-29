#!/usr/bin/env python3
"""Offline regression tests. Never runs an installer, harness, or real service."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
import tarfile
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("stack", Path(__file__).with_name("ai-stack.py"))
stack = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stack)


class StackTests(unittest.TestCase):
  def setUp(self):
    self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-test-")
    self.addCleanup(self.temp.cleanup)
    home = Path(self.temp.name)
    self.patches = [patch.object(stack, "HOME", home), patch.object(stack, "CONFIG", home / ".config/ai-stack"),
                    patch.object(stack, "MEMORY", home / ".local/share/ai-memory"), patch.object(stack, "DRY", False),
                    patch.object(stack, "CLIENT", home / ".local/share/ai-stack/memory"),
                    patch.object(stack, "ROOTS", (home / "Dev/sympla", home / "Documents/gcrm/Linear"))]
    for item in self.patches:
      item.start()
      self.addCleanup(item.stop)
    self.output = contextlib.redirect_stdout(io.StringIO())
    self.output.__enter__()
    self.addCleanup(self.output.__exit__, None, None, None)

  def put(self, relative, content):
    path = stack.HOME / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    return path

  def test_mcp_preserves_preferences_names_and_is_idempotent(self):
    path = self.put(".codex/config.toml", 'model = "keep-model"\n\n[mcp_servers.GitLab]\nurl = "https://gitlab.com/api/v4/mcp"\n\n[projects."/keep"]\ntrust_level = "trusted"\n')
    opencode = self.put(".config/opencode/opencode.json", json.dumps({"default_agent": "plan", "mcp": {"servers": {"Linear LPM": {"url": "https://mcp.linear.app/mcp", "oauth": {}}}}}))
    stack.configure_mcp()
    first = {p: p.read_bytes() for p in [path, opencode, stack.HOME / ".kimi-code/mcp.json"]}
    stack.configure_mcp()
    self.assertEqual(first, {p: p.read_bytes() for p in first})
    data = stack.tomllib.loads(path.read_text())
    self.assertEqual(data["model"], "keep-model")
    self.assertEqual(data["projects"]["/keep"]["trust_level"], "trusted")
    self.assertIn("GitLab", data["mcp_servers"])
    self.assertNotIn("gitlab", data["mcp_servers"])
    self.assertEqual(json.loads(opencode.read_text())["default_agent"], "plan")
    self.assertIn("Linear LPM", json.loads(opencode.read_text())["mcp"]["servers"])

  def test_preview_does_not_write(self):
    stack.DRY = True
    stack.configure_mcp()
    stack.configure_shell()
    self.assertEqual(list(stack.HOME.iterdir()), [])

  def test_write_backs_up_once_and_refuses_symlinks(self):
    path = self.put("settings", "old")
    stack.write(path, "new")
    stack.write(path, "new")
    backups = list((stack.HOME / ".local/state/dotfiles/backups").glob("*/settings"))
    self.assertEqual(len(backups), 1)
    self.assertEqual(backups[0].read_text(), "old")
    link = stack.HOME / "linked"
    link.symlink_to(path)
    with self.assertRaises(RuntimeError):
      stack.write(link, "bad")
    self.assertEqual(path.read_text(), "new")

  def test_shell_preserves_customizations(self):
    path = self.put(".zshrc", 'export MY_SETTING=yes\nalias jail-code="old"\n')
    stack.configure_shell()
    first = path.read_text()
    stack.configure_shell()
    self.assertEqual(first, path.read_text())
    self.assertIn("export MY_SETTING=yes", first)
    self.assertNotIn("alias jail-code=", first)
    self.assertEqual(first.count("# dotfiles: managed AI launchers"), 1)

  def test_duplicate_endpoints_are_rejected(self):
    self.put(".kimi-code/mcp.json", json.dumps({"mcpServers": {"a": {"url": "https://gitlab.com/api/v4/mcp"}, "b": {"url": "https://gitlab.com/api/v4/mcp"}}}))
    with self.assertRaises(RuntimeError):
      stack.configure_mcp()

  def test_launch_refuses_home_before_starting_anything(self):
    for root in stack.ROOTS:
      root.mkdir(parents=True)
    with patch.object(stack.Path, "cwd", return_value=stack.HOME):
      with self.assertRaisesRegex(RuntimeError, "Start inside"):
        stack.launch_command("codex", [])

  def test_launch_here_maps_only_the_current_directory(self):
    workspace = self.put("OtherProject/README.md", "project")
    self.put(".config/ai-stack/gitconfig", "# test")
    native = self.put(".local/share/ai-memory/native-runner/ai-memory", "native")
    tool = self.put(".local/bin/codex", "native")
    with patch.object(stack.Path, "cwd", return_value=workspace.parent), \
         patch.object(stack, "native_memory", return_value=native), \
         patch.object(stack.shutil, "which", side_effect=lambda name: str(tool) if name == "codex" else ("/usr/bin/ai-jail" if name == "ai-jail" else None)):
      command = stack.launch_command("codex", [], here=True)
    rw_maps = [command[index + 1] for index, item in enumerate(command[:-1]) if item == "--rw-map"]
    self.assertEqual(rw_maps, [str(workspace.parent)])
    self.assertIn("--network", command)
    self.assertNotIn("--no-network", command)
    self.assertIn("--require-server", command)
    self.assertNotIn("--no-terminal-passthrough", command)
    self.assertIn("--terminal-passthrough", command)
    self.assertNotIn("--display", command)
    self.assertNotIn(str(stack.ROOTS[0]), command)
    self.assertNotIn(str(stack.ROOTS[1]), command)

  def test_launch_here_rejects_home_and_broad_parents(self):
    for broad in [stack.HOME, stack.HOME.parent, stack.HOME / "Dev", Path("/tmp"), Path("/usr")]:
      with patch.object(stack.Path, "cwd", return_value=broad):
        with self.assertRaisesRegex(RuntimeError, "jail-here refuses"):
          stack.launch_command("codex", [], here=True)

  def test_launch_here_cli_action_uses_current_directory_mode(self):
    import sys
    with patch.object(sys, "argv", ["ai-stack.py", "launch-here", "--dry-run", "kimi", "--fresh"]), \
         patch.object(stack, "launch_command", return_value=["fake-ai-jail"]) as launch, \
         patch.object(stack, "exec_or_preview") as execute:
      stack.main()
    launch.assert_called_once_with("kimi", ["--fresh"], here=True)
    execute.assert_called_once_with(["fake-ai-jail"])
    self.assertTrue(stack.DRY)

  def test_launch_retains_arguments_and_network_is_allowed(self):
    for root in stack.ROOTS:
      root.mkdir(parents=True)
    self.put(".config/ai-stack/gitconfig", "# test")
    native = self.put(".local/share/ai-memory/native-runner/ai-memory", "native")
    tool = self.put(".opencode/bin/opencode", "native")
    with patch.object(stack.Path, "cwd", return_value=stack.ROOTS[0]), patch.object(stack, "native_memory", return_value=native), patch.object(stack.shutil, "which", side_effect=lambda name: str(tool) if name == "opencode" else ("/usr/bin/ai-jail" if name == "ai-jail" else None)):
      command = stack.launch_command("opencode", ["--prompt", "keep this argument", "--fresh"])
      self.assertIn("--private-home", command)
      self.assertIn("--network", command)
      self.assertNotIn("--no-network", command)
      self.assertNotIn("--ssh", command)
      self.assertNotIn("--no-terminal-passthrough", command)
      self.assertIn("--terminal-passthrough", command)
      self.assertIn("--display", command)
      for name in ["DISPLAY", "WAYLAND_DISPLAY", "XDG_RUNTIME_DIR", "XAUTHORITY"]:
        self.assertIn(name, command)
      self.assertIn("--require-server", command)
      self.assertEqual(command[-4:], ["--standalone", "--prompt", "keep this argument", "--fresh"])
      with self.assertRaisesRegex(RuntimeError, "--server"):
        stack.launch_command("opencode", ["--server=http://localhost:4096"])

  def test_display_passthrough_is_opencode_only_and_forwards_names(self):
    for root in stack.ROOTS:
      root.mkdir(parents=True)
    self.put(".config/ai-stack/gitconfig", "# test")
    native = self.put(".local/share/ai-memory/native-runner/ai-memory", "native")
    opencode = self.put(".opencode/bin/opencode", "native")
    codex = self.put(".local/bin/codex", "native")
    display_env = {
      "DISPLAY": ":91",
      "WAYLAND_DISPLAY": "wayland-test",
      "XDG_RUNTIME_DIR": "/run/user/1000",
      "XAUTHORITY": "/tmp/test-xauthority",
    }
    which = lambda name: str(opencode if name == "opencode" else codex) if name in {"opencode", "codex"} else ("/usr/bin/ai-jail" if name == "ai-jail" else None)
    with patch.object(stack.Path, "cwd", return_value=stack.ROOTS[0]), \
         patch.object(stack, "native_memory", return_value=native), \
         patch.object(stack.shutil, "which", side_effect=which), \
         patch.dict(os.environ, display_env, clear=True):
      command = stack.launch_command("opencode", [])
      self.assertIn("--display", command)
      for name in display_env:
        self.assertIn(name, command)
      for value in display_env.values():
        self.assertNotIn(value, command)
      codex_command = stack.launch_command("codex", [])
    self.assertNotIn("--display", codex_command)
    for name in display_env:
      self.assertNotIn(name, codex_command)

  def test_extra_jail_policy_is_never_discarded(self):
    path = self.put(".ai-jail", 'mask = [".env"]\n')
    with self.assertRaises(RuntimeError):
      stack.clean_legacy_jails()
    self.assertIn("mask", path.read_text())

  def test_skills_are_linked_without_deleting_unrelated_skills(self):
    repo = stack.HOME / "test-repo"
    source = self.put("test-repo/ai/skills/demo/SKILL.md", "---\nname: demo\ndescription: test\n---\n")
    unrelated = self.put(".codex/skills/unrelated/SKILL.md", "keep")
    with patch.object(stack, "REPO", repo):
      stack.configure_skills()
      stack.configure_skills()
    for root in [".codex", ".kimi-code", ".config/opencode"]:
      target = stack.HOME / root / "skills/demo/SKILL.md"
      self.assertEqual(target.resolve(), source)
    self.assertEqual(unrelated.read_text(), "keep")

  def test_glab_and_other_secrets_are_forwarded_by_name_only(self):
    for root in stack.ROOTS:
      root.mkdir(parents=True)
    self.put(".config/ai-stack/gitconfig", "# test")
    native = self.put(".local/share/ai-memory/native-runner/ai-memory", "native")
    tool = self.put(".codex/packages/standalone/releases/0.163.0/bin/codex", "native")
    with patch.object(stack.Path, "cwd", return_value=stack.ROOTS[0]), patch.object(stack, "native_memory", return_value=native), patch.object(stack.shutil, "which", side_effect=lambda name: str(tool) if name == "codex" else ("/usr/bin/ai-jail" if name == "ai-jail" else None)), patch.dict(os.environ, {"GITLAB_TOKEN": "test-secret-never-on-argv", "UNRELATED_SECRET": "do-not-forward"}):
      command = stack.launch_command("codex", [])
    self.assertIn("GITLAB_TOKEN", command)
    self.assertNotIn("test-secret-never-on-argv", command)
    self.assertNotIn("UNRELATED_SECRET", command)
    self.assertNotIn("do-not-forward", command)
    self.assertNotIn(tool.parent, command)
    self.assertIn("/tmp/.ai-stack-codex", command)
    self.assertIn("--deny-path", command)

  def test_playwright_extension_token_is_forwarded_only_when_set(self):
    for root in stack.ROOTS:
      root.mkdir(parents=True)
    self.put(".config/ai-stack/gitconfig", "# test")
    native = self.put(".local/share/ai-memory/native-runner/ai-memory", "native")
    tool = self.put(".opencode/bin/opencode", "native")
    which = lambda name: str(tool) if name == "opencode" else ("/usr/bin/ai-jail" if name == "ai-jail" else None)
    with patch.object(stack.Path, "cwd", return_value=stack.ROOTS[0]), \
         patch.object(stack, "native_memory", return_value=native), \
         patch.object(stack.shutil, "which", side_effect=which), \
         patch.dict(os.environ, {"PLAYWRIGHT_MCP_EXTENSION_TOKEN": "test-playwright-token"}, clear=True):
      command = stack.launch_command("opencode", [])
    self.assertIn("PLAYWRIGHT_MCP_EXTENSION_TOKEN", command)
    self.assertNotIn("test-playwright-token", command)

    with patch.object(stack.Path, "cwd", return_value=stack.ROOTS[0]), \
         patch.object(stack, "native_memory", return_value=native), \
         patch.object(stack.shutil, "which", side_effect=which), \
         patch.dict(os.environ, {}, clear=True):
      command = stack.launch_command("opencode", [])
    self.assertNotIn("PLAYWRIGHT_MCP_EXTENSION_TOKEN", command)

  def test_codex_standalone_mount_avoids_overlap(self):
    for root in stack.ROOTS:
      root.mkdir(parents=True)
    self.put(".config/ai-stack/gitconfig", "# test")
    native = self.put(".local/share/ai-memory/native-runner/ai-memory", "native")
    tool = self.put(".codex/packages/standalone/releases/0.163.0/bin/codex", "native")
    with patch.object(stack.Path, "cwd", return_value=stack.ROOTS[0]), \
         patch.object(stack, "native_memory", return_value=native), \
         patch.object(stack.shutil, "which", side_effect=lambda name: str(tool) if name == "codex" else ("/usr/bin/ai-jail" if name == "ai-jail" else None)):
      command = stack.launch_command("codex", [])
    self.assertNotIn(tool.parent, command)
    self.assertIn("/tmp/.ai-stack-codex", command)
    self.assertIn("--deny-path", command)
    self.assertNotIn("--no-daemon", command)
    # Make sure the legacy npm node_modules mount is not forced for Codex.
    self.assertNotIn("node_modules", " ".join(command))
    # Node may still be mapped for OpenCode; here we only assert Codex itself.
    self.assertIn(str(stack.ROOTS[0]), command)

  def test_chrome_config_is_mounted_for_playwright_mcp_extension(self):
    for root in stack.ROOTS:
      root.mkdir(parents=True)
    self.put(".config/ai-stack/gitconfig", "# test")
    chrome = self.put(".config/google-chrome/Default/Extensions/mmlmfjhmonkocbjadbfplnigmagldckm/0.0.0_0/manifest.json", "{}")
    native = self.put(".local/share/ai-memory/native-runner/ai-memory", "native")
    tool = self.put(".opencode/bin/opencode", "native")
    with patch.object(stack.Path, "cwd", return_value=stack.ROOTS[0]), \
         patch.object(stack, "native_memory", return_value=native), \
         patch.object(stack.shutil, "which", side_effect=lambda name: str(tool) if name == "opencode" else ("/usr/bin/ai-jail" if name == "ai-jail" else None)):
      command = stack.launch_command("opencode", [])
    rw_maps = [command[i + 1] for i, item in enumerate(command[:-1]) if item == "--rw-map"]
    self.assertIn(str(chrome.parents[4]), rw_maps)

  def test_probe_executes_env_after_the_entry_script(self):
    from types import SimpleNamespace
    self.put(".config/ai-stack/skills/demo/SKILL.md", "test")
    native = stack.HOME / "native"
    prefix = ["/usr/bin/ai-jail", "--", "/usr/bin/env", "NO_PROXY=localhost", "/bin/sh", "/tmp/.ai-stack-entry.sh"]
    command = prefix + [str(native), "run", "--executable", "/native-tool", "codex"]
    with patch.object(stack, "launch_command", return_value=command), patch.object(stack, "native_memory", return_value=native), patch.object(stack.os, "execv") as execute:
      stack.probe(SimpleNamespace(harness="codex", auth=False))
    result = execute.call_args.args[1]
    index = result.index("/tmp/.ai-stack-entry.sh")
    self.assertEqual(result[index + 1], "/usr/bin/env")

  def test_release_verifies_checksum_and_installs_native_hooks(self):
    archive = io.BytesIO()
    with tarfile.open(fileobj=archive, mode="w:gz") as tar:
      for name, payload in [("./ai-memory", b"test-native"), ("./hooks/codex/stop.sh", b"test-hook")]:
        member = tarfile.TarInfo(name)
        member.size = len(payload)
        tar.addfile(member, io.BytesIO(payload))
    payload = archive.getvalue()
    checksum = stack.hashlib.sha256(payload).hexdigest().encode()
    target = stack.HOME / "native/ai-memory"
    def retrieve(url, path):
      path.write_bytes(payload)
    with patch.object(stack.urllib.request, "urlretrieve", side_effect=retrieve), patch.object(stack.urllib.request, "urlopen", return_value=io.BytesIO(checksum)):
      stack.download_release("example/repo", "v1", "test.tar.gz", target, "ai-memory")
    self.assertEqual(target.read_bytes(), b"test-native")
    self.assertEqual((target.parent / "hooks/codex/stop.sh").read_bytes(), b"test-hook")

  def test_bad_release_checksum_installs_nothing(self):
    target = stack.HOME / "native/ai-memory"
    def retrieve(url, path):
      path.write_bytes(b"bad")
    with patch.object(stack.urllib.request, "urlretrieve", side_effect=retrieve), patch.object(stack.urllib.request, "urlopen", return_value=io.BytesIO(b"0" * 64)):
      with self.assertRaisesRegex(RuntimeError, "Checksum mismatch"):
        stack.download_release("example/repo", "v1", "test.tar.gz", target, "ai-memory")
    self.assertFalse(target.exists())

  def test_jsonc_mcp_conflicts_are_not_overridden(self):
    path = self.put(".config/opencode/opencode.jsonc", '// keep comments\n{"mcp": {"servers": {}}}')
    with self.assertRaisesRegex(RuntimeError, "reconcile"):
      stack.configure_mcp()
    self.assertIn("// keep comments", path.read_text())

  def test_launch_preview_never_resolves_environment_secrets(self):
    stack.DRY = True
    output = io.StringIO()
    with patch.dict(os.environ, {"GITLAB_TOKEN": "secret-not-for-stdout"}), patch.object(stack.os, "execv") as execute, contextlib.redirect_stdout(output):
      stack.exec_or_preview(["/usr/bin/ai-jail", "--env", "GITLAB_TOKEN", "--", "native"])
    execute.assert_not_called()
    self.assertIn("GITLAB_TOKEN", output.getvalue())
    self.assertNotIn("secret-not-for-stdout", output.getvalue())

  def test_usagebar_template_is_deployed_with_private_permissions(self):
    stack.configure_usagebar()
    target = stack.HOME / '.config/ai-usagebar/config.toml'
    self.assertEqual(target.read_bytes(), (stack.REPO / 'chezmoi/dot_config/ai-usagebar/private_config.toml').read_bytes())
    self.assertEqual(target.stat().st_mode & 0o777, 0o600)
    stack.configure_usagebar()
    self.assertFalse((stack.HOME / '.local/state/dotfiles/backups').exists())

  def test_usagebar_local_settings_and_credentials_are_preserved(self):
    content = '[kimi]\nenabled = false\napi_key = "local-test-value"\n'
    target = self.put('.config/ai-usagebar/config.toml', content)
    stack.configure_usagebar()
    self.assertEqual(target.read_text(), content)

  def test_existing_nvm_and_node_are_not_reinstalled(self):
    self.put('.nvm/nvm.sh', '# existing nvm')
    with patch.dict(os.environ, {'NVM_DIR': str(stack.HOME / '.nvm')}), patch.object(stack.shutil, 'which', return_value='/existing/bin/node'), patch.object(stack, 'run') as run:
      stack.ensure_node()
    run.assert_not_called()
    self.assertEqual((stack.HOME / '.nvm/nvm.sh').read_text(), '# existing nvm')

  def test_nvm_preview_does_not_download_or_create_files(self):
    stack.DRY = True
    with patch.dict(os.environ, {'NVM_DIR': str(stack.HOME / '.nvm')}), patch.object(stack.shutil, 'which', return_value=None), patch.object(stack.urllib.request, 'urlretrieve') as download:
      stack.ensure_node()
    download.assert_not_called()
    self.assertFalse((stack.HOME / '.nvm').exists())


if __name__ == "__main__":
  unittest.main()
