#!/usr/bin/env bash
# Conservative monthly cleanup. Dry-run is the default; only --apply mutates.
set -euo pipefail

readonly AGE_DAYS=30
mode=dry-run
verbose=false
mode_selected=false
select_docker=false select_git=false select_worktrees=false selected=false
while (( $# )); do
case "$1" in
  --dry-run|--apply)
    if $mode_selected; then echo 'Specify only one cleanup mode.' >&2; exit 2; fi
    mode="${1#--}"
    mode_selected=true ;;
  --verbose) verbose=true ;;
  --docker) select_docker=true; selected=true ;;
  --git) select_git=true; selected=true ;;
  --worktrees) select_worktrees=true; selected=true ;;
  -h|--help)
    cat <<'HELP'
Usage: cleanup-system.sh [--dry-run|--apply] [--verbose] [--docker] [--git] [--worktrees]

Default/--dry-run: report Docker build cache older than 30 days, old images,
Git repository sizes, and stale worktree metadata. Nothing is removed.
--apply: prune only Docker build cache older than 30 days and run
`git maintenance run --auto` in discovered repositories.
--verbose: show detailed cache, image, and repository reports.
--docker, --git: select those categories; both are selected by default.
--worktrees: select stale worktree metadata pruning (preview unless --apply).

Images, containers, volumes, branches, worktree directories, project files, application
caches, package caches, logs, and user data are never deleted by this script.
HELP
    exit 0
    ;;
  *) echo "Unknown option: $1 (use --dry-run, --apply, --verbose, or --help)" >&2; exit 2 ;;
esac
shift
done
if ! $selected; then select_docker=true; select_git=true; fi

spinner_pid=''
stop_spinner() {
  if [[ -n "$spinner_pid" ]]; then
    kill "$spinner_pid" 2>/dev/null || true
    wait "$spinner_pid" 2>/dev/null || true
    spinner_pid=''
    printf '\r%*s\r' 80 '' >&2
  fi
}
start_spinner() {
  stop_spinner
  if [[ -t 2 && "${TERM:-}" != dumb ]]; then
    (
      trap 'exit 0' TERM INT
      while :; do
        for frame in '|' '/' '-' '\'; do
          printf '\r%s %s' "$frame" "$1" >&2
          sleep 0.15
        done
      done
    ) &
    spinner_pid=$!
  else
    printf '%s\n' "$1" >&2
  fi
}
trap stop_spinner EXIT

cutoff_epoch=$(( $(date +%s) - AGE_DAYS * 86400 ))
cutoff_label="$(date -u -d "@$cutoff_epoch" '+%Y-%m-%d %H:%M UTC')"
printf 'Monthly cleanup (%s); age threshold: %s days (before %s)\n' "$mode" "$AGE_DAYS" "$cutoff_label"
$verbose && printf 'Docker images and stale worktree metadata are report-only.\n\n'

if [[ "$mode" == apply ]]; then
  command -v flock >/dev/null || { echo 'flock is required for safe scheduled runs.' >&2; exit 1; }
  state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
  mkdir -p "$state_dir"
  exec 9>"$state_dir/monthly-cleanup.lock"
  flock -n 9 || { echo 'Another cleanup run is active; exiting.'; exit 0; }
fi

cache_count=unknown
cache_estimate=unknown
docker_reclaimed=unavailable
if $select_docker; then
start_spinner 'Checking Docker cache and images...'
if command -v docker >/dev/null && docker info >/dev/null 2>&1 && docker buildx version >/dev/null 2>&1; then
  $verbose && printf '%s\n' 'Docker build cache (current Buildx builder):'
  if docker_cache_json="$(docker buildx du --format '{{json .}}' 2>/dev/null)"; then
    cache_report="$(DOCKER_CACHE_JSON="$docker_cache_json" python3 - "$cutoff_epoch" <<'PY'
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
print(f"{len(eligible)} {total / 1000**3:.2f}")
PY
    )"
    if $verbose; then printf '%s\n' "$cache_report" | sed '$d'; fi
    read -r cache_count cache_estimate <<< "${cache_report##*$'\n'}"
  else
    echo '  Could not query build cache; exact dry-run estimate unavailable.'
  fi

  if [[ "$mode" == apply ]]; then
    start_spinner 'Pruning Docker build cache...'
    prune_output="$(docker buildx prune --filter "until=$((AGE_DAYS * 24))h" --force)"
    $verbose && printf '%s\n' "$prune_output"
    docker_reclaimed="$(printf '%s\n' "$prune_output" | sed -n 's/^Total:[[:space:]]*//p' | tail -n 1)"
    docker_reclaimed="${docker_reclaimed:-unavailable}"
  fi

  if $verbose; then
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
  fi
else
  echo 'Docker/Buildx unavailable or daemon is not running; skipping Docker checks.'
fi
fi

if $select_git || $select_worktrees; then
if [[ "$mode" == apply ]]; then
  start_spinner 'Scanning repositories and running Git maintenance...'
else
  start_spinner 'Scanning Git repositories...'
fi
$verbose && printf '\n%s\n' 'Local Git repositories (maintenance is safe/local; stale worktrees remain report-only):'
git_roots=("$HOME/Dev" "$HOME/Documents" "$HOME/src" "$HOME/Projects")
declare -A seen_common=()
repo_paths=()
repo_sizes=()
repo_count=0
git_total_bytes=0
maintenance_ok=0
maintenance_failed=0
stale_count=0
worktree_ok=0 worktree_failed=0
git_after_bytes=0 git_measurement_complete=true

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
    if ! bytes="$(du -sb "$common" 2>/dev/null | awk '{print $1}')" || [[ ! "$bytes" =~ ^[0-9]+$ ]]; then
      bytes=0
      git_measurement_complete=false
    fi
    repo_paths+=("$repo")
    repo_sizes+=("$bytes")
    git_total_bytes=$((git_total_bytes + bytes))

    if ! stale="$(git -C "$repo" worktree prune --dry-run --verbose --expire=30.days.ago 2>&1)"; then
      printf '  Worktree inspection failed for %s: %s\n' "$repo" "$stale" >&2
      worktree_failed=$((worktree_failed + 1))
      stale=''
    fi
    if [[ -n "$stale" ]]; then
      stale_count=$((stale_count + 1))
      if $verbose || $select_worktrees; then
        printf '  Stale worktree metadata review (%s):\n' "$repo"
        while IFS= read -r line; do printf '    %s\n' "$line"; done <<< "$stale"
      fi
    fi

    if [[ "$mode" == apply ]] && $select_worktrees && [[ -n "$stale" ]]; then
      if git -C "$repo" worktree prune --verbose --expire=30.days.ago; then
        worktree_ok=$((worktree_ok + 1))
      else
        worktree_failed=$((worktree_failed + 1))
      fi
    fi
    if [[ "$mode" == apply ]] && $select_git; then
      if git -C "$repo" maintenance run --auto >/dev/null 2>&1; then
        maintenance_ok=$((maintenance_ok + 1))
      else
        maintenance_failed=$((maintenance_failed + 1))
        printf '  Git maintenance failed for %s; continuing.\n' "$repo"
      fi
    fi
    if [[ "$mode" == apply ]] && $select_git; then
      if after="$(du -sb "$common" 2>/dev/null | awk '{print $1}')" && [[ "$after" =~ ^[0-9]+$ ]]; then
        git_after_bytes=$((git_after_bytes + after))
      else
        git_measurement_complete=false
      fi
    fi
  done < <(find "$root" -xdev \
    \( -type d \( -name node_modules -o -name vendor -o -name .venv -o -name .cache -o -name target \) -prune \) -o \
    \( -type d -name .git -prune -print0 \) -o \
    \( -type f -name .git -print0 \) 2>/dev/null)
done

stop_spinner
if $verbose && (( repo_count == 0 )); then
  echo '  No repositories found under ~/Dev, ~/Documents, ~/src, or ~/Projects.'
elif $verbose; then
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
fi

summary_title='' summary_warning='' summary_muted='' summary_error='' summary_success='' summary_reset=''
if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != dumb ]]; then
  summary_title=$'\033[1;36m'
  summary_warning=$'\033[1;33m'
  summary_muted=$'\033[1;34m'
  summary_error=$'\033[1;31m'
  summary_success=$'\033[1;32m'
  summary_reset=$'\033[0m'
fi
printf '\n%s%s%s\n' "$summary_title" 'Cleanup summary:' "$summary_reset"
if $select_docker; then
if [[ "$cache_count" == unknown ]]; then
  printf '%s%s%s\n' "$summary_error" '  Docker Buildx cache: estimate unavailable; Docker/Buildx data could not be queried.' "$summary_reset"
  printf '%s%s%s\n' "$summary_warning" '  Total estimated space: unavailable.' "$summary_reset"
else
  if [[ "$mode" == dry-run ]]; then
    printf '%s  Docker Buildx cache: %s candidate records; estimated %s GB.%s\n' "$summary_success" "$cache_count" "$cache_estimate" "$summary_reset"
  else
    printf '%s  Docker Buildx cache: prune completed; prior estimate %s candidate records, %s GB.%s\n' "$summary_success" "$cache_count" "$cache_estimate" "$summary_reset"
  fi
  printf '%s  Total estimated space: %s GB (Docker cache only; not actual reclaimed space).%s\n' "$summary_warning" "$cache_estimate" "$summary_reset"
  echo '  Shared cache and Docker prune eligibility may make actual recovery differ.'
fi
if [[ "$mode" == apply ]]; then printf '  Docker Buildx reported reclaimed: %s.\n' "$docker_reclaimed"; fi
fi
if $select_git; then
if [[ "$mode" == dry-run ]]; then
  printf '%s  Git maintenance: planned for %s repositories; space savings unknown.%s\n' "$summary_success" "$repo_count" "$summary_reset"
else
  if (( maintenance_failed > 0 )); then
    printf '%s  Git maintenance: %s succeeded, %s failed; space savings unknown.%s\n' "$summary_error" "$maintenance_ok" "$maintenance_failed" "$summary_reset"
  else
    printf '%s  Git maintenance: %s succeeded, %s failed; space savings unknown.%s\n' "$summary_success" "$maintenance_ok" "$maintenance_failed" "$summary_reset"
  fi
fi
if [[ "$mode" == apply ]] && $git_measurement_complete; then
  printf '  Git .git size change: %s bytes (before minus after; approximate, may be negative).\n' "$((git_total_bytes - git_after_bytes))"
fi
fi
if $select_worktrees; then
  if [[ "$mode" == apply ]]; then
    printf '  Worktree metadata prune: %s repositories succeeded, %s failed.\n' "$worktree_ok" "$worktree_failed"
  else
    printf '  Worktree metadata: %s repositories with candidates; preview only.\n' "$stale_count"
  fi
elif $select_git; then
  printf '%s  Not removed: Docker images (listed with --verbose) and %s sets of stale worktree metadata.%s\n' "$summary_muted" "$stale_count" "$summary_reset"
fi
cat <<'NOTICE'

Not touched: Docker images/containers/volumes, branches, worktree directories,
project/build directories, package caches, browser/app caches, logs, or personal data.
NOTICE

if [[ "$mode" == dry-run ]]; then
  echo 'Dry-run only; nothing was removed. Use --apply after reviewing this report.'
else
  echo 'Cleanup complete.'
fi
if ${select_git} && [[ "$mode" == apply ]] && (( maintenance_failed > 0 )); then exit 1; fi
if ${select_worktrees} && [[ "$mode" == apply ]] && (( worktree_failed > 0 )); then exit 1; fi
