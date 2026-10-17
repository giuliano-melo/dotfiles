#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${1:-}" != "ai" ]]; then
  echo "Usage: bash setup.sh ai {install|configure|server|check|launch|test} [options]"
  echo "Existing shell/editor deployment remains available through bash install.sh."
  exit 1
fi
shift
exec bash "${script_dir}/scripts/setup-ai.sh" "$@"
