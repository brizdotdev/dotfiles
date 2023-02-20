FROM mcr.microsoft.com/devcontainers/base:bullseye

RUN apt update && apt install -y vim git curl tmux jq sudo

# Install PowerShell
RUN apt update && apt install -y curl gnupg apt-transport-https \
    && curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-debian-bullseye-prod bullseye main" > /etc/apt/sources.list.d/microsoft.list' \
    && apt update && apt install -y powershell

# Install NeoVim
COPY linux/scripts/install-neovim.sh /tmp/install-neovim.sh
RUN chmod +x /tmp/install-neovim.sh && /tmp/install-neovim.sh

# Install Ansible
COPY linux/scripts/install-ansible.sh /tmp/install-ansible.sh
RUN chmod +x /tmp/install-ansible.sh && /tmp/install-ansible.sh