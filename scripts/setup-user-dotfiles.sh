#!/usr/bin/env bash
# Back up and link selected legacy shell/Vim files without touching other config.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode=''
shell_config=false
vim_config=false
while (($#)); do
  case "$1" in
    --dry-run) mode=dry-run ;;
    --apply) mode=apply ;;
    --shell) shell_config=true ;;
    --vim) vim_config=true ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
[[ -n "$mode" ]] || { echo 'Specify --dry-run or --apply.' >&2; exit 2; }
[[ "$shell_config" == true || "$vim_config" == true ]] || { echo 'Select --shell and/or --vim.' >&2; exit 2; }

shell_files=(.bashrc .bashrc_custom .bash/prompt.sh .zshrc .git-completion.bash .gitignore_global)
vim_files=(.vimrc)
files=()
[[ "$shell_config" == true ]] && files+=("${shell_files[@]}")
[[ "$vim_config" == true ]] && files+=("${vim_files[@]}")
stamp="$(date -u +%Y%m%dT%H%M%S.%NZ)"
backup_root="$HOME/.local/state/dotfiles/backups/$stamp"

for relative in "${files[@]}"; do
  source="$repo/$relative"
  target="$HOME/$relative"
  [[ -f "$source" ]] || { echo "Missing dotfile source: $source" >&2; exit 1; }
  if [[ -L "$target" ]]; then
    if [[ "$(readlink -f "$target")" == "$(readlink -f "$source")" ]]; then
      echo "[unchanged] $target"
      continue
    fi
    echo "Refusing to replace symlink target: $target" >&2
    exit 1
  fi
  if [[ -e "$target" && ! -f "$target" ]]; then
    echo "Refusing to replace non-regular target: $target" >&2
    exit 1
  fi
  if [[ -f "$target" ]]; then
    if cmp -s -- "$source" "$target"; then
      echo "[unchanged] $target (identical regular file; left in place)"
      continue
    fi
    echo "[backup] $target -> $backup_root/$relative"
  fi
  if [[ "$mode" == dry-run ]]; then
    echo "[preview] symlink $target -> $source"
  else
    if [[ -f "$target" ]]; then
      destination="$backup_root/$relative"
      [[ ! -e "$destination" ]] || { echo "Backup already exists: $destination" >&2; exit 1; }
      mkdir -p "$(dirname "$destination")"
      chmod 700 "$backup_root" "$(dirname "$destination")"
      cp -p -- "$target" "$destination"
      chmod 600 "$destination"
      rm -- "$target"
    fi
    mkdir -p "$(dirname "$target")"
    ln -s "$source" "$target"
    echo "[linked] $target"
  fi
done
