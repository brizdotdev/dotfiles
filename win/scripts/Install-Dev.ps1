#Requires -RunAsAdministrator
################################################################################
# Install apps and tools for development
################################################################################
Write-Host -ForegroundColor Blue "Installing apps and tools for development"
$LocalWindowsApps = "$env:LocalAppData\Microsoft\WindowsApps"
# CLI tools
winget install --silent stedolan.jq
winget install --silent MikeFarah.yq
winget install --silent JFLarvoire.Ag
winget install --silent glab
choco install -y ripgrep fzf bat lazygit fd lf glow dust duf xsv sd-cli
# Install fx
pushd $LocalWindowsApps
curl.exe -L -o fx.exe https://github.com/antonmedv/fx/releases/latest/download/fx_windows_amd64.exe
popd

# Configure Lazygit
$LazyGitConfigPath = "$env:AppData\lazygit"
mkdir.exe -p $LazyGitConfigPath
$LazyGitConfigFile = Join-Path -Path $LazyGitConfigPath -ChildPath "config.yml"
if (!(Test-Path -Path $LazyGitConfigFile)) {
    New-Item -ItemType SymbolicLink -Path "$LazyGitConfigFile" -Target "$env:DOTFILES\common\config\lazygit\config.yml"
}

# Useful GUI tools
winget install --silent WinMerge.WinMerge
winget install --silent WinSCP.WinSCP
winget install --silent Insomnia.Insomnia

# dotnet
winget install --silent Microsoft.DotNet.SDK.3_1
winget install --silent Microsoft.DotNet.SDK.5
winget install --silent Microsoft.DotNet.SDK.6
winget install --silent Microsoft.DotNet.SDK.7
winget install --silent Microsoft.DotNet.SDK.Preview
choco install -y dotpeek

# DB
winget install --silent TablePlus.TablePlus
winget install --silent Microsoft.SQLServerManagementStudio

# Langs
winget install --silent OpenJS.NodeJS
Remove-Item -Path "$LocalWindowsApps\python.exe" -Force
Remove-Item -Path "$LocalWindowsApps\python3.exe" -Force
winget install --silent Python.Python.3.12 --override '/passive PrependPath=1'

# Repos folder
$ReposFolder = "$env:USERPROFILE\Repos"
if (!(Test-Path -Path $ReposFolder)) {
    New-Item -ItemType Directory -Path $ReposFolder
}
$env:REPOS = $ReposFolder
[Environment]::SetEnvironmentVariable("REPOS", $ReposFolder, "User")

# Hosts file
$HostsFile = "C:\Windows\System32\drivers\etc\hosts"
$env:HOSTS = $HostsFile
[Environment]::SetEnvironmentVariable("HOSTS", $HostsFile, "Machine")

Write-Host -ForegroundColor Green "Apps and tools for development installed"
exit 0