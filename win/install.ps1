#Requires -RunAsAdministrator
################################################################################
# Setup script for my dotfiles
################################################################################

# Helper functions
$HelperPath = Join-Path -Path $PSScriptRoot -ChildPath "scripts" -ChildPath "helpers"
foreach ($DotfilesHelper in $HelperPath) {
  . $DotfilesHelper;
};

$InstallDevTools = YesNoPrompt "Install apps and tools for development?"
$InstallWebDev = YesNoPrompt "Install apps and tools for web development?"
$InstallWSL = YesNoPrompt "Install WSL?"
$InstallExtras = YesNoPrompt "Install extras?"

# Set dotfiles env var to the path of the dotfiles repo
$ParentPath = (Get-Item -Path $PSScriptRoot).Parent
[Environment]::SetEnvironmentVariable("DOTFILES", $ParentPath, "User")
$env:DOTFILES = $ParentPath

# Install Chocolatey
& "$PSScriptRoot\scripts\Install-Chocolatey.ps1"
if ($? -eq $False) {
    exit 1
}

# Install Base
& "$PSScriptRoot\scripts\Install-Base.ps1"
if ($? -eq $False) {
    exit 1
}

# Configure Windows
& "$PSScriptRoot\scripts\Configure-Windows.ps1"
if ($? -eq $False) {
    exit 1
}

# Install Dev
if ($InstallDevTools -eq $True) {
    & "$PSScriptRoot\scripts\Install-Dev.ps1"
    if ($? -eq $False) {
        exit 1
    }
}

# Install web dev
if ($InstallWebDev -eq $True) {
    & "$PSScriptRoot\scripts\Install-Web-Dev.ps1"
    if ($? -eq $False) {
        exit 1
    }
}

# Install Extras
if ($InstallExtras -eq $True) {
    & "$PSScriptRoot\scripts\Install-Extras.ps1"
    if ($? -eq $False) {
        exit 1
    }
}

# TODO: Install WSL
# if ($InstallWSL -eq $True) {
#     & "$PSScriptRoot\scripts\Install-WSL.ps1"
#     if ($? -eq $False) {
#         exit 1
#     }
# }

# Generate SSH key
Write-Host -ForegroundColor Blue "Generating SSH Key"
ssh-keygen -t ed25519
Write-Host -ForegroundColor Green "SSH Key generated"