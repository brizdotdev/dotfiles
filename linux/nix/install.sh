#!/bin/bash

# Ensure submodules are initialized
pushd $HOME/.dotfiles
git submodule update --init --recursive
popd

# Ensure nix is installed
if ! command -v nix &> /dev/null; then
  echo -e "\033[31m ⚠️ Nix is not installed \033[0m"
  exit 1
fi

# Ensure home-manager is installed
if ! command -v home-manager &> /dev/null; then
  echo -e "\033[31m ⚠️ Home-manager is not installed \033[0m"
  exit 1
fi

# Install home-manager config
HOME_MANAGER_TARGET="$HOME/.config/home-manager/home.nix"
HOME_MANAGER_SOURCE="$HOME/.dotfiles/linux/nix/home.nix"
echo -e "\033[32m Installing home-manager config \033[0m"
rm "$HOME_MANAGER_TARGET"
echo -e "\033[32m Replacing {{USERNAME}} with $USER \033[0m"
sed -i "s+{{USERNAME}}+$USER+g" "$HOME_MANAGER_SOURCE"
echo -e "\033[32m Replacing {{HOME_PATH}} with $HOME \033[0m"
sed -i "s+{{HOME_PATH}}+$HOME+g" "$HOME_MANAGER_SOURCE"
ln -s "$HOME_MANAGER_SOURCE" "$HOME_MANAGER_TARGET"
home-manager switch -b bak

source ~/.bashrc