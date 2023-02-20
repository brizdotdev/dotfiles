#!/bin/bash
# Install neovim
## Check if fuse is installed, if not install it
if ! dpkg -s fuse3 > /dev/null 2>&1; then
    sudo apt install -y fuse3 libfuse-dev
fi
## Check if curl is installed, if not install it
if ! dpkg -s curl > /dev/null 2>&1; then
    sudo apt install -y curl
fi
## Get latest appImage from GitHub
curl -L https://github.com/neovim/neovim/releases/latest/download/nvim.appimage -o /tmp/nvim
chmod u+x /tmp/nvim
mkdir -p ~/.local/bin
mv /tmp/nvim ~/.local/bin/nvim
