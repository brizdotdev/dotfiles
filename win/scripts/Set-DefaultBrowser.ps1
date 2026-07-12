<#
.SYNOPSIS
    Registers a browser as a capable default and opens the Windows
    "Default apps" page so the user can click "Set default" once.

.DESCRIPTION
    Mirrors Firefox's supported "Make Default" flow on Windows 11:
      1. Write per-user (HKCU) capability registration so Windows knows the
         browser can handle http/https/.htm/.html/.pdf.
      2. Launch the documented ms-settings deep link so the user performs the
         single required click. No UserChoice hash, no admin, no UCPD.

.PARAMETER Browser
    Which browser to register. One of: Firefox, Chrome, LibreWolf.

.PARAMETER ExePath
    Optional explicit path to the browser executable. If omitted, common
    install locations and the PATH are searched.

.PARAMETER NoLaunch
    Register only; do not open the Settings deep link.

.EXAMPLE
    .\Set-DefaultBrowser.ps1 -Browser LibreWolf
    .\Set-DefaultBrowser.ps1 -Browser Chrome -ExePath "C:\Tools\chrome.exe"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Firefox', 'Chrome', 'LibreWolf')]
    [string]$Browser,

    [string]$ExePath,
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'

$browserConfig = @{
    Firefox = @{
        RegName      = 'Firefox'
        AppName      = 'Firefox'
        UrlProgId    = 'FirefoxURL'
        HtmlProgId   = 'FirefoxHTML'
        PdfProgId    = 'FirefoxPDF'
        UrlCmdArgs   = '-osint -url "%1"'
        HtmlCmdArgs  = '-osint -url "%1"'
        PdfCmdArgs   = '"%1"'
        ExeName      = 'firefox'
        ExeCandidates = @(
            (Join-Path $env:ProgramFiles 'Mozilla Firefox\firefox.exe')
            (Join-Path ${env:ProgramFiles(x86)} 'Mozilla Firefox\firefox.exe')
        )
    }
    Chrome = @{
        RegName      = 'Chrome'
        AppName      = 'Google Chrome'
        UrlProgId    = 'ChromeHTML'
        HtmlProgId   = 'ChromeHTML'
        PdfProgId    = 'ChromeHTML'
        UrlCmdArgs   = '"%1"'
        HtmlCmdArgs  = '"%1"'
        PdfCmdArgs   = '"%1"'
        ExeName      = 'chrome'
        ExeCandidates = @(
            (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe')
            (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe')
        )
    }
    LibreWolf = @{
        RegName      = 'LibreWolf'
        AppName      = 'LibreWolf'
        UrlProgId    = 'LibreWolfURL'
        HtmlProgId   = 'LibreWolfHTML'
        PdfProgId    = 'LibreWolfPDF'
        UrlCmdArgs   = '-osint -url "%1"'
        HtmlCmdArgs  = '-osint -url "%1"'
        PdfCmdArgs   = '"%1"'
        ExeName      = 'librewolf'
        ExeCandidates = @(
            (Join-Path $env:LOCALAPPDATA 'Programs\LibreWolf\librewolf.exe')
            (Join-Path $env:ProgramFiles 'LibreWolf\librewolf.exe')
            (Join-Path ${env:ProgramFiles(x86)} 'LibreWolf\librewolf.exe')
        )
    }
}

function Find-BrowserExe {
    param(
        [string]$Path,
        [string]$ExeName,
        [string[]]$Candidates
    )

    if ($Path -and (Test-Path -LiteralPath $Path)) { return $Path }

    foreach ($c in $Candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    }

    $cmd = Get-Command $ExeName -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    # App Paths fallback
    $appPathKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$ExeName.exe"
    $appPath = Get-ItemProperty $appPathKey -ErrorAction SilentlyContinue
    if ($appPath -and $appPath.'(Default)' -and (Test-Path -LiteralPath $appPath.'(Default)')) {
        return $appPath.'(Default)'
    }

    throw "$ExeName executable not found. Pass -ExePath '<full path to the executable>'."
}

function Set-RegValue {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] $Value,
        [string]$Type = 'String'
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

# ---------------------------------------------------------------------------
# 1. Resolve configuration and locate the binary
# ---------------------------------------------------------------------------
$cfg = $browserConfig[$Browser]

$exe = Find-BrowserExe -Path $ExePath -ExeName $cfg.ExeName -Candidates $cfg.ExeCandidates
Write-Host "Using $($cfg.AppName): $exe"

$iconPath = "$exe,0"

# ---------------------------------------------------------------------------
# 2. Capability registration (HKCU)
# ---------------------------------------------------------------------------
$regName = $cfg.RegName
$capRoot = "HKCU:\Software\$regName\Capabilities"

Set-RegValue 'HKCU:\Software\RegisteredApplications' $regName "Software\$regName\Capabilities"

Set-RegValue $capRoot 'ApplicationName'        $cfg.AppName
Set-RegValue $capRoot 'ApplicationDescription' "$($cfg.AppName) Web Browser"
Set-RegValue $capRoot 'ApplicationIcon'        $iconPath

Set-RegValue "$capRoot\URLAssociations"  'http'  $cfg.UrlProgId
Set-RegValue "$capRoot\URLAssociations"  'https' $cfg.UrlProgId

Set-RegValue "$capRoot\FileAssociations" '.htm'  $cfg.HtmlProgId
Set-RegValue "$capRoot\FileAssociations" '.html' $cfg.HtmlProgId
Set-RegValue "$capRoot\FileAssociations" '.pdf'  $cfg.PdfProgId

# ProgIds under HKCU\Software\Classes
$urlCmd  = "`"$exe`" $($cfg.UrlCmdArgs)"
$htmlCmd = "`"$exe`" $($cfg.HtmlCmdArgs)"
$pdfCmd  = "`"$exe`" $($cfg.PdfCmdArgs)"

Set-RegValue "HKCU:\Software\Classes\$($cfg.UrlProgId)"  '(Default)'      "$($cfg.AppName) URL"
Set-RegValue "HKCU:\Software\Classes\$($cfg.UrlProgId)"  'URL Protocol'   ''
Set-RegValue "HKCU:\Software\Classes\$($cfg.UrlProgId)\shell\open\command" '(Default)' $urlCmd

Set-RegValue "HKCU:\Software\Classes\$($cfg.HtmlProgId)" '(Default)'      "$($cfg.AppName) HTML Document"
Set-RegValue "HKCU:\Software\Classes\$($cfg.HtmlProgId)\shell\open\command" '(Default)' $htmlCmd

Set-RegValue "HKCU:\Software\Classes\$($cfg.PdfProgId)"  '(Default)'      "$($cfg.AppName) PDF Document"
Set-RegValue "HKCU:\Software\Classes\$($cfg.PdfProgId)\shell\open\command" '(Default)' $pdfCmd

# StartMenuInternet entry for full parity with Firefox
$smtRoot = "HKCU:\Software\Clients\StartMenuInternet\$regName"
Set-RegValue $smtRoot                                  '(Default)'      $cfg.AppName
Set-RegValue "$smtRoot\Capabilities"                   '(Default)'      ''
Set-RegValue "$smtRoot\shell\open\command"             '(Default)'      "`"$exe`""
Set-RegValue 'HKCU:\Software\Clients\StartMenuInternet' '(Default)'      $regName

# ---------------------------------------------------------------------------
# 3. Open the Settings deep link (one click required from the user)
# ---------------------------------------------------------------------------
$deepLink = "ms-settings:defaultapps?registeredAppUser=$regName"
Write-Host "Registration complete. Opening: $deepLink"
Write-Host "In Settings, click 'Set default' for $($cfg.AppName) (single click)."

if (-not $NoLaunch) {
    Start-Process $deepLink
}

# ---------------------------------------------------------------------------
# 4. Verify registration
# ---------------------------------------------------------------------------
$verify = Get-ItemProperty 'HKCU:\Software\RegisteredApplications' -ErrorAction SilentlyContinue
if ($verify.$regName) {
    Write-Host "OK: '$regName' is registered under HKCU\Software\RegisteredApplications." -ForegroundColor Green
}
else {
    Write-Warning "Verification failed: '$regName' not found in RegisteredApplications."
}
