#Requires -RunAsAdministrator
################################################################################
# Install Chocolatey
# https://chocolatey.org/install
################################################################################
Write-Host -ForegroundColor Blue "Installing Chocolatey"
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
if ($? -eq $False) {
    Write-Host -ForegroundColor Red  "Failed to install Chocolatey"
    exit 1
}
refreshenv
choco feature enable -n=useRememberedArgumentsForUpgrades
Write-Host -ForegroundColor Green "Chocolatey installed"
exit 0