#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR"

BACKUP_DIR="${HOME}/.dotfiles_backup_$(date +%Y%m%d_%H%m%s)"

declare -a FILES=(
    ".bashrc"
    ".bashrc_custom"
    ".bash/prompt.sh"
    ".vimrc"
    ".git-completion.bash"
    ".gitignore_global"
    "iptables.rules"
    "nftables.rules"
    ".zshrc"
)

echo "=== Dotfiles Installer ==="
echo "Dotfiles directory: $DOTFILES_DIR"
echo ""

if [[ "$1" == "--dry-run" ]]; then
    echo "[DRY RUN] No changes will be made."
    echo ""
fi

read -p "Create backup of existing dotfiles? [Y/n] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    if [[ "$1" == "--dry-run" ]]; then
        echo "[DRY RUN] Would create backup directory: $BACKUP_DIR"
    else
        mkdir -p "$BACKUP_DIR"
        echo "Backup directory created: $BACKUP_DIR"
    fi
fi

for file in "${FILES[@]}"; do
    target="${HOME}/${file}"
    source="${DOTFILES_DIR}/${file}"

    if [[ ! -e "$source" ]]; then
        echo "[SKIP] ${file}: source not found"
        continue
    fi

    if [[ -e "$target" || -L "$target" ]]; then
        if [[ "$1" == "--dry-run" ]]; then
            echo "[DRY RUN] Would replace: ${target}"
        else
            if [[ ! -L "$target" || "$(readlink "$target")" != "$source" ]]; then
                if [[ -e "$BACKUP_DIR" ]]; then
                    cp -r "$target" "$BACKUP_DIR/" 2>/dev/null || true
                fi
                rm -rf "$target"
            fi
        fi
    fi

    if [[ ! -e "$target" ]]; then
        if [[ "$1" == "--dry-run" ]]; then
            echo "[DRY RUN] Would symlink: ${target} -> ${source}"
        else
            mkdir -p "$(dirname "$target")"
            ln -s "$source" "$target"
            echo "[LINKED] ${file}"
        fi
    else
        echo "[SKIP] ${file}: already linked"
    fi
done

echo ""
echo "=== Installation Complete ==="

if [[ "$1" != "--dry-run" ]]; then
    echo ""
    echo "To apply changes, run:"
    echo "  source ~/.bashrc    # for bash"
    echo "  source ~/.zshrc     # for zsh"
fi
