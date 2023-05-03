#Requires -RunAsAdministrator
################################################################################
# Setup script for my dotfiles
################################################################################

# Helper functions
$HelperPath = Join-Path -Path $PSScriptRoot -ChildPath "scripts\helpers"
Get-ChildItem -Path $HelperPath -Filter "*.ps1" | ForEach-Object {
    . $_.FullName
}

$InstallChocolatey = YesNoPrompt "Install Chocolatey?"
$ConfigureWindows = YesNoPrompt "Configure Windows?"
$InstallBase = YesNoPrompt "Install base apps and fonts?"
$InstallFirefoxExtensions = $False
$InstallLibrewolfExtensions = $False
$InstallChromeExtensions = $False
if ($InstallBase -eq $True)
{
    $InstallFirefoxExtensions = YesNoPrompt "Install Firefox extensions?"
    $InstallLibrewolfExtensions = YesNoPrompt "Install Librewolf extensions?"
    $InstallChromeExtensions = YesNoPrompt "Install Chrome extensions?"
}
$InstallDevTools = YesNoPrompt "Install apps and tools for development?"
$InstallWebDev = YesNoPrompt "Install apps and tools for web development?"
$InstallExtras = YesNoPrompt "Install extras?"
$RemoveBloatware = YesNoPrompt "Remove bloatware?"
do {
    $browserChoice = Read-Host -Prompt "Which browser do you want to set as default? (firefox, chrome, none): "
}
while ($browserChoice -ne "firefox" -and $browserChoice -ne "chrome" -and $browserChoice -ne "none")
$GitUserName = Read-Host -Prompt "Enter your Git user name: "
$GitUserEmail = Read-Host -Prompt "Enter your Git user email: "
$GitConfigureSigning = YesNoPrompt "Configure Commit Signing?"
$ImportSSHKey = YesNoPrompt "Import SSH Key from Yubikey?"

Write-Host ""

# Set dotfiles env var to the path of the dotfiles repo
$ParentPath = ((Get-Item -Path $PSScriptRoot).Parent).FullName
[Environment]::SetEnvironmentVariable("DOTFILES", $ParentPath, "User")
$env:DOTFILES = [Environment]::GetEnvironmentVariable("DOTFILES", "User")

# Install Chocolatey
if ($InstallChocolatey -eq $True) {
    & "$PSScriptRoot\scripts\Install-Chocolatey.ps1"
    if ($? -eq $False) {
        Write-Host -ForegroundColor Red "Chocolatey installation failed"
        Read-Host
        exit 1
    }
    Write-Host ""
}

# Configure Windows
if ($ConfigureWindows -eq $True) {
    & "$PSScriptRoot\scripts\Configure-Windows.ps1"
    if ($? -eq $False) {
        Write-Host -ForegroundColor Red "Windows configuration failed"
        Read-Host
        exit 1
    }
    Write-Host ""
}

# Install Base
if ($InstallBase -eq $True) {
    & "$PSScriptRoot\scripts\Install-Base.ps1" $browserChoice $InstallFirefoxExtensions $InstallLibrewolfExtensions $InstallChromeExtensions $GitUserName $GitUserEmail $GitConfigureSigning
    if ($? -eq $False) {
        Write-Host -ForegroundColor Red "Base installation failed"
        Read-Host
        exit 1
    }
    Write-Host ""
}

# Install Dev
if ($InstallDevTools -eq $True) {
    & "$PSScriptRoot\scripts\Install-Dev.ps1"
    if ($? -eq $False) {
        Write-Host -ForegroundColor Red "Dev installation failed"
        Read-Host
        exit 1
    }
    Write-Host ""
}

# Install web dev
if ($InstallWebDev -eq $True) {
    & "$PSScriptRoot\scripts\Install-Web-Dev.ps1"
    if ($? -eq $False) {
        Write-Host -ForegroundColor Red "Web Dev installation failed"
        Read-Host
        exit 1
    }
    Write-Host ""
}

# Remove Bloatware
if ($RemoveBloatware -eq $True) {
    & "$PSScriptRoot\scripts\Remove-Bloatware.ps1"
    if ($? -eq $False) {
        Write-Host -ForegroundColor Red "Bloatware removal failed"
        Read-Host
        exit 1
    }
    Write-Host ""
}


# Install Extras
if ($InstallExtras -eq $True) {
    & "$PSScriptRoot\scripts\Install-Extras.ps1"
    if ($? -eq $False) {
        Write-Host -ForegroundColor Red "Extras installation failed"
        Read-Host
        exit 1
    }
    Write-Host ""
}

# Import SSH Key
if ($ImportSSHKey -eq $True) {
    & "$PSScriptRoot\scripts\Import-SSHKey.ps1"
    if ($? -eq $False) {
        Write-Host -ForegroundColor Red "SSH Key import failed"
        Read-Host
        exit 1
    }
    Write-Host ""
}


& "$PSScriptRoot\scripts\Backup-Path.ps1"

Write-Host -ForegroundColor Green "Done!"
Read-Host
