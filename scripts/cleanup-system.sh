#!/usr/bin/env bash
# Conservative monthly cleanup. Dry-run is the default; only --apply mutates.
set -euo pipefail

readonly AGE_DAYS=30
mode=dry-run
case "${1:-}" in
  "") ;;
  --dry-run) mode=dry-run ;;
  --apply) mode=apply ;;
  -h|--help)
    cat <<'HELP'
Usage: cleanup-system.sh [--dry-run|--apply]

Default/--dry-run: report Docker build cache older than 30 days, old images,
Git repository sizes, and stale worktree metadata. Nothing is removed.
--apply: prune only Docker build cache older than 30 days and run
`git maintenance run --auto` in discovered repositories.

Images, containers, volumes, branches, worktrees, project files, application
caches, package caches, logs, and user data are never deleted by this script.
HELP
    exit 0
    ;;
  *) echo "Unknown option: $1 (use --dry-run, --apply, or --help)" >&2; exit 2 ;;
esac

cutoff_epoch=$(( $(date +%s) - AGE_DAYS * 86400 ))
cutoff_label="$(date -u -d "@$cutoff_epoch" '+%Y-%m-%d %H:%M UTC')"
printf 'Monthly cleanup (%s); age threshold: %s days (before %s)\n' "$mode" "$AGE_DAYS" "$cutoff_label"
printf 'Docker images and stale worktree metadata are report-only.\n\n'

if [[ "$mode" == apply ]]; then
  command -v flock >/dev/null || { echo 'flock is required for safe scheduled runs.' >&2; exit 1; }
  state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
  mkdir -p "$state_dir"
  exec 9>"$state_dir/monthly-cleanup.lock"
  flock -n 9 || { echo 'Another cleanup run is active; exiting.'; exit 0; }
fi

if command -v docker >/dev/null && docker info >/dev/null 2>&1 && docker buildx version >/dev/null 2>&1; then
  printf '%s\n' 'Docker build cache (current Buildx builder):'
  if docker_cache_json="$(docker buildx du --format '{{json .}}' 2>/dev/null)"; then
    DOCKER_CACHE_JSON="$docker_cache_json" python3 - "$cutoff_epoch" <<'PY'
import datetime, json, os, re, sys

cutoff = datetime.datetime.fromtimestamp(int(sys.argv[1]), datetime.timezone.utc)
rows = [json.loads(line) for line in os.environ.get("DOCKER_CACHE_JSON", "").splitlines() if line.strip()]
units = {"B": 1, "kB": 1000, "MB": 1000**2, "GB": 1000**3, "TB": 1000**4,
         "KiB": 1024, "MiB": 1024**2, "GiB": 1024**3, "TiB": 1024**4}

def created_at(value):
  value = value.removesuffix(" UTC")
  value = re.sub(r"(\.\d{6})\d+(?= )", r"\1", value)
  for fmt in ("%Y-%m-%d %H:%M:%S.%f %z", "%Y-%m-%d %H:%M:%S %z"):
    try:
      return datetime.datetime.strptime(value, fmt).astimezone(datetime.timezone.utc)
    except ValueError:
      pass
  return None

def size_bytes(value):
  match = re.fullmatch(r"([0-9.]+)\s*([A-Za-z]+)", value or "")
  return int(float(match.group(1)) * units[match.group(2)]) if match and match.group(2) in units else 0

eligible = []
unparsed = 0
for row in rows:
  created = created_at(row.get("CreatedAt", ""))
  if created is None:
    unparsed += 1
  elif created < cutoff and row.get("Reclaimable") is True:
    eligible.append(row)

total = sum(size_bytes(row.get("Size", "")) for row in eligible)
print(f"  Reclaimable cache records older than threshold: {len(eligible)}")
print(f"  Estimated space: {total / 1000**3:.2f} GB (shared records may reduce actual recovery)")
for row in sorted(eligible, key=lambda r: r.get("CreatedAt", "")):
  print(f"  {row.get('ID', '?')[:12]}  {row.get('Size', '?'):>9}  {row.get('CreatedAt', '?')}  {row.get('Description', '')}")
if unparsed:
  print(f"  Note: could not date {unparsed} cache record(s); excluded from the estimate.")
if not rows:
  print("  No cache records reported by the selected builder.")
PY
  else
    echo '  Could not query build cache; exact dry-run estimate unavailable.'
  fi

  if [[ "$mode" == apply ]]; then
    printf '\nPruning Buildx cache older than %s days…\n' "$AGE_DAYS"
    docker buildx prune --filter "until=$((AGE_DAYS * 24))h" --force
  fi

  printf '\n%s\n' 'Images created more than 30 days ago (review only; none will be removed):'
  if image_json="$(docker image ls --format '{{json .}}' 2>/dev/null)"; then
    DOCKER_IMAGES_JSON="$image_json" python3 - "$cutoff_epoch" <<'PY'
import datetime, json, os, sys

cutoff = datetime.datetime.fromtimestamp(int(sys.argv[1]), datetime.timezone.utc)
rows = [json.loads(line) for line in os.environ.get("DOCKER_IMAGES_JSON", "").splitlines() if line.strip()]
old = []
for row in rows:
  value = row.get("CreatedAt", "").rsplit(" ", 1)[0]
  try:
    created = datetime.datetime.strptime(value, "%Y-%m-%d %H:%M:%S %z").astimezone(datetime.timezone.utc)
  except ValueError:
    continue
  if created < cutoff:
    old.append((created, row))
if not old:
  print("  None reported.")
for _, row in sorted(old):
  print(f"  {row.get('Repository')}:{row.get('Tag')}  {row.get('ID')}  {row.get('CreatedSince')}  {row.get('Size')}  containers={row.get('Containers')}")
PY
  else
    echo '  Could not list images.'
  fi
else
  echo 'Docker/Buildx unavailable or daemon is not running; skipping Docker checks.'
fi

printf '\n%s\n' 'Local Git repositories (maintenance is safe/local; stale worktrees remain report-only):'
git_roots=("$HOME/Dev" "$HOME/Documents" "$HOME/src" "$HOME/Projects")
declare -A seen_common=()
repo_paths=()
repo_sizes=()
repo_count=0
git_total_bytes=0
maintenance_ok=0
maintenance_failed=0
stale_count=0

for root in "${git_roots[@]}"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r -d '' entry; do
    repo="${entry%/.git}"
    common="$(git -C "$repo" rev-parse --git-common-dir 2>/dev/null)" || continue
    [[ "$common" == /* ]] || common="$repo/$common"
    common="$(realpath -m "$common")"
    [[ -n "${seen_common[$common]:-}" ]] && continue
    seen_common[$common]=1
    repo_count=$((repo_count + 1))
    bytes="$(du -sb "$common" 2>/dev/null | awk '{print $1}')"
    bytes="${bytes:-0}"
    repo_paths+=("$repo")
    repo_sizes+=("$bytes")
    git_total_bytes=$((git_total_bytes + bytes))

    stale="$(git -C "$repo" worktree prune --dry-run --verbose --expire=30.days.ago 2>&1 || true)"
    if [[ -n "$stale" ]]; then
      stale_count=$((stale_count + 1))
      printf '  Stale worktree metadata review (%s):\n' "$repo"
      while IFS= read -r line; do printf '    %s\n' "$line"; done <<< "$stale"
    fi

    if [[ "$mode" == apply ]]; then
      if git -C "$repo" maintenance run --auto >/dev/null 2>&1; then
        maintenance_ok=$((maintenance_ok + 1))
      else
        maintenance_failed=$((maintenance_failed + 1))
        printf '  Git maintenance failed for %s; continuing.\n' "$repo"
      fi
    fi
  done < <(find "$root" -xdev \
    \( -type d \( -name node_modules -o -name vendor -o -name .venv -o -name .cache -o -name target \) -prune \) -o \
    \( -type d -name .git -prune -print0 \) -o \
    \( -type f -name .git -print0 \) 2>/dev/null)
done

if (( repo_count == 0 )); then
  echo '  No repositories found under ~/Dev, ~/Documents, ~/src, or ~/Projects.'
else
  printf '  Found %s distinct repositories; total .git data: %s.\n' \
    "$repo_count" "$(numfmt --to=iec --suffix=B "$git_total_bytes")"
  echo '  Largest .git directories:'
  for index in "${!repo_paths[@]}"; do
    printf '%s\t%s\n' "${repo_sizes[$index]}" "${repo_paths[$index]}"
  done | sort -nr | head -10 | while IFS=$'\t' read -r bytes repo; do
    printf '    %s  %s\n' "$(numfmt --to=iec --suffix=B "$bytes")" "$repo"
  done
  printf '  Stale worktree metadata sets to review: %s (not removed).\n' "$stale_count"
  if [[ "$mode" == apply ]]; then
    printf '  Git maintenance: %s succeeded, %s failed.\n' "$maintenance_ok" "$maintenance_failed"
  else
    printf '  Would run: git maintenance run --auto in %s repositories.\n' "$repo_count"
  fi
fi

cat <<'NOTICE'

Not touched: Docker images/containers/volumes, branches, worktree metadata,
project/build directories, package caches, browser/app caches, logs, or personal data.
NOTICE

if [[ "$mode" == dry-run ]]; then
  echo 'Dry-run only; nothing was removed. Use --apply after reviewing this report.'
else
  echo 'Cleanup complete.'
fi
