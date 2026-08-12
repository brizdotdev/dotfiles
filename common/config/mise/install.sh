#!/usr/bin/env bash
set -euo pipefail

config_file="${1:-mise.devcontainer.toml}"

# Where mise looks for its global config, in order of precedence.
# https://mise.jdx.dev/configuration.html
if [ -n "${MISE_GLOBAL_CONFIG_FILE:-}" ]; then
  target="$MISE_GLOBAL_CONFIG_FILE"
elif [ -n "${MISE_CONFIG_DIR:-}" ]; then
  target="$MISE_CONFIG_DIR/config.toml"
else
  target="$HOME/.config/mise/config.toml"
fi

if ! command -v mise &>/dev/null; then
  echo "mise not found, installing..."
  curl https://mise.run | sh
fi

echo "Linking mise config ($config_file -> $target)..."
mkdir -p "$(dirname "$target")"
ln -sf "$HOME/.dotfiles/common/config/mise/$config_file" "$target"

echo "Bootstrapping mise..."
cd ~
mise bootstrap
