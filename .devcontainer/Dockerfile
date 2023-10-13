FROM mcr.microsoft.com/devcontainers/base:bookworm

# Install PowerShell
RUN curl -L https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -o /tmp/packages-microsoft-prod.deb \
    && dpkg -i /tmp/packages-microsoft-prod.deb

RUN apt update && apt update && apt install -y powershell