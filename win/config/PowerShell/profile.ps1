################################################################################
# Utility Functions
################################################################################
function Show-History {
    Get-Content (Get-PSReadlineOption).HistorySavePath
}

function which($command) {
    Get-Command -Name $command -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

# Change the screen resolution to 1920x1080
# Useful for when I need to screenshare because my main monitor is 3440x1440
function fullhd {
    Import-Module ChangeScreenResolution
    Set-ScreenResolution -Width 1920 -Height 1080
    Remove-Module ChangeScreenResolution
}

# Restore rewsolution to 3440x1440
function ultrawide {
    Import-Module ChangeScreenResolution
    Set-ScreenResolution -Width 3440 -Height 1440
    Remove-Module ChangeScreenResolution
}
Set-Alias -Name "uw" -Value ultrawide -Option AllScope

function Copy-Pwd {
    $(pwd).Path | clip.exe
}

function AWSLogin {
    param (
        [string]  $AWSProfile
    )
    process {
        if (-Not [string]::IsNullOrEmpty($AWSProfile)) {
            $env:AWS_PROFILE = $AWSProfile
        }
        else {
            $env:AWS_PROFILE = 'default'
        }
        echo "Profile: $env:AWS_Profile"
        $creds = aws-runas
        if (-Not $?) {
            echo "Failed to login"
        }
        $CredentialFileLocation = $env:USERPROFILE + "\.aws\credentials"
        $accesskey = ""
        $secret = ""
        $profile = ""
        $sessionToken = ""
        ForEach ($line in $($creds -split "`r`n")) {
            if ($line -match 'AWS_ACCESS_KEY_ID') {
                $accesskey = $line -replace "^(.*?)="
            }
            if ($line -match 'AWS_SECRET_ACCESS_KEY') {
                $secret = $line -replace "^(.*?)="
            }
            if ($line -match 'AWSRUNAS_PROFILE') {
                $profile = $line -replace "^(.*?)="
            }
            if ($line -match 'AWS_SESSION_TOKEN') {
                $sessionToken = $line -replace "^(.*?)="
            }
        }
        Import-Module AWS.Tools.Common
        $env:AWS_PROFILE = 'default'
        Set-AWSCredential -AccessKey $accesskey -SecretKey $secret -SessionToken $sessionToken -StoreAs $ENV:AWS_PROFILE -ProfileLocation $CredentialFileLocation
        if ($?) {
            Write-Host  "Credentials successfully set"-ForegroundColor Green
        }
        else {
            Write-Host "Error setting credentials"-ForegroundColor Red
        }
        Remove-Module AWS.Tools.Common
    }
}

function ConnectPVPN {
    PVPN.exe
    if ($? -ne $true) {
        Write-Host "Failed to connect to Get VPN Cookie"
    }
    $cookieFile = Join-Path -Path (Split-Path (Get-Command PVPN.exe).Source) -ChildPath "cookie.txt"
    $cookie = Get-Content $cookieFile
    Remove-Item $cookieFile
    openconnect -q --servercert pin-sha256:1xhU6RCHvqQ94oP8/h1YBK8RjiSqy0QNbqzUQbz6l94= --cookie="$cookie" --script="C:\Program Files\OpenConnect\pearson-vpn-exclude-iit.js" $env:PVPN_VPNURL
}
Set-Alias -Name "pvpn" -Value ConnectPVPN

function ConnectPVPNFT {
    PVPN.exe
    if ($? -ne $true) {
        Write-Host "Failed to connect to Get VPN Cookie"
    }
    $cookieFile = Join-Path -Path (Split-Path (Get-Command PVPN.exe).Source) -ChildPath "cookie.txt"
    $cookie = Get-Content $cookieFile
    Remove-Item $cookieFile
    openconnect -q --servercert pin-sha256:1xhU6RCHvqQ94oP8/h1YBK8RjiSqy0QNbqzUQbz6l94= --cookie="$cookie" $env:PVPN_VPNURL
}
Set-Alias -Name "pvpn-full" -Value ConnectPVPNFT

function tmux([string]$a) {
    wsl -- tmux -f /home/brizzz/.tmux-pwsh.conf $a
}

################################################################################
# Aliases
################################################################################
Set-Alias -Name "clear" -Value Clear-Host -Option AllScope
Set-Alias -Name "c" -Value Clear-Host -Option AllScope
Set-Alias -Name "history" -Value Show-History -Option AllScope
Set-Alias -Name "vi" -Value nvim
Set-Alias -Name "vim" -Value nvim
Set-Alias -Name "g" -Value git
Set-Alias -Name "got" -Value git
Set-Alias -Name "gut" -Value git
Set-Alias -Name "gat" -Value git
Set-Alias -Name "ex" -Value explorer
Set-Alias -Name "expl" -Value explorer
Set-Alias -Name "lg" -Value lazygit

del alias:sl -Force
del alias:rm -Force
del alias:ls -Force
del alias:sort -Force

################################################################################
# Imports
################################################################################
Import-Module posh-git
Import-Module DockerCompletion

################################################################################
# Startup
################################################################################
if ($env:TERM_PROGRAM -eq "vscode") {
    Set-PSReadLineOption -EditMode Emacs
}
