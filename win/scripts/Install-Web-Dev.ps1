Write-Host -ForegroundColor Blue "Installing browsers"
winget install --silent Google.Chrome.Dev
winget install --silent Google.Chrome.Beta
winget install --silent Google.Chrome.Canary
winget install --silent Mozilla.Firefox.Beta
winget install --silent Mozilla.Firefox.DeveloperEdition
winget install --silent Microsoft.Edge.Dev
winget install --silent Microsoft.Edge.Beta
Write-Host -ForegroundColor Green "Done installing browsers"
exit 0