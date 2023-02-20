#Requires -RunAsAdministrator
################################################################################
# Install WSL
## This has to be the last step because it will reboot the machine
################################################################################

$distribution="Debian"

## Check if WSL is installed
Write-Host -ForegroundColor Blue "Checking if WSL is installed"
wsl -l | Out-Null
if ($? -eq $False) {
    ### WSL not installed. Install and reboot
    Write-Host -ForegroundColor Yellow "Setting up WSL2."
    Write-Host -ForegroundColor Yellow "This will restart your machine once done"
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

## Copy WSL conf
Write-Host -ForegroundColor Blue "Copying WSL conf"
$wslConfPath = [IO.Path]::Combine("\\wsl$" , $distribution, "etc", "wsl.conf")
Copy-Item -Recurse "$PSScriptRoot\..\linux\wsl\wsl.conf" -Destination $wslConfPath -ErrorAction SilentlyContinue
wsl --shutdown
Write-Host -ForegroundColor Green "WSL conf copied"

# TODO:
# ## Copy bash scripts into WSL tmp folder
# ## Because files in Windows are owned by root in WSL
# Write-Host -ForegroundColor Blue "Copying scripts to WSL /tmp"
# $scriptsFolder = Join-Path -Path $($PSScriptRoot) -ChildPath "scripts"
# $wslTempPath = [IO.Path]::Combine("\\wsl$" , $distribution, "tmp")
# Copy-Item -Recurse $scriptsFolder\*.sh -Destination $wslTempPath -ErrorAction SilentlyContinue
# wsl --cd "$scriptsFolder" -- sudo apt install -y dos2unix '&&' sudo chown '$USER' /tmp/*.sh '&&' dos2unix --allow-chown /tmp/*.sh '&&' chmod +x /tmp/*.sh
# Write-Host -ForegroundColor Green "Scripts copied"
# Write-Host ""

# TODO: Setup WSL