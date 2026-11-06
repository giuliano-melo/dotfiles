#!/usr/bin/env bash
# Install or update gitleaks to ~/.local/bin.
set -euo pipefail

version="${1:-8.21.2}"
install_dir="$HOME/.local/bin"
bin="$install_dir/gitleaks"

mkdir -p "$install_dir"

os="linux"
arch="x64"
if [[ "$OSTYPE" == darwin* ]]; then
  os="darwin"
  arch="arm64"
  if [[ "$(uname -m)" == x86_64 ]]; then
    arch="x64"
  fi
fi

url="https://github.com/gitleaks/gitleaks/releases/download/v${version}/gitleaks_${version}_${os}_${arch}.tar.gz"
tmpdir="$(mktemp -d /tmp/opencode/gitleaks-install.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

echo "Downloading gitleaks ${version} for ${os}/${arch}..."
curl -fsSL "$url" -o "$tmpdir/gitleaks.tar.gz"
tar -xzf "$tmpdir/gitleaks.tar.gz" -C "$tmpdir" gitleaks
mv "$tmpdir/gitleaks" "$bin"
chmod +x "$bin"

echo "Installed gitleaks ${version} at ${bin}"
echo "Ensure ${install_dir} is on your PATH."
"$bin" version
