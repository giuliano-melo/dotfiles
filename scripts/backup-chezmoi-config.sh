#!/usr/bin/env bash
set -euo pipefail

repo="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
[[ -d "$repo/chezmoi" ]] || { echo "Missing chezmoi source: $repo/chezmoi" >&2; exit 1; }

stamp="$(date -u +%Y%m%dT%H%M%S.%NZ)"
backup_root="$HOME/.local/state/dotfiles/backups/$stamp"

backup_if_different() {
  local target="$1" source="$2" relative destination
  [[ -f "$source" ]] || { echo "Missing managed source file: $source" >&2; exit 1; }
  [[ -e "$target" || -L "$target" ]] || return 0
  [[ ! -L "$target" && -f "$target" ]] || {
    echo "Refusing to replace a non-regular chezmoi target: $target" >&2
    exit 1
  }
  cmp -s -- "$target" "$source" && return 0
  relative="${target#"$HOME"/}"
  destination="$backup_root/$relative"
  [[ ! -e "$destination" ]] || { echo "Backup already exists: $destination" >&2; exit 1; }
  mkdir -p "$(dirname "$destination")"
  chmod 700 "$backup_root" "$(dirname "$destination")"
  cp -- "$target" "$destination"
  chmod 600 "$destination"
  echo "Backed up existing config to $destination"
}

# Keep this list aligned with the files managed by the curated chezmoi source.
backup_if_different "$HOME/.config/ai-stack/ai-stack.zsh" "$repo/chezmoi/dot_config/ai-stack/ai-stack.zsh"
backup_if_different "$HOME/.config/ai-usagebar/config.toml" "$repo/chezmoi/dot_config/ai-usagebar/private_config.toml"
