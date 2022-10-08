#Requires -RunAsAdministrator

# Setup script for my dotfiles
## Setup  WSL2
### Check if WSL is installed
wsl -l
if ($? -eq $False) {
    ### WSL not installed. Install and reboot
    Write-Host -ForegroundColor Yellow "Setting up WSL2. This will restart your machine"
    # Install Debian instead of Ubuntu because Ubuntu will install 20.04 whereas Debian will install 11 which is newer
    wsl --install Debian 
    if ($? -eq $False) {
        Write-Host -ForegroundColor Red  "Failed to setup WSL2"
        exit 1
    }
    shutdown /g /t 30 /d p:4:1 /c "WSL2 setup complete. Restarting in 30 seconds" 
    exit 0
}
Write-Host -ForegroundColor Green "WSL2 is installed"

## Install ansible in WSL
$scriptsFolder = Join-Path -Path $($PSScriptRoot) -ChildPath "scripts"
wsl --cd "$scriptsFolder" -e ./install-ansible.sh
if ($? -eq $False) {
    Write-Host -ForegroundColor Red  "Failed to install ansible"
    exit 1
}

## Enable WinRM
## https://docs.ansible.com/ansible/2.5/user_guide/windows_setup.html#winrm-setup
$configAnsibleScriptPath = Join-Path -Path $env:Temp -ChildPath "ansible.ps1"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1" -OutFile $configAnsibleScriptPath
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
& $configAnsibleScriptPath
if ($? -eq $False) {
    Write-Host -ForegroundColor Red  "Failed to enable WinRM"
    exit 1
}

## Get Windows IP address from WSL
$windowsIP = wsl --cd "$scriptsFolder" -e ./get-win-ip.sh
if ($? -eq $False) {
    Write-Host -ForegroundColor Red  "Failed to get Windows IP address"
    exit 1
}
Write-Host -ForegroundColor Green "Windows IP address is $windowsIP"
Write-Host -ForegroundColor Green "Edit the ansible/hosts file then run your playbooks"
Write-Host ""

# Reminder to remove listeners
Write-Host -ForegroundColor Yellow "Don't forget to remove WinRM listeners when you're done"
