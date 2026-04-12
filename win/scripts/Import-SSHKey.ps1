#Requires -RunAsAdministrator
Write-Host -ForegroundColor Blue "Importing SSH Key from Yubikey"

$sshDir = "$env:USERPROFILE\.ssh"

winget install --silent --no-upgrade Microsoft.OpenSSH.Preview
winget install --silent --no-upgrade Yubico.YubiKeyManagerCLI
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

if (-not (Test-Path -Path $sshDir)) {
  New-Item -ItemType Directory -Path $sshDir
}

while ($true) {
    ykman.exe info >$null 2>&1
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host -ForegroundColor Yellow "Please insert your Yubikey and press any key to continue"
    Read-Host
}
Write-Host -ForegroundColor Green "Yubikey detected"

Push-Location $sshDir
for ($attempt = 1; $attempt -le 5; $attempt++) {
    ssh-keygen.exe -K
    if ($LASTEXITCODE -eq 0) { break }
    if ($attempt -eq 5) {
        Write-Host -ForegroundColor Red "Failed to import SSH key from Yubikey"
        exit 1
    }
    Write-Host -ForegroundColor Yellow "Failed to import key. Try again"
}


Pop-Location

$privateKeys = Get-ChildItem -Path $sshDir -File |
    Where-Object { -not $_.Name.EndsWith('.pub') }

foreach ($privateKey in $privateKeys) {
    ssh-add.exe $privateKey.FullName
    if ($LASTEXITCODE -ne 0) {
        Write-Host -ForegroundColor Red "Failed to add SSH key to agent: $($privateKey.Name)"
        exit 1
    }
}

Write-Host -ForegroundColor Green "SSH Key imported from Yubikey"
exit 0