################################################################################
# Backup PATH environment variable to a file
################################################################################

function Backup-Path {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [Parameter(Mandatory=$true)]
        [string]$FileName
    )
    if (Test-Path $FileName) {
        Remove-Item $FileName
    }
    $Path | Out-File -FilePath $FileName
}

$backupDir = Join-Path -Path $env:DOTFILES -ChildPath "env"
mkdir -p $backupDir
pushd $backupDir
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
Backup-Path -Path $userPath -FileName "user-path.txt"
$machinePath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
Backup-Path -Path $machinePath -FileName "machine-path.txt"
popd