# AI CLI setup (Linux)

One host-side setup module configures Codex, Kimi Code, and OpenCode **V2**.
It also installs **nvm/Node LTS** and **ai-usagebar**, including your portable
usagebar preferences.
Managed launch order is **ai-jail → native ai-memory run → selected CLI**.
The existing shell/editor installer is unchanged; this module does not deploy
firewall rules, replace your shell setup, or weaken AppArmor/sysctl policy.

## New machine

Clone this repository outside the sandbox (HTTPS works before configuring SSH).
Install Python 3.11+ first. The installer provisions nvm and pinned Node LTS/npm
when absent, without replacing an existing nvm installation or its defaults.
On a new machine, first follow the root [machine setup guide](../README.md) to
install chezmoi, prepare Ansible/host packages, and apply the user configuration.
Then install the AI tools:

```sh
git clone https://github.com/giuliano-melo/dotfiles.git ~/Dev/dotfiles
cd ~/Dev/dotfiles
bash setup.sh ai install --dry-run
bash setup.sh ai install
```

Downloads use pinned releases and published SHA256 checksums; Codex and
OpenCode V2 use versioned official npm packages. Existing executables are kept,
never silently upgraded. Version pins are in `ai/versions.json`. This is a
reproducible configuration, not a byte-for-byte locked OS image. Review installer
and dependency changes before bumping versions. The pinned ai-jail binary is
Linux x86_64; on arm64, install that version with cargo first.

Make sure these are in PATH (also add them to your own shell startup if needed):

```sh
export PATH="$HOME/.local/bin:$HOME/.kimi-code/bin:$HOME/.opencode/bin:$HOME/.cargo/bin:$PATH"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
source "$NVM_DIR/nvm.sh"
mkdir -p ~/Dev/sympla ~/Documents/gcrm/Linear
bash setup.sh ai configure
bash setup.sh ai server
bash setup.sh ai configure --hooks
bash setup.sh ai check
```

`server` leaves an existing listener on port 49374 alone. Otherwise it invokes
ai-memory's native interactive setup to create a **host user service**. It does
not create a second server next to Docker. Keep the server bound to loopback;
configure service authentication separately when needed. Server data and secrets
are never committed here. Check the service's identity with `check`.

On your existing installation, the one-time adoption command is:

```sh
bash setup.sh ai configure --import-skills --hooks --clean-legacy-jails
```

This copies existing custom skills unchanged into `ai/skills`, backs up changed
configs under `~/.local/state/dotfiles/backups`, replaces only identical skill
directories with links, and retires only the three reviewed legacy `.ai-jail`
files. It stops if those files contain additional policy. Review imported skills
before committing; never import credential, session, or auth directories.

## Authentication (on the host)

After loading the zsh module, plain CLI names start managed sessions. Use
`command` to deliberately bypass the zsh functions for host login/maintenance:

```sh
command codex login
command kimi login
command opencode auth login
glab auth login --hostname gitlab.com --git-protocol https
```

Authorize remote MCPs separately in each harness. OpenCode: use the native UI
on the host (`command opencode`) and `/mcps`. This avoids sandbox-to-browser
loopback callback problems. The five MCP **definitions** are shared, not OAuth
tokens/client registrations. No secrets are stored in the repository. Existing
model choices, permissions, trust settings, unrelated MCPs, and hooks are kept.

For Codex, run `command codex mcp login <server-name>` on the host using the
names from `command codex mcp list`. Kimi's host UI uses `/mcp-config login
<server-name>` for sign-in and `/mcp` for connection status.

glab must be able to authenticate without a desktop keyring inside the sandbox.
Its config is mounted read-only at a private source path and copied to a
disposable in-jail directory: glab 1.53 needs a writable config even for read-only
API calls. Changes never write back to the host config. A host `GITLAB_TOKEN`
(or fallback `OAUTH_TOKEN`) is passed by **name**, never embedded in argv/config.
Only selected API-key variables and ai-memory authentication are passed in
addition; the full host environment is not inherited.
Do not expose the desktop DBus/keyring socket
to make login work. Provision a suitably scoped GitLab credential on the host;
read-only mounting prevents edits, not use or theft of the credential.

## Daily use

Start a new zsh, or source `~/.config/ai-stack/ai-stack.zsh`:

```sh
cd ~/Dev/sympla/a-repository
codex
kimi --fresh
opencode2
jail opencode --prompt 'Review this repository'
jail-here codex
jail-here kimi --fresh
jail-here opencode2
jail-spec codex
jail-code kimi
```

`jails` / `jaill` change to the two workspace roots. Native CLI names remain
available with `command`; these convenience functions are not system-wide
enforcement. Invocations from editors, desktop apps, absolute paths, and other
shells must explicitly use the managed launcher to obtain the same protections.

For a project outside those two roots, `jail-here <harness>` opts into using only
the current directory as the writable workspace. For example, `cd` to a specific
project first, then run `jail-here codex`, `jail-here kimi`, or
`jail-here opencode2`. It keeps the same ai-jail → ai-memory → CLI launch path
and network/credential restrictions. It refuses HOME, its ancestors, broad
system directories, and parent directories of the configured workspaces. Regular
`codex`, `kimi`, `opencode2`, and `jail` commands remain restricted to the
existing roots.

The managed OpenCode launcher explicitly enables raw terminal passthrough so
OpenCode's TUI can send OSC 52 clipboard sequences through ai-jail's PTY proxy.
A global `[commands.opencode]` setting cannot do this: ai-jail selects command
tables from the jailed argv, and the managed argv starts with `/usr/bin/env`,
not the harness name. Codex and Kimi explicitly keep passthrough disabled. Raw
passthrough exposes terminal escape/query behavior to programs in the OpenCode
jail; that trade-off is accepted there for clipboard support.

Codex is now a self-contained standalone binary installed under `~/.codex`. The
managed launcher exposes the executable at a read-only path outside that writable
state tree and denies the original `bin` directory, avoiding overlapping mount
warnings. It also passes `--no-daemon` so Codex does not try to use a
persisting background server inside the jail's fresh tmpfs home.

The regular launcher rejects working directories outside the two workspace
roots, including HOME. Both roots remain writable in regular launches. It
exposes only the active harness's persistent state, ai-memory client state,
read-only skills and Git/glab config, and required runtime binaries. Docker, SSH,
full inherited environment, systemd-user IPC, and automatic registry egress are
off. Raw terminal passthrough is off except for OpenCode (see above). OpenCode
always runs a **private server inside
the jail**; connecting it to an explicit host server is refused.

Writable ai-memory client caches/spools live in
`~/.local/share/ai-stack/memory`, separate from the read-only native runner and
the host server's database. Existing server history and old client spools are
not moved or deleted. Kimi's installed binary is exposed read-only at a separate
in-jail path, with its original bin directory denied, so its state can remain
writable without exposing a writable executable.

GitLab SSH-style remotes are rewritten to HTTPS **inside the jail only**, with
`glab auth git-credential` as the sandbox-only helper. Host remotes and global
credential settings are unchanged. Other host Git settings/signing/includes
are intentionally not imported; name/email are copied into the private Git
config. Re-run configure after changing your Git identity.

## Sources of truth

- `ai/skills/`: edit custom skills here; links deploy the same files to all three
  harnesses. Built-in/project skills can still differ and override global skills.
- `~/.config/ai-stack/skills`: includes generated ai-memory managed skills;
  re-generated by `configure --hooks`, not manually copied into Git.
- `ai/mcp-servers.json`: endpoints, with Kimi's required flavor override.
- `ai/allowed-hosts.txt`: explicit hosts; entries also allow subdomains. Registry
  access and arbitrary browsing are not enabled. Add hosts only as needed.
- `chezmoi/dot_config/ai-usagebar/private_config.toml`: portable ai-usagebar
  preferences, deployed by chezmoi as a private `~/.config/ai-usagebar/config.toml`.
  Existing settings are preserved, including local-only fields; review and
  reconcile the template manually if you later customize the widget. Config
  files are copied, not symlinked, so settings UI writes cannot alter the repo.

ai-usagebar runs on the host, **outside ai-jail**. Its current provider choices
and environment-variable names are tracked; API keys, OAuth login files, and
credentials are not. No autostart/service existed in the inspected setup, so
none is invented or enabled. Desktop-extension/tray integration remains a
separate opt-in. Run `ai-usagebar --help` for your preferred display integration.

The zsh module loads nvm portably and adds locally installed tools to PATH. On
a fresh system it installs the pinned Node LTS default; an existing active Node
and nvm default are retained. An existing Node older than 20 still requires an
explicit `nvm install` / `nvm use` choice rather than silently switching versions.

Re-run `configure` after adding a skill or changing the MCP manifest. Avoid
changing MCP server names: existing OAuth and permission rules may refer to them.
The script refuses duplicate endpoints and ambiguous formats rather than
discarding configuration or comments. Hand-written JSONC configs require manual
review; the installer edits strict JSON and preserves an existing JSONC file.

## Verification

```sh
bash setup.sh ai test
bash setup.sh ai configure --dry-run
bash setup.sh ai check
bash setup.sh ai check --sandbox --auth
cd ~/Dev/sympla
bash ~/Dev/dotfiles/setup.sh ai launch --dry-run codex
```

Dry-runs do not launch a model or prove connectivity. On the first real session
of **each** harness, check the model responds, all five MCPs connect, skills
appear, and Git can run `ls-remote origin` (read-only, no fetch/ref changes).
Verify writes in both workspaces using disposable files, then remove those
files. Confirm unrelated home directories, SSH files, and the Docker socket
cannot be accessed. After exiting, run ai-memory doctor from the same project
with the native client; a newly configured hook is not proof of captured data.

Launcher previews print the names-only invocation without executing ai-jail's
own environment-expanding `--dry-run`; this avoids exposing forwarded token
values in terminal output. Use the live sandbox probes to validate isolation.

`check --sandbox --auth` performs actual disposable-file, read-only skill,
network allow/deny, executable/runtime, ai-memory relay, GitLab API and Git
credential-helper checks for all three harnesses. It does not start a model or
approve hooks. On Codex's first interactive launch, review and approve the new
hooks in its **Hooks need review** prompt. Remote MCPs that say **Not logged in**
still need individual host-side OAuth sign-in; configuring an endpoint does not
authenticate it.

Filtered networking may need additional provider OAuth/refresh hosts. Never
automatically fall back to unrestricted networking. ai-jail 2.9.0 leaves
`NO_PROXY` empty even with a forwarded port; the launcher sets loopback bypass
inside the jail explicitly. Port 49374 exposes the **entire ai-memory service**,
not just MCP; use server-side authorization if that is too broad.

If bubblewrap is blocked by Ubuntu AppArmor, stop and review a narrowly scoped
profile for the installed bubblewrap binary. This script never disables the
system-wide unprivileged-user-namespace policy.

## Backups, updates, rollback

### Disposable Ubuntu installation test

From the repository root, run `bash scripts/test-ai-container.sh` with Docker
available. It downloads Ubuntu 24.04, runs the Ansible package play, installs
the pinned chezmoi release, and creates a fresh non-root user. It tests
chezmoi deployment, private file permissions, conflict backups, shell launcher
loading, AI tool installation, hooks, launch previews, and repeat-run
idempotence. The repository is mounted read-only; no host home, auth files, or
Docker socket are mounted. No privileged mode or host networking is used. The
test container is removed on exit; Docker retains its downloaded base image
cache.

This is not a substitute for a VM test of systemd and nested bubblewrap, or
for authenticated model/MCP checks. The test starts without Node/npm or nvm;
the installer must provision them. ai-usagebar's configuration and binary
startup are checked, but desktop display integration is not. The host `sudo
apt` installation path is not exercised.

Back up ai-memory data separately, using the server's supported `backup`/`restore`
workflow. For an existing Docker deployment, use its wrapper/volume-aware
commands on the host. Never restore raw databases over a running server, and
never point a new native server at an existing volume without planning migration.
Keep backups containing memory, credentials, or private Git identity encrypted
and outside this repository. MCP/provider sign-ins are redone on a new machine.

For upgrades, edit version pins deliberately, upgrade tools with their supported
host-side commands, rerun `configure --hooks`, and repeat the live checks.
`install` deliberately skips installed tools. To roll back configuration, inspect
the timestamped backups and restore only the intended files. To disable shell
integration, remove its marked source line from `.zshrc` and open a new shell.
Do not run the legacy `install.sh` just to install the AI module: it also deploys
other personal shell/editor files.
