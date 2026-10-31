#!/usr/bin/env python3
"""Update clean Git worktrees using only their configured upstream."""
import argparse
import os
from pathlib import Path
import subprocess
import sys

SKIP = {'.git', 'node_modules', 'vendor', '.venv', '.cache', 'target'}


def git(repo, *args):
  return subprocess.run(['git', '-C', str(repo), *args], text=True,
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                        env={**os.environ, 'GIT_TERMINAL_PROMPT': '0'})


def repositories(root):
  def onerror(error):
    raise error
  for current, dirs, files in os.walk(root, followlinks=False, onerror=onerror):
    if '.git' in dirs or '.git' in files:
      yield Path(current)
    dirs[:] = sorted(d for d in dirs if d not in SKIP and not Path(current, d).is_symlink())


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--dry-run', action='store_true', help='Inspect local state without fetching or updating')
  parser.add_argument('directory', type=Path, help='Directory to search recursively')
  args = parser.parse_args()
  if not args.directory.is_dir():
    parser.error('directory does not exist or is not a directory')
  counts = {'updated': 0, 'skipped': 0, 'failed': 0}
  try:
    for repo in repositories(args.directory.resolve()):
      print(f'\n{repo}', flush=True)
      status = git(repo, 'status', '--porcelain=v1', '--untracked-files=normal', '--ignore-submodules=none')
      if status.returncode:
        print('  ERROR: cannot inspect working tree:', status.stderr.strip())
        counts['failed'] += 1
        continue
      branch = git(repo, 'symbolic-ref', '--quiet', '--short', 'HEAD')
      upstream = git(repo, 'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}')
      if status.stdout or branch.returncode or upstream.returncode:
        reason = 'local changes' if status.stdout else ('detached HEAD' if branch.returncode else 'no upstream')
        print(f'  SKIP: {reason}')
        counts['skipped'] += 1
        continue
      if args.dry_run:
        print(f'  WOULD UPDATE: {branch.stdout.strip()} from {upstream.stdout.strip()} (no fetch performed)')
        counts['skipped'] += 1
        continue
      result = git(repo, '-c', 'submodule.recurse=false', '-c', 'fetch.recurseSubmodules=false',
                   'pull', '--ff-only', '--no-recurse-submodules')
      if result.returncode:
        print('  ERROR:', (result.stderr or result.stdout).strip())
        counts['failed'] += 1
      else:
        print(' ', result.stdout.strip())
        counts['updated'] += 1
  except OSError as error:
    print(f'ERROR: directory traversal failed: {error}', file=sys.stderr)
    return 1
  print(f"\nSummary: {counts['updated']} updated, {counts['skipped']} skipped/previewed, {counts['failed']} failed")
  return 1 if counts['failed'] else 0


if __name__ == '__main__':
  sys.exit(main())
