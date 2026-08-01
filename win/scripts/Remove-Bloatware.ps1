#Requires -RunAsAdministrator

function Assert-Environment {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal] $identity
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $isDesktop = $PSVersionTable.PSEdition -eq 'Desktop'

    if ($isAdmin -and $isDesktop) { return }

    $launchArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
    if ($script:PSBoundParameters.Count) {
        foreach ($k in $script:PSBoundParameters.Keys) {
            $launchArgs += "-$k"; $launchArgs += $script:PSBoundParameters[$k]
        }
    }

    if (-not $isAdmin) {
        Write-Host -ForegroundColor Cyan "Not elevated; relaunching via UAC..."
        $p = Start-Process powershell.exe -Verb RunAs -ArgumentList $launchArgs -PassThru -Wait
        exit $p.ExitCode
    }

    Write-Host -ForegroundColor Cyan "DISM cmdlets require Windows PowerShell 5.1 (MSIX pwsh is unsupported); relaunching..."
    & powershell.exe @launchArgs
    exit $LASTEXITCODE
}

Assert-Environment

Write-Host -ForegroundColor Blue "Removing bloatware"

$packages = @(
    "*3dbuilder*",
    "*actiprosoftwarellc*",
    "*adobephotoshopexpress*",
    "*advertising.xaml*",
    "*appconnector*",
    "*asphalt8*",
    "*autodesksketchbook*",
    "*bethesda*",
    "*bingfinance*",
    "*bingfoodanddrink*",
    "*binghealthandfitness*",
    "*bingnews*",
    "*bingsearch*",
    "*bingsports*",
    "*bingtranslator*",
    "*bingtravel*",
    "*bingweather*",
    "*bubblewitch*",
    "*caesarsslots*",
    "*candycrush*",
    "*clipchamp*",
    "*connectivitystore*",
    "*cookingfever*",
    "*copilot*",
    "*crossdevice*",
    "*cyberlinkmediastudio*",
    "*disney*",
    "*dolby*",
    "*drawboardpdf*",
    "*duolingo*",
    "*eclipse*",
    "*facebook*",
    "*farmville*",
    "*feedbackhub*",
    "*fitbit*",
    "*flipboard*",
    "*gamingservices*",
    "*gethelp*",
    "*getstarted*",
    "*hiddencity*",
    "*iheartradio*",
    "*keeper*",
    "*king.com*",
    "*linkedin*",
    "*marchofempires*",
    "*messaging*",
    "*microsoft.gamingapp*",
    "*microsoft.powerautomatedesktop*",
    "*microsoft.startexperiencesapp*",
    "*microsoft.windows.devhome*",
    "*microsoft3dviewer*",
    "*microsoftfamily*",
    "*minecraft*",
    "*mixedreality*",
    "*netflix*",
    "*networkspeedtest*",
    "*officehub*",
    "*oneconnect*",
    "*onenote*",
    "*pandora*",
    "*people*",
    "*phone*",
    "*phototastic*",
    "*picsart*",
    "*plex*",
    "*polarr*",
    "*powerbi*",
    "*print3d*",
    "*quickassist*",
    "*readinglist*",
    "*royalrevolt*",
    "*screensketch*",
    "*shazam*",
    "*skype*",
    "*sling*",
    "*solitaire*",
    "*soundrecorder*",
    "*stickynotes*",
    "*sway*",
    "*todos*",
    "*tunein*",
    "*twitter*",
    "*wallet*",
    "*windowsalarms*",
    "*windowscommunicationsapps*",
    "*windowsfeedbackhub*",
    "*windowsmaps*",
    "*wunderlist*",
    "*xbox*",
    "*xing*",
    "*zune*",
    "*whatsapp*",
    "*linkedin*",
    "*Microsoft.Edge.GameAssist*",
    "*Microsoft.OutlookForWindows*",
    "*Microsoft.549981C3F5F10*"
)

$i = 0
foreach ($package in $packages) {
    $i++
    Write-Progress -Activity "Removing bloatware" -Status "Removing $package ($i/$($packages.Count))" -PercentComplete (($i / $packages.Count) * 100)
    Get-AppxPackage -Name $package | Remove-AppxPackage -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $package | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
}
Write-Progress -Activity "Removing bloatware" -Completed

# Widgets (adapted from winutil WPFTweaksWidget)
# Sometimes if you don't stop the Widgets process the removal may fail
Get-Process -Name "*Widget*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-AppxPackage -Name "Microsoft.WidgetsPlatformRuntime" -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
Get-AppxPackage -Name "MicrosoftWindows.Client.WebExperience" -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
Get-AppxProvisionedPackage -Online | Where-Object DisplayName -in @("Microsoft.WidgetsPlatformRuntime", "MicrosoftWindows.Client.WebExperience") | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
# Restart Explorer so the Widgets taskbar button disappears (winutil Invoke-WinUtilExplorerUpdate -action "restart")
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Write-Host -ForegroundColor Green "Removed widgets"

$capabilities = @(
    "Language.Handwriting",
    "Browser.InternetExplorer",
    "MathRecognizer",
    "OneCoreUAP.OneSync",
    "Microsoft.Windows.PowerShell.ISE",
    "App.Support.QuickAssist",
    "Language.Speech",
    "Language.TextToSpeech",
    "App.StepsRecorder",
    "Media.WindowsMediaPlayer",
    "Microsoft.Windows.WordPad"
)

$i = 0
foreach ($capability in $capabilities) {
    $i++
    Write-Progress -Activity "Removing capabilities" -Status "$capability ($i/$($capabilities.Count))" -PercentComplete (($i / $capabilities.Count) * 100)
    Get-WindowsCapability -Online | Where-Object { $_.Name -like "*$capability*" } | Remove-WindowsCapability -Online -ErrorAction SilentlyContinue | Out-Null
}
Write-Progress -Activity "Removing capabilities" -Completed

$features = @(
    "MediaPlayback",
    "MicrosoftWindowsPowerShellV2Root",
    "Recall"
)

$i = 0
foreach ($feature in $features) {
    $i++
    Write-Progress -Activity "Disabling features" -Status "$feature ($i/$($features.Count))" -PercentComplete (($i / $features.Count) * 100)
    $installed = Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -eq $feature }
    if ($installed -and $installed.State -notin @('Disabled', 'DisabledWithPayloadRemoved')) {
        Disable-WindowsOptionalFeature -Online -FeatureName $feature -Remove -NoRestart -ErrorAction SilentlyContinue | Out-Null
        Write-Host -ForegroundColor Green "Disabled feature: $feature"
    }
}
Write-Progress -Activity "Disabling features" -Completed

Write-Host -ForegroundColor Green "Done removing bloatware"
exit 0
