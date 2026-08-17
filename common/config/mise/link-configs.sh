#!/usr/bin/env bash
# Linked from [bootstrap.hooks.post-dotfiles] in mise.devcontainer.toml.
#
# mise's [dotfiles] targets must be literal paths — it expands neither env vars
# nor templates there — so anything rooted at XDG_CONFIG_HOME or
# CLAUDE_CONFIG_DIR is linked here instead.
set -euo pipefail

dotfiles="$HOME/.dotfiles/common/config"

# Whole directories under $XDG_CONFIG_HOME — add names under common/config/
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$config_home"
for name in yazi lazygit herdr tuicr; do
  echo "Linking $dotfiles/$name -> $config_home/$name"
  rm -rf "$config_home/$name"
  ln -sfn "$dotfiles/$name" "$config_home/$name"
done

# Individual files under $CLAUDE_CONFIG_DIR — the dir holds unmanaged state
# (projects/, todos/), so only the named files are replaced, never the dir.
claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
mkdir -p "$claude_dir"
for file in settings.json CLAUDE.md; do
  echo "Linking $dotfiles/claude/$file -> $claude_dir/$file"
  rm -f "$claude_dir/$file"
  ln -sfn "$dotfiles/claude/$file" "$claude_dir/$file"
done
