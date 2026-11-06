#!/usr/bin/env bash
# Install the gitleaks pre-commit hook into the current repository.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hook_dir="$repo/.git/hooks"
hook="$hook_dir/pre-commit"

mkdir -p "$hook_dir"

cat > "$hook" <<'HOOK'
#!/usr/bin/env bash
# Pre-commit hook: block secrets using gitleaks if available on the host.
set -euo pipefail

if command -v gitleaks > /dev/null 2>&1; then
  gitleaks detect --source . --verbose
elif [[ -x /tmp/gitleaks ]]; then
  /tmp/gitleaks detect --source . --verbose
else
  echo 'gitleaks not found; install it from https://github.com/gitleaks/gitleaks' >&2
  echo '  (or run scripts/install-gitleaks.sh)' >&2
fi
HOOK

chmod +x "$hook"
echo "Installed pre-commit hook: $hook"
