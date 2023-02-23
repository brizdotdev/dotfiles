################################################################################
# Generate an SSH Key
################################################################################
Write-Host -ForegroundColor Blue "Generating SSH Key"
ssh-keygen -t ed25519
Write-Host -ForegroundColor Green "SSH Key generated"
Write-Host
