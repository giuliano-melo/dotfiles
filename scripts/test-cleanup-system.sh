#!/usr/bin/env bash
# Isolated cleanup tests: fake Docker and Git maintenance commands, temp HOME.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d /tmp/opencode/cleanup-test.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home/Dev/sample"

real_git="$(command -v git)"
git init --quiet "$tmp/home/Dev/sample"

python3 - "$tmp/cache.jsonl" "$tmp/images.jsonl" <<'PY'
import datetime, json, sys
now = datetime.datetime.now(datetime.timezone.utc)
def stamp(days, cache=False):
  value = now - datetime.timedelta(days=days)
  if cache:
    return value.strftime('%Y-%m-%d %H:%M:%S.123456000 +0000 UTC')
  return value.strftime('%Y-%m-%d %H:%M:%S +0000 UTC')
cache = [
  {'ID':'old-reclaimable', 'CreatedAt':stamp(45, True), 'Reclaimable':True, 'Size':'1.5GB', 'Description':'old build layer'},
  {'ID':'recent-reclaimable', 'CreatedAt':stamp(10, True), 'Reclaimable':True, 'Size':'2GB', 'Description':'recent build layer'},
  {'ID':'old-shared', 'CreatedAt':stamp(60, True), 'Reclaimable':False, 'Size':'3GB', 'Description':'shared layer'},
]
images = [
  {'Repository':'legacy/postgres', 'Tag':'old', 'ID':'oldimage', 'CreatedAt':stamp(45), 'CreatedSince':'6 weeks ago', 'Size':'400MB', 'Containers':'0'},
  {'Repository':'active/app', 'Tag':'latest', 'ID':'newimage', 'CreatedAt':stamp(2), 'CreatedSince':'2 days ago', 'Size':'300MB', 'Containers':'1'},
]
for path, rows in [(sys.argv[1], cache), (sys.argv[2], images)]:
  with open(path, 'w') as stream:
    for row in rows:
      stream.write(json.dumps(row) + '\n')
PY

cat > "$tmp/bin/docker" <<'DOCKER'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$DOCKER_LOG"
if [[ "$1" == info || ( "$1" == buildx && "$2" == version ) ]]; then exit 0; fi
if [[ "$1" == buildx && "$2" == du ]]; then cat "$CACHE_FIXTURE"; exit 0; fi
if [[ "$1" == image && "$2" == ls ]]; then cat "$IMAGE_FIXTURE"; exit 0; fi
exit 0
DOCKER

cat > "$tmp/bin/git" <<'GIT'
#!/usr/bin/env bash
set -euo pipefail
if [[ " $* " == *" maintenance run --auto "* ]]; then
  printf '%s\n' "$*" >> "$GIT_MAINTENANCE_LOG"
  exit 0
fi
exec "$REAL_GIT" "$@"
GIT
chmod 755 "$tmp/bin/docker" "$tmp/bin/git"

export HOME="$tmp/home"
export PATH="$tmp/bin:$PATH"
export REAL_GIT="$real_git"
export CACHE_FIXTURE="$tmp/cache.jsonl"
export IMAGE_FIXTURE="$tmp/images.jsonl"
export DOCKER_LOG="$tmp/docker.log"
export GIT_MAINTENANCE_LOG="$tmp/git-maintenance.log"

for option in '' --dry-run; do
  output="$(bash "$repo/scripts/cleanup-system.sh" $option)"
  grep -q 'Reclaimable cache records older than threshold: 1' <<< "$output"
  grep -q 'Estimated space: 1.50 GB' <<< "$output"
  grep -q 'old-reclaima' <<< "$output"
  ! grep -q 'recent-reclaim' <<< "$output"
  ! grep -q 'old-shared' <<< "$output"
  grep -q 'legacy/postgres:old' <<< "$output"
  ! grep -q 'active/app:latest' <<< "$output"
  grep -q 'Dry-run only; nothing was removed' <<< "$output"
done

if grep -Eq 'buildx prune|image rm' "$DOCKER_LOG"; then
  echo 'Dry-run called a destructive Docker command.' >&2
  exit 1
fi
[[ ! -s "$GIT_MAINTENANCE_LOG" ]] || { echo 'Dry-run ran Git maintenance.' >&2; exit 1; }
[[ ! -e "$HOME/.local/state/dotfiles/monthly-cleanup.lock" ]] || { echo 'Dry-run created the apply lock.' >&2; exit 1; }

output="$(bash "$repo/scripts/cleanup-system.sh" --apply)"
grep -q 'Git maintenance: 1 succeeded, 0 failed' <<< "$output"
grep -q 'Cleanup complete' <<< "$output"
grep -q 'buildx prune --filter until=720h --force' "$DOCKER_LOG"
grep -q 'maintenance run --auto' "$GIT_MAINTENANCE_LOG"
! grep -q 'image rm' "$DOCKER_LOG"

echo 'PASS: default and explicit dry-runs are non-destructive; apply uses only age-filtered cache prune and Git --auto.'
