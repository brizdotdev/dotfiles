#Requires -RunAsAdministrator
Write-Host -ForegroundColor Blue "Importing SSH Key from Yubikey"

$sshDir = "$env:USERPROFILE\.ssh"

winget install --silent GnuPG.Gpg4win
winget install --silent Microsoft.OpenSSH.Beta
winget install --silent Yubico.YubikeyManager
$ykPath = "C:\Program Files\Yubico\YubiKey Manager"
[Environment]::SetEnvironmentVariable("PATH", "$env:Path;$ykPath", "User")
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

if (-not (Test-Path -Path $sshDir)) {
  New-Item -ItemType Directory -Path $sshDir
}

ykman.exe info >$null 2>&1
$ykmanExitCode = $LASTEXITCODE
while ($ykmanExitCode -ne 0) {
    Write-Host -ForegroundColor Yellow "Please insert your Yubikey and press any key to continue"
    Read-Host
    ykman.exe info >$null 2>&1
    $ykmanExitCode = $LASTEXITCODE
}
Write-Host -ForegroundColor Green "Yubikey detected"

pushd $sshDir
ssh-keygen.exe -K
$sshKeygenExitCode = $LASTEXITCODE
$sshKeygenRetryCount = 0
while ($sshKeygenExitCode -ne 0) {
    Write-Host -ForegroundColor Yellow "Failed to import key. Try again"
    ssh-keygen.exe -K
    $sshKeygenExitCode = $LASTEXITCODE
    $sshKeygenRetryCount++
    if ($sshKeygenRetryCount -gt 3) {
        Write-Host -ForegroundColor Red "Failed to import SSH key from Yubikey"
        exit 1
    }
}
popd

Write-Host -ForegroundColor Green "SSH Key imported from Yubikey"
exit 0