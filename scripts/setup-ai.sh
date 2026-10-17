#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! command -v python3 >/dev/null; then
  echo "Install Python 3.11+ first (Ubuntu: sudo apt install python3)." >&2
  exit 1
fi
if [[ "${1:-}" == "test" ]]; then
  shift
  exec python3 "${script_dir}/test-ai.py" "$@"
fi
exec python3 "${script_dir}/ai-stack.py" "$@"
