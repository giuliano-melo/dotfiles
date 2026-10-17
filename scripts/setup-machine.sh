#!/usr/bin/env bash
# Selective, preview-first setup for a new Linux machine.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
apply=false
assume_yes=false
system_packages=false
user_config=false
shell_config=false
vim_config=false
ai_tools=false
ai_config=false
cleanup_timer=false
selected_any=false

usage() {
  cat <<'HELP'
Usage: bash scripts/setup-machine.sh [OPTIONS]

With no component flags, a terminal presents a checklist. Without --apply,
selected components are previewed only. Applying always shows the full preview
and asks for confirmation unless --yes is supplied.

Components:
  --system-packages  Install Ansible prerequisites and supported host packages
  --user-config      Preview/apply the curated chezmoi-managed user config
  --shell            Install selected Bash/Zsh and shell support dotfiles
  --vim              Install the Vim configuration
  --ai               Install pinned AI CLI tools (does not sign in)
  --ai-config        Configure AI shell/MCP/skill integration (no sign-in/hooks)
  --cleanup-timer    Install and enable the monthly cleanup user timer (opt-in)
  --all              Select all components except the cleanup timer

Modes:
  --dry-run          Preview only (the default)
  --apply            Apply selected components after preview/confirmation
  --yes              Skip final confirmation; requires --apply
  -h, --help         Show this help

Examples:
  bash scripts/setup-machine.sh
  bash scripts/setup-machine.sh --apply                 # interactive checklist
  bash scripts/setup-machine.sh --dry-run --shell --vim
  bash scripts/setup-machine.sh --apply --system-packages --user-config

No OS upgrades, security-policy changes, credential sign-ins, or data restores.
Existing files selected for shell/Vim deployment are backed up before linking.
HELP
}

while (($#)); do
  case "$1" in
    --apply) apply=true ;;
    --dry-run) apply=false ;;
    --yes) assume_yes=true ;;
    --system-packages) system_packages=true; selected_any=true ;;
    --user-config|--chezmoi) user_config=true; selected_any=true ;;
    --shell) shell_config=true; selected_any=true ;;
    --vim) vim_config=true; selected_any=true ;;
    --ai) ai_tools=true; selected_any=true ;;
    --ai-config) ai_config=true; selected_any=true ;;
    --cleanup-timer) cleanup_timer=true; selected_any=true ;;
    --all)
      system_packages=true
      user_config=true
      shell_config=true
      vim_config=true
      ai_tools=true
      ai_config=true
      selected_any=true
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "$assume_yes" == true && "$apply" != true ]]; then
  echo '--yes is only valid with --apply.' >&2
  exit 2
fi

if [[ "$selected_any" != true ]]; then
  if [[ -t 0 ]]; then
    echo 'Choose components (cleanup scheduling is deliberately opt-in).'
    while :; do
      printf '\n  1) [%s] System packages\n' "$([[ $system_packages == true ]] && echo x || echo ' ')"
      printf '  2) [%s] Curated chezmoi user config\n' "$([[ $user_config == true ]] && echo x || echo ' ')"
      printf '  3) [%s] Shell dotfiles (Bash/Zsh)\n' "$([[ $shell_config == true ]] && echo x || echo ' ')"
      printf '  4) [%s] Vim config\n' "$([[ $vim_config == true ]] && echo x || echo ' ')"
      printf '  5) [%s] AI CLI tools (no sign-in)\n' "$([[ $ai_tools == true ]] && echo x || echo ' ')"
      printf '  6) [%s] AI integrations (requires chezmoi user config)\n' "$([[ $ai_config == true ]] && echo x || echo ' ')"
      printf '  7) [%s] Monthly cleanup timer (opt-in)\n' "$([[ $cleanup_timer == true ]] && echo x || echo ' ')"
      read -r -p 'Toggle 1-7, "all" (except timer), "none", or Enter to continue: ' choice
      case "$choice" in
        '') break ;;
        all)
          system_packages=true; user_config=true; shell_config=true
          vim_config=true; ai_tools=true; ai_config=true; cleanup_timer=false
          ;;
        none)
          system_packages=false; user_config=false; shell_config=false
          vim_config=false; ai_tools=false; ai_config=false; cleanup_timer=false
          ;;
        *)
          read -r -a toggles <<< "${choice//,/ }"
          for toggle in "${toggles[@]}"; do
            case "$toggle" in
              1) system_packages=$([[ $system_packages == true ]] && echo false || echo true) ;;
              2) user_config=$([[ $user_config == true ]] && echo false || echo true) ;;
              3) shell_config=$([[ $shell_config == true ]] && echo false || echo true) ;;
              4) vim_config=$([[ $vim_config == true ]] && echo false || echo true) ;;
              5) ai_tools=$([[ $ai_tools == true ]] && echo false || echo true) ;;
              6) ai_config=$([[ $ai_config == true ]] && echo false || echo true) ;;
              7) cleanup_timer=$([[ $cleanup_timer == true ]] && echo false || echo true) ;;
              *) echo "Ignoring invalid selection: $toggle" ;;
            esac
          done
          ;;
      esac
    done
    selected_any=true
  else
    echo 'No components selected. Use the checklist in a terminal or pass component flags.' >&2
    usage >&2
    exit 2
  fi
fi

if [[ "$system_packages" == false && "$user_config" == false && "$shell_config" == false \
  && "$vim_config" == false && "$ai_tools" == false && "$ai_config" == false \
  && "$cleanup_timer" == false ]]; then
  echo 'Nothing selected; exiting without changes.'
  exit 0
fi

if [[ "$ai_config" == true && "$user_config" != true \
  && ! -f "$HOME/.config/ai-stack/ai-stack.zsh" ]]; then
  echo 'AI integrations require --user-config unless its managed launcher is already installed.' >&2
  echo 'Select both components on a new machine.' >&2
  exit 2
fi

if [[ ! -r /etc/os-release ]]; then
  echo 'Cannot identify this Linux distribution.' >&2
  exit 1
fi
# shellcheck disable=SC1091
source /etc/os-release
case "${ID:-}:${ID_LIKE:-}" in
  ubuntu:*|debian:*|*:debian*) manager=apt; ansible_package=ansible-core ;;
  fedora:*|*:fedora*) manager=dnf; ansible_package=ansible-core ;;
  arch:*|manjaro:*|endeavouros:*|*:arch*) manager=pacman; ansible_package=ansible ;;
  *)
    if [[ "$system_packages" == true ]]; then
      echo "Unsupported distro: ${PRETTY_NAME:-${ID:-unknown}}" >&2
      exit 1
    fi
    manager=unsupported
    ;;
esac

selected=()
[[ "$system_packages" == true ]] && selected+=(system-packages)
[[ "$user_config" == true ]] && selected+=(user-config)
[[ "$shell_config" == true ]] && selected+=(shell)
[[ "$vim_config" == true ]] && selected+=(vim)
[[ "$ai_tools" == true ]] && selected+=(ai)
[[ "$ai_config" == true ]] && selected+=(ai-config)
[[ "$cleanup_timer" == true ]] && selected+=(cleanup-timer)

echo 'Selected setup components:'
printf '  - %s\n' "${selected[@]}"
if [[ "$apply" == true ]]; then
  echo 'Mode: APPLY (nothing runs until the preview is confirmed)'
else
  echo 'Mode: DRY RUN (no changes will be made)'
fi

preview() {
  echo
  echo '--- Preview ---'
  if [[ "$system_packages" == true ]]; then
    case "$manager" in
      apt) printf 'System packages: sudo apt-get update && sudo apt-get install -y %s (only if Ansible is missing)\n' "$ansible_package" ;;
      dnf) printf 'System packages: sudo dnf install -y %s (only if Ansible is missing)\n' "$ansible_package" ;;
      pacman) printf 'System packages: sudo pacman -S --needed %s (only if Ansible is missing)\n' "$ansible_package" ;;
    esac
    printf 'Ansible play: %s\n' "$repo/ansible/site.yml"
  fi
  if [[ "$user_config" == true ]]; then
    command -v chezmoi >/dev/null || { echo 'Install chezmoi from its official instructions before selecting --user-config.' >&2; return 1; }
    echo 'Curated user configuration diff:'
    chezmoi --source "$repo/chezmoi" diff
  fi
  if [[ "$shell_config" == true || "$vim_config" == true ]]; then
    local_args=(--dry-run)
    [[ "$shell_config" == true ]] && local_args+=(--shell)
    [[ "$vim_config" == true ]] && local_args+=(--vim)
    bash "$repo/scripts/setup-user-dotfiles.sh" "${local_args[@]}"
  fi
  if [[ "$ai_tools" == true ]]; then
    bash "$repo/setup.sh" ai install --dry-run
  fi
  if [[ "$ai_config" == true ]]; then
    bash "$repo/setup.sh" ai configure --dry-run
  fi
  if [[ "$cleanup_timer" == true ]]; then
    check_timer_units || return 1
    echo 'Monthly cleanup timer dry-run (reports scope; does not enable the timer):'
    bash "$repo/scripts/cleanup-system.sh" --dry-run
    printf 'Would install user units under %s/.config/systemd/user and enable the monthly timer.\n' "$HOME"
  fi
}

check_timer_units() {
  if [[ "$repo" != "$HOME/Dev/dotfiles" ]]; then
    echo "Cleanup timer unit assumes the repository is at $HOME/Dev/dotfiles; current path is $repo." >&2
    return 1
  fi
  local user_units="$HOME/.config/systemd/user"
  for unit in dotfiles-monthly-cleanup.service dotfiles-monthly-cleanup.timer; do
    local destination="$user_units/$unit"
    local source="$repo/systemd/user/$unit"
    if [[ -e "$destination" || -L "$destination" ]]; then
      if [[ ! -L "$destination" || "$(readlink -f "$destination")" != "$(readlink -f "$source")" ]]; then
        echo "Refusing to replace existing systemd unit: $destination" >&2
        return 1
      fi
    fi
  done
}

if [[ "$cleanup_timer" == true ]] && ! check_timer_units; then
  exit 1
fi

if ! preview; then
  exit 1
fi

if [[ "$apply" != true ]]; then
  echo
  echo 'Dry-run complete. Use --apply with the same component flags (or checklist selection) to proceed.'
  exit 0
fi

if [[ "$user_config" == true ]] && ! command -v chezmoi >/dev/null; then
  echo 'Install chezmoi from https://www.chezmoi.io/install/ before applying user config.' >&2
  exit 1
fi
if [[ ( "$ai_tools" == true || "$ai_config" == true ) ]] && ! command -v python3 >/dev/null; then
  echo 'Python 3.11+ is required for AI setup.' >&2
  exit 1
fi
if [[ "$cleanup_timer" == true ]] && ! command -v systemctl >/dev/null; then
  echo 'systemctl is required to enable the cleanup user timer.' >&2
  exit 1
fi

if [[ "$assume_yes" != true ]]; then
  [[ -t 0 ]] || { echo 'Applying non-interactively requires --yes after explicit component flags.' >&2; exit 2; }
  read -r -p $'\nApply exactly these selected components? [y/N] ' reply
  [[ "$reply" == [yY] ]] || { echo 'Cancelled; no changes made.'; exit 0; }
fi

if [[ "$system_packages" == true ]]; then
  if ! command -v ansible-playbook >/dev/null; then
    case "$manager" in
      apt) sudo apt-get update; sudo apt-get install -y "$ansible_package" ;;
      dnf) sudo dnf install -y "$ansible_package" ;;
      pacman) sudo pacman -S --needed --noconfirm "$ansible_package" ;;
    esac
  fi
  command -v ansible-playbook >/dev/null || { echo 'Ansible installation failed.' >&2; exit 1; }
  ansible-playbook -i localhost, -c local "$repo/ansible/site.yml" --ask-become-pass
fi

if [[ "$shell_config" == true || "$vim_config" == true ]]; then
  local_args=(--apply)
  [[ "$shell_config" == true ]] && local_args+=(--shell)
  [[ "$vim_config" == true ]] && local_args+=(--vim)
  bash "$repo/scripts/setup-user-dotfiles.sh" "${local_args[@]}"
fi

if [[ "$user_config" == true ]]; then
  bash "$repo/scripts/backup-chezmoi-config.sh" "$repo"
  chezmoi --source "$repo/chezmoi" apply --force
fi

if [[ "$ai_tools" == true ]]; then
  bash "$repo/setup.sh" ai install
fi
if [[ "$ai_config" == true ]]; then
  bash "$repo/setup.sh" ai configure
fi

if [[ "$cleanup_timer" == true ]]; then
  user_units="$HOME/.config/systemd/user"
  mkdir -p "$user_units"
  for unit in dotfiles-monthly-cleanup.service dotfiles-monthly-cleanup.timer; do
    destination="$user_units/$unit"
    source="$repo/systemd/user/$unit"
    if [[ ! -e "$destination" && ! -L "$destination" ]]; then
      ln -s "$source" "$destination"
    fi
  done
  systemctl --user daemon-reload
  systemctl --user enable --now dotfiles-monthly-cleanup.timer
fi

echo
echo 'Selected setup components completed.'
