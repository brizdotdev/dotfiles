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
    wsl --install -d $distribution
    if ($? -eq $False) {
        Write-Host -ForegroundColor Red  "Failed to setup WSL2"
        exit 1
    }
    Write-Host -ForegroundColor Yellow "WSL2 setup complete. You will need to reboot your machine to complete the WSL2 installation."
    exit 0;
}
Write-Host -ForegroundColor Green "WSL2 is installed"
Write-Host ""

## Copy WSL conf
Write-Host -ForegroundColor Blue "Copying WSL conf"
$wslConfPath = [IO.Path]::Combine("\\wsl$" , $distribution, "etc", "wsl.conf")
Copy-Item -Recurse "$PSScriptRoot\..\linux\wsl\wsl.conf" -Destination $wslConfPath -ErrorAction SilentlyContinue
wsl --shutdown
Write-Host -ForegroundColor Green "WSL conf copied"