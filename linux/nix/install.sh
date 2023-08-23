#!/bin/bash

install_dependencies() {
  if command -v curl &> /dev/null && command -v xz &> /dev/null
  then
    return
  fi

  if ! command -v sudo &> /dev/null
  then
      echo -e "\033[31m sudo is not installed \033[0m"
      exit 1
  fi

  if command -v apt-get &> /dev/null
  then
      sudo apt-get update && sudo apt-get install -y curl xz
      return
  fi

  if command -v yum &> /dev/null
  then
      sudo yum update && sudo yum install -y curl xz
      return
  fi

  if command -v pacman &> /dev/null
  then
      sudo pacman -Sy curl xz
      return
  fi

  if command -v apk &> /dev/null
  then
    sudo apk update && sudo apk add curl xz
    return
  fi
}

install_dependencies

NIX_SH="$HOME/.nix-profile/etc/profile.d/nix.sh"

# Ensure submodules are initialized
pushd $HOME/.dotfiles
git submodule update --init --recursive
popd

# Install nix
if [ ! -e "$NIX_SH" ]; then
  echo -e "\033[32m Installing nix \033[0m"
  sh <(curl -L https://nixos.org/nix/install) --no-daemon
fi

chmod +x "$NIX_SH"
. "$NIX_SH"

# Install home-manager
if ! command -v home-manager &> /dev/null; then
  echo -e "\033[32m Installing home-manager \033[0m"
  nix-channel --add https://github.com/nix-community/home-manager/archive/release-23.05.tar.gz home-manager
  nix-channel --update
  nix-shell '<home-manager>' -A install
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