#!/bin/bash
# Install Python3
sudo apt update && sudo apt install -y python3 python3-pip

# Install Ansible and pywinrm
pip3 install --user ansible && pip3 install --user pywinrm

# Add python bin to PATH
echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc
source ~/.bashrc