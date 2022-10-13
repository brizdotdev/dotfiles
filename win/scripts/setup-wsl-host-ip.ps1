# Setup the WINDOWS host IP address for WSL2 in the inventory file
$wslIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object -Property InterfaceAlias -Like "*WSL*").IPAddress
$inventory = $PSScriptRoot + "\..\ansible\hosts"
$inventoryContent = Get-Content -Path $inventory -Raw
$inventoryContent = $inventoryContent -Replace "{IP}", $wslIP
$inventoryContent | Set-Content -Path $inventory