#Requires -RunAsAdministrator

# Setup script for my dotfiles
## Setup  WSL2
### Install Debian instead of Ubuntu because Ubuntu will install 20.04 whereas Debian will install 11 which is newer
$distribution="Debian"
### Check if WSL is installed
Write-Host -ForegroundColor Blue "Checking if WSL is installed"
wsl -l | Out-Null
if ($? -eq $False) {
    ### WSL not installed. Install and reboot
    Write-Host -ForegroundColor Yellow "Setting up WSL2."
    Write-Host -ForegroundColor Yellow "⚠️ This will restart your machine once done"
    wsl --install -d $distribution
    if ($? -eq $False) {
        Write-Host -ForegroundColor Red  "Failed to setup WSL2"
        exit 1
    }
    shutdown /g /t 30 /d p:4:1 /c "WSL2 setup complete. Restarting in 30 seconds"
    exit 0
}
Write-Host -ForegroundColor Green "WSL2 is installed"
Write-Host ""

## Copy bash scripts into WSL tmp folder
## Because files in Windows are owned by root in WSL
Write-Host -ForegroundColor Blue "Copying scripts to WSL /tmp"
$scriptsFolder = Join-Path -Path $($PSScriptRoot) -ChildPath "scripts"
$wslTempPath = [IO.Path]::Combine("\\wsl$" , $distribution, "tmp")
Copy-Item -Recurse $scriptsFolder\*.sh -Destination $wslTempPath -ErrorAction SilentlyContinue
## Copy install-neovim.sh to /tmp
Copy-Item -Recurse "$PSScriptRoot\..\linux\scripts\install-neovim.sh" -Destination $wslTempPath -ErrorAction SilentlyContinue
wsl --cd "$scriptsFolder" -- sudo apt install -y dos2unix '&&' sudo chown '$USER' /tmp/*.sh '&&' dos2unix --allow-chown /tmp/*.sh '&&' chmod +x /tmp/*.sh
Write-Host -ForegroundColor Green "Scripts copied"
Write-Host ""

## Install ansible in WSL
Write-Host -ForegroundColor Blue "Installing Ansible"
wsl -- /tmp/install-ansible.sh
if ($? -eq $False) {
    Write-Host -ForegroundColor Red  "Failed to install Ansible"
    exit 1
}
Write-Host -ForegroundColor Green "Ansible installed"
Write-Host ""

## TODO: Install neovim in WSL
Write-Host -ForegroundColor Blue "Installing Neovim"
wsl -- /tmp/install-neovim.sh
if ($? -eq $False) {
    Write-Host -ForegroundColor Red  "Failed to install Neovim"
    exit 1
}
Write-Host -ForegroundColor Green "Neovim installed"
Write-Host ""


## Enable WinRM
## https://docs.ansible.com/ansible/2.5/user_guide/windows_setup.html#winrm-setup
Write-Host -ForegroundColor Blue "Enabling WinRM"
$configAnsibleScriptPath = Join-Path -Path $env:Temp -ChildPath "ansible.ps1"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1" -OutFile $configAnsibleScriptPath
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
& $configAnsibleScriptPath
if ($? -eq $False) {
    Write-Host -ForegroundColor Red  "Failed to enable WinRM"
    exit 1
}
Write-Host -ForegroundColor Green "WinRM enabled"
Write-Host ""

## Get Windows IP address from WSL
Write-Host -ForegroundColor Blue "Getting Windows IP address"
$windowsIP = wsl -- /tmp/get-win-ip.sh
if ($? -eq $False) {
    Write-Host -ForegroundColor Red  "Failed to get Windows IP address"
    exit 1
}
Write-Host -ForegroundColor Green "Windows IP address is $windowsIP"
Write-Host -ForegroundColor Green "Edit the ansible/hosts file then run your playbooks"
Write-Host ""

# Reminder to remove listeners
Write-Host -ForegroundColor Yellow "Don't forget to remove WinRM listeners when you're done"

# Cleanup
Remove-Item $configAnsibleScriptPath -ErrorAction SilentlyContinue
Remove-Item $wslTempPath\*.sh -ErrorAction SilentlyContinue