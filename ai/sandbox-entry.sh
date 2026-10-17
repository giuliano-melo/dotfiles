#!/bin/sh
# Runs only inside ai-jail. glab 1.53 opens its config for writing even for
# read-only API calls. Give it a disposable copy, not RW access to host tokens.
set -eu
if [ -d /tmp/.ai-stack-glab-source ]; then
  mkdir -p "${HOME}/.config/glab-cli"
  cp -R /tmp/.ai-stack-glab-source/. "${HOME}/.config/glab-cli/"
fi
export GLAB_CHECK_UPDATE=false
exec "$@"
