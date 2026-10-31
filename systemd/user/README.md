# Monthly cleanup timer

`dotfiles-monthly-cleanup.timer` is intentionally not enabled by the dotfiles
installer. First review a manual report:

```sh
bash ~/Dev/dotfiles/scripts/cleanup-system.sh --dry-run
```

The script defaults to dry-run. Its apply mode only prunes Docker Buildx cache
created more than 30 days ago and runs `git maintenance run --auto` in local
repositories. It reports old Docker images and stale worktree metadata without
removing them. It never deletes volumes, containers, branches, project files,
application caches, logs, or personal data.

The default output is concise, with progress shown on a terminal. Add
`--verbose` to either mode to see cache records, old Docker images and detailed
Git repository reports. The summary uses color only on a terminal and respects
`NO_COLOR`.

Use `--docker` or `--git` to select just that category (they may be combined).
With no category option, both remain selected. `--worktrees` is a separate,
explicit category: first preview with `--worktrees --dry-run`, then use
`--worktrees --apply` to prune eligible stale metadata older than 30 days. It
does not remove worktree directories. Docker's reported reclaimed space and the
approximate change in Git data size are shown after apply when available; Git
size changes can reflect concurrent work or background maintenance.

After reviewing the output, you can choose **Monthly cleanup timer** in the
machine setup checklist or pass `--cleanup-timer` to
`scripts/setup-machine.sh --apply`. This remains opt-in; setup previews the
cleanup report and checks for unit conflicts before asking for confirmation.
Alternatively, install and enable the timer manually:

```sh
mkdir -p ~/.config/systemd/user
ln -s ~/Dev/dotfiles/systemd/user/dotfiles-monthly-cleanup.service ~/.config/systemd/user/
ln -s ~/Dev/dotfiles/systemd/user/dotfiles-monthly-cleanup.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now dotfiles-monthly-cleanup.timer
```

Check status with `systemctl --user list-timers dotfiles-monthly-cleanup.timer`
and logs with `journalctl --user -u dotfiles-monthly-cleanup.service`. The timer
uses `Persistent=true`, so a missed monthly run is caught up when the user
systemd manager starts.
