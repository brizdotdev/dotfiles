################################################################################
# Utility Functions
################################################################################
${function:~} = { Set-Location ~ }

function Show-History {
    Get-Content (Get-PSReadlineOption).HistorySavePath
}
Set-Alias -Name "history" -Value Show-History -Option AllScope

function Reload-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
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

# Restore resolution to 3440x1440
function ultrawide {
    Import-Module ChangeScreenResolution
    Set-ScreenResolution -Width 3440 -Height 1440
    Remove-Module ChangeScreenResolution
}
Set-Alias -Name "uw" -Value ultrawide -Option AllScope

function Copy-Pwd {
    $(pwd).Path | clip.exe
}

function tmux([string]$a) {
    wsl -- tmux -f /home/brizzz/.tmux-pwsh.conf $a
}

function fzf-vim()
{
    vim $(fzf)
}

## Exec profile.local.ps1 if it exists
$LocalProfile = Join-Path $PSScriptRoot -ChildPath "profile.local.ps1"
if (Test-Path $LocalProfile) {
    & $LocalProfile
}

################################################################################
# Aliases
################################################################################
# Correct PowerShell Aliases if tools are available (aliases win if set)
# WGet: Use `wget.exe` if available
if (Get-Command wget.exe -ErrorAction SilentlyContinue | Test-Path) {
    rm alias:wget -ErrorAction SilentlyContinue
}

# Directory Listing: Use `ls.exe` if available
if (Get-Command ls.exe -ErrorAction SilentlyContinue | Test-Path) {
    rm alias:ls -ErrorAction SilentlyContinue
    # Set `ls` to call `ls.exe` and always use --color
    ${function:ls} = { ls.exe --color @args }
    # List all files in long format
    ${function:l} = { ls -lF @args }
    # List all files in long format, including hidden files
    ${function:la} = { ls -laF @args }
} else {
    # List all files, including hidden files
    ${function:la} = { ls -Force @args }
}
${function:lsd} = { Get-ChildItem -Directory -Force @args }

# curl: Use `curl.exe` if available
if (Get-Command curl.exe -ErrorAction SilentlyContinue | Test-Path) {
    rm alias:curl -ErrorAction SilentlyContinue
    # Set `ls` to call `ls.exe` and always use --color
    ${function:curl} = { curl.exe @args }
    # Gzip-enabled `curl`
    ${function:gurl} = { curl --compressed @args }
} else {
    # Gzip-enabled `curl`
    ${function:gurl} = { curl -TransferEncoding GZip }
}
del alias:sl -Force
del alias:rm -Force
del alias:sort -Force
del alias:cat -Force
del alias:mv -Force

Set-Alias -Name "clear" -Value Clear-Host -Option AllScope
Set-Alias -Name "c" -Value Clear-Host -Option AllScope
Set-Alias -Name "v" -Value nvim
Set-Alias -Name "vi" -Value nvim
Set-Alias -Name "vim" -Value nvim
Set-Alias -Name "g" -Value git
Set-Alias -Name "got" -Value git
Set-Alias -Name "gut" -Value git
Set-Alias -Name "gat" -Value git
Set-Alias -Name "ex" -Value explorer
Set-Alias -Name "expl" -Value explorer
Set-Alias -Name "lg" -Value lazygit
Set-Alias -Name "t" -Value tmux
Set-Alias -Name "dck" -Value docker
Set-Alias -Name "dckr" -Value docker
Set-Alias -Name "dn" -Value dotnet
Set-Alias -Name "cat" -Value bat
Set-Alias -Name "mkdir" -Value mkdir.exe

################################################################################
# Imports
################################################################################
Import-Module posh-git
$GitPromptSettings.EnableFileStatus = $false
Import-Module DockerCompletion
Import-Module CompletionPredictor

################################################################################
# Env
################################################################################
$env:FZF_DEFAULT_OPTS = "--layout=reverse --multi --cycle"

################################################################################
# PSReadLine
################################################################################
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PsFzfOption -TabExpansion
Set-PSReadLineOption -EditMode Vi
$OnViModeChange = [scriptblock]{
    if ($args[0] -eq 'Command') {
        # Set the cursor to a blinking block.
        Write-Host -NoNewLine "`e[2 q"
    }
    else {
        # Set the cursor to a blinking line.
        Write-Host -NoNewLine "`e[5 q"
    }
}
Set-PSReadLineOption -ViModeIndicator Script -ViModeChangeHandler $OnViModeChange
Set-PSReadLineKeyHandler -Key Alt+Enter -Function AcceptNextSuggestionWord
Set-PSReadLineKeyHandler -Key F2 -Function SwitchPredictionView

################################################################################
# GitHub Copilot
################################################################################
function ghcs {
        # Debug support provided by common PowerShell function parameters, which is natively aliased as -d or -db
        # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_commonparameters?view=powershell-7.4#-debug
        param(
                [ValidateSet('gh', 'git', 'shell')]
                [Alias('t')]
                [String]$Target = 'shell',

                [Parameter(Position=0, ValueFromRemainingArguments)]
                [string]$Prompt
        )
        begin {
                # Create temporary file to store potential command user wants to execute when exiting
                $executeCommandFile = New-TemporaryFile

                # Store original value of GH_DEBUG environment variable
                $envGhDebug = $Env:GH_DEBUG
        }
        process {
                if ($PSBoundParameters['Debug']) {
                        $Env:GH_DEBUG = 'api'
                }

                gh copilot suggest -t $Target -s "$executeCommandFile" $Prompt
        }
        end {
                # Execute command contained within temporary file if it is not empty
                if ($executeCommandFile.Length -gt 0) {
                        # Extract command to execute from temporary file
                        $executeCommand = (Get-Content -Path $executeCommandFile -Raw).Trim()

                        # Insert command into PowerShell up/down arrow key history
                        [Microsoft.PowerShell.PSConsoleReadLine]::AddToHistory($executeCommand)

                        # Insert command into PowerShell history
                        $now = Get-Date
                        $executeCommandHistoryItem = [PSCustomObject]@{
                                CommandLine = $executeCommand
                                ExecutionStatus = [Management.Automation.Runspaces.PipelineState]::NotStarted
                                StartExecutionTime = $now
                                EndExecutionTime = $now.AddSeconds(1)
                        }
                        Add-History -InputObject $executeCommandHistoryItem

                        # Execute command
                        Write-Host "`n"
                        Invoke-Expression $executeCommand
                }
        }
        clean {
                # Clean up temporary file used to store potential command user wants to execute when exiting
                Remove-Item -Path $executeCommandFile

                # Restore GH_DEBUG environment variable to its original value
                $Env:GH_DEBUG = $envGhDebug
        }
}

function ghce {
        # Debug support provided by common PowerShell function parameters, which is natively aliased as -d or -db
        # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_commonparameters?view=powershell-7.4#-debug
        param(
                [Parameter(Position=0, ValueFromRemainingArguments)]
                [string[]]$Prompt
        )
        begin {
                # Store original value of GH_DEBUG environment variable
                $envGhDebug = $Env:GH_DEBUG
        }
        process {
                if ($PSBoundParameters['Debug']) {
                        $Env:GH_DEBUG = 'api'
                }

                gh copilot explain $Prompt
        }
        clean {
                # Restore GH_DEBUG environment variable to its original value
                $Env:GH_DEBUG = $envGhDebug
        }
}

################################################################################
# Startup
################################################################################

# Set encoding to UTF-8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

function Invoke-Starship-TransientFunction {
    &starship module character
  }

Invoke-Expression (&starship init powershell)

Invoke-Expression (& { (zoxide init powershell | Out-String) })
