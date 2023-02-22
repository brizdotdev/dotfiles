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

Write-Host ""

# Set dotfiles env var to the path of the dotfiles repo
$ParentPath = ((Get-Item -Path $PSScriptRoot).Parent).FullName
[Environment]::SetEnvironmentVariable("DOTFILES", $ParentPath, "User")
$env:DOTFILES = $ParentPath

# Install Chocolatey
if ($InstallChocolatey -eq $True) {
    & "$PSScriptRoot\scripts\Install-Chocolatey.ps1"
    if ($? -eq $False) {
        exit 1
    }
    Write-Host ""
}

# Configure Windows
if ($ConfigureWindows -eq $True) {
    & "$PSScriptRoot\scripts\Configure-Windows.ps1"
    if ($? -eq $False) {
        exit 1
    }
    Write-Host ""
}

# Install Base
if ($InstallBase -eq $True) {
    & "$PSScriptRoot\scripts\Install-Base.ps1" $browserChoice $GitUserName $GitUserEmail
    if ($? -eq $False) {
        exit 1
    }
    Write-Host ""
}

# Install Dev
if ($InstallDevTools -eq $True) {
    & "$PSScriptRoot\scripts\Install-Dev.ps1"
    if ($? -eq $False) {
        exit 1
    }
    Write-Host ""
}

# Install web dev
if ($InstallWebDev -eq $True) {
    & "$PSScriptRoot\scripts\Install-Web-Dev.ps1"
    if ($? -eq $False) {
        exit 1
    }
    Write-Host ""
}

# Remove Bloatware
if ($RemoveBloatware -eq $True) {
    & "$PSScriptRoot\scripts\Remove-Bloatware.ps1"
    if ($? -eq $False) {
        exit 1
    }
    Write-Host ""
}


# Install Extras
if ($InstallExtras -eq $True) {
    & "$PSScriptRoot\scripts\Install-Extras.ps1"
    if ($? -eq $False) {
        exit 1
    }
    Write-Host ""
}

# Generate SSH key
Write-Host -ForegroundColor Blue "Generating SSH Key"
ssh-keygen -t ed25519
Write-Host -ForegroundColor Green "SSH Key generated"