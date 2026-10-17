#!/usr/bin/env bash
# Host invocation: bash scripts/test-ai-container.sh
# No host credentials, Docker socket, writable host mounts, or privileged mode.
set -euo pipefail

if [[ "${1:-}" != "--inside" ]]; then
  repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  exec docker run --rm --name "dotfiles-ai-test-$$" \
    --security-opt=no-new-privileges \
    --mount "type=bind,src=${repo},dst=/source,readonly" \
    ubuntu:24.04 bash /source/scripts/test-ai-container.sh --inside
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq python3 curl ca-certificates xz-utils git glab bubblewrap zsh ansible-core sudo
ansible-playbook -i localhost, -c local /source/ansible/site.yml

chezmoi_version="$(python3 -c 'import json; print(json.load(open("/source/ai/versions.json"))["chezmoi"])')"
chezmoi_sha256="$(python3 -c 'import json; print(json.load(open("/source/ai/versions.json"))["chezmoi_linux_amd64_sha256"])')"
chezmoi_archive="/tmp/chezmoi_${chezmoi_version}_linux_amd64.tar.gz"
curl --fail --silent --show-error --location --output "$chezmoi_archive" \
  "https://github.com/twpayne/chezmoi/releases/download/v${chezmoi_version}/chezmoi_${chezmoi_version}_linux_amd64.tar.gz"
printf '%s  %s\n' "$chezmoi_sha256" "$chezmoi_archive" | sha256sum --check --status
tar -xzf "$chezmoi_archive" -C /usr/local/bin chezmoi
chmod 755 /usr/local/bin/chezmoi
chezmoi --version

useradd --create-home --shell /bin/bash tester
repo=/home/tester/Dev/dotfiles
mkdir -p "${repo}"
cp -R /source/ai /source/ansible /source/chezmoi /source/scripts /source/setup.sh "${repo}/"
chown -R tester:tester /home/tester
runuser -u tester -- env HOME=/home/tester PATH="/home/tester/.local/bin:/home/tester/.kimi-code/bin:/usr/local/bin:/usr/bin:/bin" bash /source/scripts/test-ai-container-user.sh
