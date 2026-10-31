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
if [[ "$1" == buildx && "$2" == du ]]; then
  [[ "${CACHE_FAIL:-0}" != 1 ]] || exit 1
  cat "$CACHE_FIXTURE"; exit 0
fi
if [[ "$1" == image && "$2" == ls ]]; then cat "$IMAGE_FIXTURE"; exit 0; fi
if [[ "$1" == buildx && "$2" == prune ]]; then echo 'Total: 1.2GB'; exit 0; fi
exit 0
DOCKER

cat > "$tmp/bin/git" <<'GIT'
#!/usr/bin/env bash
set -euo pipefail
if [[ " $* " == *" maintenance run --auto "* ]]; then
  printf '%s\n' "$*" >> "$GIT_MAINTENANCE_LOG"
  exit 0
fi
if [[ "${FAKE_STALE:-0}" == 1 && " $* " == *" worktree prune "* ]]; then
  printf '%s\n' "$*" >> "$WORKTREE_LOG"
  echo 'Removing worktrees/gone: gitdir file points to non-existent location'
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
export WORKTREE_LOG="$tmp/worktree.log"

for option in '' --dry-run; do
  output="$(bash "$repo/scripts/cleanup-system.sh" $option)"
  ! grep -q 'old-reclaima' <<< "$output"
  ! grep -q 'recent-reclaim' <<< "$output"
  ! grep -q 'old-shared' <<< "$output"
  ! grep -q 'legacy/postgres:old' <<< "$output"
  ! grep -q 'active/app:latest' <<< "$output"
  grep -q 'Dry-run only; nothing was removed' <<< "$output"
  grep -q 'Docker Buildx cache: 1 candidate records; estimated 1.50 GB' <<< "$output"
  grep -q 'Total estimated space: 1.50 GB' <<< "$output"
  grep -q 'Git maintenance: planned for 1 repositories; space savings unknown' <<< "$output"
  grep -q 'Not removed: Docker images (listed with --verbose) and 0 sets of stale worktree metadata' <<< "$output"
done

output="$(bash "$repo/scripts/cleanup-system.sh" --dry-run --verbose)"
grep -q 'Reclaimable cache records older than threshold: 1' <<< "$output"
grep -q 'old-reclaima' <<< "$output"
grep -q 'legacy/postgres:old' <<< "$output"

output="$(CACHE_FAIL=1 bash "$repo/scripts/cleanup-system.sh" --dry-run)"
grep -q 'Total estimated space: unavailable' <<< "$output"
empty_cache="$tmp/empty.jsonl"
: > "$empty_cache"
output="$(CACHE_FIXTURE="$empty_cache" bash "$repo/scripts/cleanup-system.sh" --dry-run)"
grep -q 'Docker Buildx cache: 0 candidate records; estimated 0.00 GB' <<< "$output"
[[ "$output" != *$'\033['* ]] || { echo 'Non-terminal output contains color codes.' >&2; exit 1; }

python3 - "$repo/scripts/cleanup-system.sh" <<'PY'
import os, pty, subprocess, sys

def capture(extra):
  master, slave = pty.openpty()
  env = dict(os.environ, TERM='xterm', **extra)
  if 'NO_COLOR' not in extra:
    env.pop('NO_COLOR', None)
  proc = subprocess.Popen(['bash', sys.argv[1], '--dry-run'], stdout=slave, stderr=subprocess.PIPE, env=env)
  os.close(slave)
  data = b''
  while True:
    try:
      chunk = os.read(master, 65536)
      if not chunk:
        break
      data += chunk
    except OSError:
      break
  os.close(master)
  assert proc.wait() == 0, proc.stderr.read().decode()
  return data

colored = capture({})
assert b'\x1b[1;36mCleanup summary:\x1b[0m' in colored
assert b'\x1b[1;33m  Total estimated space:' in colored
assert b'\x1b[1;34m  Not removed:' in colored
assert b'\x1b[1;32m  Docker Buildx cache:' in colored
assert b'\x1b[' not in capture({'NO_COLOR': '1'})
PY

if grep -Eq 'buildx prune|image rm' "$DOCKER_LOG"; then
  echo 'Dry-run called a destructive Docker command.' >&2
  exit 1
fi
[[ ! -s "$GIT_MAINTENANCE_LOG" ]] || { echo 'Dry-run ran Git maintenance.' >&2; exit 1; }
[[ ! -e "$HOME/.local/state/dotfiles/monthly-cleanup.lock" ]] || { echo 'Dry-run created the apply lock.' >&2; exit 1; }

output="$(bash "$repo/scripts/cleanup-system.sh" --apply)"
grep -q 'Git maintenance: 1 succeeded, 0 failed' <<< "$output"
grep -q 'Cleanup complete' <<< "$output"
grep -q 'Docker Buildx cache: prune completed; prior estimate 1 candidate records, 1.50 GB' <<< "$output"
grep -q 'Git maintenance: 1 succeeded, 0 failed; space savings unknown' <<< "$output"
grep -q 'Docker Buildx reported reclaimed: 1.2GB' <<< "$output"
grep -q 'Git .git size change:' <<< "$output"
grep -q 'buildx prune --filter until=720h --force' "$DOCKER_LOG"
grep -q 'maintenance run --auto' "$GIT_MAINTENANCE_LOG"
! grep -q 'image rm' "$DOCKER_LOG"

: > "$DOCKER_LOG"
: > "$GIT_MAINTENANCE_LOG"
output="$(bash "$repo/scripts/cleanup-system.sh" --apply --git)"
[[ ! -s "$DOCKER_LOG" ]] || { echo 'Git-only mode called Docker.' >&2; exit 1; }
grep -q 'maintenance run --auto' "$GIT_MAINTENANCE_LOG"

: > "$DOCKER_LOG"
: > "$GIT_MAINTENANCE_LOG"
output="$(bash "$repo/scripts/cleanup-system.sh" --apply --docker)"
grep -q 'buildx prune' "$DOCKER_LOG"
[[ ! -s "$GIT_MAINTENANCE_LOG" ]] || { echo 'Docker-only mode ran Git maintenance.' >&2; exit 1; }

: > "$DOCKER_LOG"
: > "$GIT_MAINTENANCE_LOG"
output="$(bash "$repo/scripts/cleanup-system.sh" --worktrees)"
grep -q 'Worktree metadata: 0 repositories with candidates; preview only' <<< "$output"
[[ ! -s "$DOCKER_LOG" && ! -s "$GIT_MAINTENANCE_LOG" ]] || { echo 'Worktree preview ran unrelated cleanup.' >&2; exit 1; }

output="$(FAKE_STALE=1 bash "$repo/scripts/cleanup-system.sh" --worktrees --dry-run)"
grep -q 'worktree prune --dry-run --verbose --expire=30.days.ago' "$WORKTREE_LOG"
! grep -q 'worktree prune --verbose --expire=30.days.ago' "$WORKTREE_LOG"
grep -q '1 repositories with candidates; preview only' <<< "$output"
: > "$WORKTREE_LOG"
output="$(FAKE_STALE=1 bash "$repo/scripts/cleanup-system.sh" --worktrees --apply)"
grep -q 'worktree prune --verbose --expire=30.days.ago' "$WORKTREE_LOG"
grep -q 'Worktree metadata prune: 1 repositories succeeded, 0 failed' <<< "$output"

echo 'PASS: default and explicit dry-runs are non-destructive; apply uses only age-filtered cache prune and Git --auto.'
