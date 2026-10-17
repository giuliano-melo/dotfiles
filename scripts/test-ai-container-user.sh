#!/usr/bin/env bash
set -euo pipefail

cd "$HOME/Dev/dotfiles"
mkdir -p "$HOME/Dev/sympla" "$HOME/Documents/gcrm/Linear"
bash setup.sh ai test

# Exercise real chezmoi deployment over pre-existing local files. The backup
# helper must preserve both files before chezmoi replaces them.
mkdir -p "$HOME/.config/ai-stack" "$HOME/.config/ai-usagebar"
printf 'legacy launcher config\n' > "$HOME/.config/ai-stack/ai-stack.zsh"
printf 'legacy usagebar config\n' > "$HOME/.config/ai-usagebar/config.toml"
bash scripts/backup-chezmoi-config.sh "$HOME/Dev/dotfiles"
chezmoi --source "$HOME/Dev/dotfiles/chezmoi" apply --force
python3 - <<'PY'
import pathlib
home = pathlib.Path.home()
backups = list((home / '.local/state/dotfiles/backups').iterdir())
assert len(backups) == 1, f'expected one backup snapshot, got {len(backups)}'
backup = backups[0]
for relative, content in [
  ('.config/ai-stack/ai-stack.zsh', 'legacy launcher config\n'),
  ('.config/ai-usagebar/config.toml', 'legacy usagebar config\n'),
]:
  path = backup / relative
  assert path.read_text() == content
  assert path.stat().st_mode & 0o777 == 0o600
usagebar = home / '.config/ai-usagebar/config.toml'
assert usagebar.stat().st_mode & 0o777 == 0o600
assert usagebar.read_bytes() == (home / 'Dev/dotfiles/chezmoi/dot_config/ai-usagebar/private_config.toml').read_bytes()
launcher = home / '.config/ai-stack/ai-stack.zsh'
assert launcher.read_bytes() == (home / 'Dev/dotfiles/chezmoi/dot_config/ai-stack/ai-stack.zsh').read_bytes()
assert launcher.stat().st_mode & 0o777 == 0o644
PY

bash setup.sh ai install
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"
nvm --version
node --version
ai-jail --version
ai-memory --version
codex --version
kimi --version
opencode --version
ai-usagebar --version
bash setup.sh ai configure --hooks

# Reapplying must not change config/skill bytes or create more backups.
python3 - <<'PY'
import hashlib, pathlib, subprocess
home = pathlib.Path.home()
roots = [home / '.config', home / '.codex', home / '.kimi-code', home / '.nvm/alias', home / '.local/state/dotfiles/backups']
def snapshot():
  return {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
          for root in roots if root.exists() for p in root.rglob('*')
          if p.is_file() and not p.is_symlink()}
before = snapshot()
subprocess.run(['bash', 'setup.sh', 'ai', 'install'], check=True)
subprocess.run(['bash', 'setup.sh', 'ai', 'configure', '--hooks'], check=True)
subprocess.run(['bash', 'scripts/backup-chezmoi-config.sh', str(home / 'Dev/dotfiles')], check=True)
subprocess.run(['chezmoi', '--source', str(home / 'Dev/dotfiles/chezmoi'), 'apply', '--force'], check=True)
assert before == snapshot(), 'Reapplying changed files or added backups'
for harness in ['codex', 'kimi', 'opencode']:
  subprocess.run(['bash', str(home / 'Dev/dotfiles/setup.sh'), 'ai', 'launch', '--dry-run', harness], cwd=home / 'Dev/sympla', check=True, stdout=subprocess.DEVNULL)
assert (home / '.config/ai-usagebar/config.toml').read_bytes() == (home / 'Dev/dotfiles/chezmoi/dot_config/ai-usagebar/private_config.toml').read_bytes()
assert len(list((home / '.local/state/dotfiles/backups').iterdir())) == 1
print('PASS: chezmoi deployment, private mode, conflict backups, nvm/Node, AI tools/hooks, launch previews, and idempotence')
PY
zsh -fc 'source ~/.zshrc; whence -w nvm jail codex kimi opencode2; nvm --version'
echo 'Not tested here: systemd, nested bubblewrap, provider/MCP authentication.'
