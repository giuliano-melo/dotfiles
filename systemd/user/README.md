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
