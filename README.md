# Dotfiles

Personal shell and Vim configuration with a cross-distro setup path based on
chezmoi (user configuration) and Ansible (system packages).

## New Linux machine

1. Clone this repository. Install [chezmoi](https://www.chezmoi.io/install/)
   using its official instructions only if you select the chezmoi user config.
2. Start the setup checklist. It previews only; nothing is changed unless you
   explicitly pass `--apply`:

   ```sh
   bash scripts/setup-machine.sh
   ```

   Choose system packages, chezmoi user config, shell dotfiles, Vim, AI tools,
   AI integrations, and (optionally) the monthly cleanup timer. Review the complete preview and
   confirm before applying. Cleanup scheduling is never selected by `--all`.
   You can also select components non-interactively:

   ```sh
   bash scripts/setup-machine.sh --dry-run --shell --vim
   bash scripts/setup-machine.sh --apply --shell --vim
   ```

   `--apply` with no component flags opens the checklist. Non-interactive apply
   requires explicit component flags and `--yes`. Existing shell/Vim files are
   backed up under `~/.local/state/dotfiles/backups/`; conflicting symlinks are
   left untouched. The AI tools selection installs pinned tools but does not
   sign in or configure credentials. On a new machine, `--ai-config` should be
   selected with `--user-config`; on an existing one it can be selected alone
   if the managed launcher is already installed. It does not sign in or install
   hooks.

Package mappings are provided for Debian, Ubuntu, Fedora, Arch Linux, Manjaro,
and EndeavourOS. The fresh-install test currently covers Ubuntu only; validate
the other distributions in disposable VMs before relying on them. ai-jail also
depends on kernel and distro security-policy support. The setup does not upgrade
the OS or change firewall, AppArmor, SELinux, sysctl, or other security policy.
Unsupported distributions stop rather than guessing.

- **AI tools:** see [ai/README.md](ai/README.md) for installation, authentication,
  sandboxed Codex/Kimi/OpenCode V2 launchers, shared skills/MCP definitions,
  verification, and recovery.
- **Existing shell/editor links:** `bash install.sh --dry-run` previews the
  original installer. It deploys personal configurations beyond the AI module;
  review it before using it on a new machine.

The selective setup uses `scripts/setup-user-dotfiles.sh` for shell and Vim
files. It does not deploy the legacy firewall rule files.

The AI launcher and harness-specific configuration remain in the focused
`setup.sh ai ...` helpers; they are not replaced by chezmoi or Ansible.
After configuring the AI launchers, use `jail-here <codex|kimi|opencode2>` from
a specific project outside the default workspaces when you explicitly want to
make only the current directory writable.

## Monthly cleanup

To update Git repositories recursively, run `git-update-all --dry-run ~/Dev`
to preview, then `git-update-all ~/Dev`. The command skips dirty worktrees,
detached HEADs and branches without an upstream, and only allows fast-forward
updates. The preview uses local information and does not fetch remote changes.
The shell command is available after loading the managed AI shell fragment;
alternatively run `python3 ~/Dev/dotfiles/scripts/git-update-all.py ~/Dev`.

`bash scripts/cleanup-system.sh --dry-run` reports eligible Docker build cache,
old images for review, and local Git repository maintenance. Dry-run is the
default; `--apply` prunes only Buildx cache older than 30 days and runs Git's
automatic maintenance. The user timer in `systemd/user/` is provided but not
enabled; review the report before installing it. See
[systemd/user/README.md](systemd/user/README.md).
Run `bash scripts/test-cleanup-system.sh` to verify dry-run and apply behavior
against isolated fake Docker/Git commands.
Run `bash scripts/test-setup-machine.sh` to test cancellation, conflicts,
repeat-runs, backups, and combined selections in a temporary home directory.

No credentials, OAuth tokens, session stores, or ai-memory databases belong in
this repository. Keep private backups separate.
