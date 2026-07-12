#Requires -RunAsAdministrator
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

foreach ($package in $packages) {
    Get-AppxPackage -Name $package | Remove-AppxPackage -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $package | Remove-AppxProvisionedPackage -Online
}

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

foreach ($capability in $capabilities) {
    Get-WindowsCapability -Online | Where-Object { $_.Name -like "*$capability*" } | Remove-WindowsCapability -Online -ErrorAction SilentlyContinue
}

$features = @(
    "MediaPlayback",
    "MicrosoftWindowsPowerShellV2Root",
    "Recall"
)

foreach ($feature in $features) {
    $installed = Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -eq $feature }
    if ($installed -and $installed.State -notin @('Disabled', 'DisabledWithPayloadRemoved')) {
        Disable-WindowsOptionalFeature -Online -FeatureName $feature -Remove -NoRestart -ErrorAction SilentlyContinue
        Write-Host -ForegroundColor Green "Disabled feature: $feature"
    }
}

Write-Host -ForegroundColor Green "Done removing bloatware"
exit 0
