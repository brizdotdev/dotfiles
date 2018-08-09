function GitRemote{
    ((git config --local -l) | where {$_ -match 'url'} | select-string 'iit.*').matches[0].value.Replace(':','/').Replace('.git','')
}

function OpenGitLab{
    GitRemote | %{chrome.exe $_}
}

function GetCurrentBranch{
    (git branch | select-string -Pattern "\*.*").Matches[0].Value.Replace("* ","")
}

function OpenCurrentBranch{
    Write-Output "$(GitRemote)/tree/$(GetCurrentBranch)" | %{chrome.exe $_}
}

Set-Alias -Name "git-remote" -Value GitRemote
Set-Alias -Name "gitlab" -Value OpenGitLab
Set-Alias -Name "gitlab-b" -Value OpenCurrentBranch