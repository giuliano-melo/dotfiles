#!/usr/bin/env bash
# Exercise selected setup actions against a temporary HOME; never touch host config.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d /tmp/opencode/setup-machine-test.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home/.bash" "$tmp/home/.config"
printf 'existing bashrc\n' > "$tmp/home/.bashrc"
printf 'existing vimrc\n' > "$tmp/home/.vimrc"
printf 'unrelated config\n' > "$tmp/home/.config/keep-me"

preview="$(HOME="$tmp/home" bash "$repo/scripts/setup-machine.sh" --dry-run --shell --vim)"
grep -q 'Mode: DRY RUN' <<< "$preview"
grep -q 'symlink .*\.bashrc' <<< "$preview"
grep -q 'symlink .*\.vimrc' <<< "$preview"
[[ ! -L "$tmp/home/.bashrc" && ! -L "$tmp/home/.vimrc" ]]
[[ "$(cat "$tmp/home/.bashrc")" == 'existing bashrc' ]]

if HOME="$tmp/home" bash "$repo/scripts/setup-machine.sh" --apply --shell > "$tmp/noninteractive.log" 2>&1; then
  echo 'Non-interactive apply unexpectedly proceeded without --yes.' >&2
  exit 1
fi
grep -q 'requires --yes' "$tmp/noninteractive.log"
[[ ! -L "$tmp/home/.bashrc" ]]

HOME="$tmp/home" bash "$repo/scripts/setup-machine.sh" --apply --shell --vim --yes > "$tmp/apply.log"
[[ -L "$tmp/home/.bashrc" && "$(readlink -f "$tmp/home/.bashrc")" == "$repo/.bashrc" ]]
[[ -L "$tmp/home/.vimrc" && "$(readlink -f "$tmp/home/.vimrc")" == "$repo/.vimrc" ]]
[[ "$(cat "$tmp/home/.config/keep-me")" == 'unrelated config' ]]
python3 - "$tmp/home" <<'PY'
import pathlib, sys
home = pathlib.Path(sys.argv[1])
snapshots = list((home / ".local/state/dotfiles/backups").iterdir())
assert len(snapshots) == 1, snapshots
backup = snapshots[0]
assert (backup / ".bashrc").read_text() == "existing bashrc\n"
assert (backup / ".vimrc").read_text() == "existing vimrc\n"
assert (backup / ".bashrc").stat().st_mode & 0o777 == 0o600
assert (backup / ".vimrc").stat().st_mode & 0o777 == 0o600
PY

# Reapplying links is idempotent and must not create another backup snapshot.
HOME="$tmp/home" bash "$repo/scripts/setup-machine.sh" --apply --shell --vim --yes > "$tmp/repeat.log"
[[ "$(find "$tmp/home/.local/state/dotfiles/backups" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1 ]]

# A conflicting symlink must fail during preview, before another selected item changes.
mkdir -p "$tmp/conflict-home"
printf 'keep vim config\n' > "$tmp/conflict-home/.vimrc"
printf 'symlink destination\n' > "$tmp/outside-target"
ln -s "$tmp/outside-target" "$tmp/conflict-home/.bashrc"
if HOME="$tmp/conflict-home" bash "$repo/scripts/setup-machine.sh" --apply --shell --vim --yes > "$tmp/conflict.log" 2>&1; then
  echo 'Conflicting symlink unexpectedly accepted.' >&2
  exit 1
fi
grep -q 'Refusing to replace symlink target' "$tmp/conflict.log"
[[ ! -L "$tmp/conflict-home/.vimrc" ]]
[[ "$(cat "$tmp/conflict-home/.vimrc")" == 'keep vim config' ]]
[[ ! -e "$tmp/conflict-home/.local/state/dotfiles/backups" ]]

# AI integrations depend on the chezmoi-managed launcher/config being selected.
if HOME="$tmp/home" bash "$repo/scripts/setup-machine.sh" --dry-run --ai-config > "$tmp/dependency.log" 2>&1; then
  echo 'AI config unexpectedly allowed without the managed user config.' >&2
  exit 1
fi
grep -q 'AI integrations require --user-config' "$tmp/dependency.log"

# Combined shell + AI configuration operates in a throwaway HOME. .zshrc is a
# symlink into the repo, so this catches writes through a selected dotfile link.
mkdir -p "$tmp/bin" "$tmp/combined-home"
cat > "$tmp/bin/chezmoi" <<'CHEZMOI'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CHEZMOI_LOG"
CHEZMOI
chmod 755 "$tmp/bin/chezmoi"
export CHEZMOI_LOG="$tmp/chezmoi.log"
repo_snapshot() {
  python3 - "$repo" <<'PY'
import hashlib, os, pathlib, subprocess, sys
root = pathlib.Path(sys.argv[1])
paths = subprocess.check_output(
  ["git", "-C", str(root), "ls-files", "-z", "--cached", "--others", "--exclude-standard"]
).split(b"\0")
digest = hashlib.sha256()
for raw in sorted(p for p in paths if p):
  path = root / os.fsdecode(raw)
  if path.is_file() and not path.is_symlink():
    digest.update(raw)
    digest.update(hashlib.sha256(path.read_bytes()).digest())
print(digest.hexdigest())
PY
}
repo_snapshot_before="$(repo_snapshot)"
PATH="$tmp/bin:$PATH" HOME="$tmp/combined-home" bash "$repo/scripts/setup-machine.sh" \
  --apply --user-config --shell --ai-config --yes > "$tmp/combined.log"
repo_snapshot_after="$(repo_snapshot)"
[[ "$repo_snapshot_before" == "$repo_snapshot_after" ]]
[[ -L "$tmp/combined-home/.zshrc" ]]
grep -q 'diff' "$CHEZMOI_LOG"
grep -q 'apply --force' "$CHEZMOI_LOG"

# Cancellation is read-only; exercise it with a pseudo-terminal when util-linux
# script(1) is available. The separate no-TTY guard is tested above unconditionally.
if command -v script >/dev/null; then
  mkdir -p "$tmp/cancel-home"
  printf 'preserve me\n' > "$tmp/cancel-home/.bashrc"
  printf 'n\n' | script -qec "HOME='$tmp/cancel-home' bash '$repo/scripts/setup-machine.sh' --apply --shell" /dev/null > "$tmp/cancel.log"
  grep -q 'Cancelled; no changes made' "$tmp/cancel.log"
  [[ ! -L "$tmp/cancel-home/.bashrc" ]]
  [[ "$(cat "$tmp/cancel-home/.bashrc")" == 'preserve me' ]]
fi

echo 'PASS: preview, confirmation gates, repeat runs, conflicts, backups, and combined shell/AI config are isolated and safe.'
