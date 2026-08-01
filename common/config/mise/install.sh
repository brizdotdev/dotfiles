#!/usr/bin/env bash
set -euo pipefail

if ! command -v mise &>/dev/null; then
  echo "mise not found, installing..."
  curl https://mise.run | sh
fi

echo "Linking mise config..."
mkdir -p ~/.config/mise
ln -sf ~/.dotfiles/common/config/mise/mise.toml ~/.config/mise/config.toml

echo "Bootstrapping mise..."
cd ~
mise bootstrap
