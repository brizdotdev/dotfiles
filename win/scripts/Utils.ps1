function Test-EnvPath {
	<#
	.SYNOPSIS
		Tests whether all specified paths are present in the PATH environment variable.
	.PARAMETER Paths
		One or more paths to check for in the PATH environment variable.
	.PARAMETER Scope
		The environment variable scope to check. Defaults to User.
	.OUTPUTS
		[bool] $true if all paths are present; $false if any are missing.
	.EXAMPLE
		Test-EnvPath -Paths @('C:\Tools\bin', 'C:\Tools\cmd')
	#>
	Param (
		[string[]]$Paths,
		[System.EnvironmentVariableTarget]$Scope = [System.EnvironmentVariableTarget]::User
	)
	$currentPath = [Environment]::GetEnvironmentVariable('Path', $Scope)
	$splitPath = @($currentPath -split ';' | Where-Object { $_ })
	$missingPaths = @($Paths | Where-Object { $splitPath -notcontains $_ })
	return $missingPaths.Count -eq 0
}

function Add-EnvPath {
	<#
	.SYNOPSIS
		Adds one or more paths to the PATH environment variable if not already present.
	.PARAMETER Paths
		One or more paths to add to the PATH environment variable.
	.PARAMETER Scope
		The environment variable scope to modify. Defaults to User.
	.EXAMPLE
		Add-EnvPath -Paths @('C:\Tools\bin', 'C:\Tools\cmd')
	.EXAMPLE
		Add-EnvPath -Paths @('C:\Tools\bin') -Scope Machine
	#>
	Param (
		[string[]]$Paths,
		[System.EnvironmentVariableTarget]$Scope = [System.EnvironmentVariableTarget]::User
	)
	$currentPath = [Environment]::GetEnvironmentVariable('Path', $Scope)
	$splitPath = @($currentPath -split ';' | Where-Object { $_ })
	$missingPaths = @($Paths | Where-Object { $splitPath -notcontains $_ })
	if ($missingPaths.Count -eq 0) {
		Write-Host 'All paths are already in PATH.'
	} else {
		$newPath = ($splitPath + $missingPaths) -join ';'
		[Environment]::SetEnvironmentVariable('Path', $newPath, $Scope)
		Write-Host 'Paths have been added to PATH.'
	}
}

function Get-EnvVar {
	<#
	.SYNOPSIS
		Retrieves the value of an environment variable for a specified scope.
	.PARAMETER Name
		The name of the environment variable to retrieve.
	.PARAMETER Scope
		The environment variable scope to check. Defaults to User.
	.OUTPUTS
		The value of the environment variable, or $null if it does not exist.
	.EXAMPLE
		Get-EnvVar -Name 'EDITOR'
	.EXAMPLE
		Get-EnvVar -Name 'EDITOR' -Scope Machine
	#>
	Param (
		[string]$Name,
		[System.EnvironmentVariableTarget]$Scope = [System.EnvironmentVariableTarget]::User
	)
	return [Environment]::GetEnvironmentVariable($Name, $Scope)
}

function Test-EnvVar {
	<#
	.SYNOPSIS
		Tests whether an environment variable exists and optionally matches an expected value.
	.PARAMETER Name
		The name of the environment variable to test.
	.PARAMETER Value
		The expected value of the environment variable. If omitted, only existence is checked.
	.PARAMETER Scope
		The environment variable scope to check. Defaults to User.
	.OUTPUTS
		[bool] $true if the environment variable exists and matches the expected value when provided; otherwise $false.
	.EXAMPLE
		Test-EnvVar -Name 'EDITOR'
	.EXAMPLE
		Test-EnvVar -Name 'EDITOR' -Value 'nvim.exe' -Scope User
	#>
	Param (
		[string]$Name,
		[string]$Value,
		[System.EnvironmentVariableTarget]$Scope = [System.EnvironmentVariableTarget]::User
	)
	$currentValue = [Environment]::GetEnvironmentVariable($Name, $Scope)
	if ($null -eq $currentValue) {
		return $false
	}
	if ($PSBoundParameters.ContainsKey('Value')) {
		return $currentValue -eq $Value
	}
	return $true
}

function Add-EnvVar {
	<#
	.SYNOPSIS
		Sets an environment variable if it is missing or has a different value.
	.PARAMETER Name
		The name of the environment variable to set.
	.PARAMETER Value
		The value to assign to the environment variable.
	.PARAMETER Scope
		The environment variable scope to modify. Defaults to User.
	.EXAMPLE
		Add-EnvVar -Name 'EDITOR' -Value 'nvim.exe'
	.EXAMPLE
		Add-EnvVar -Name 'DEV_HOME' -Value 'C:\Dev' -Scope Machine
	#>
	Param (
		[string]$Name,
		[string]$Value,
		[System.EnvironmentVariableTarget]$Scope = [System.EnvironmentVariableTarget]::User
	)
	if (Test-EnvVar -Name $Name -Value $Value -Scope $Scope) {
		Write-Host "Environment variable '$Name' is already set."
	} else {
		[Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
		Write-Host "Environment variable '$Name' has been set."
	}
}

function Get-PwshProfilePath {
	<#
	.SYNOPSIS
		Gets the path to a PowerShell 7 profile, asking pwsh itself so the Documents
		location is resolved correctly (OneDrive redirection, relocated Documents folder).
	.PARAMETER Scope
		Which $PROFILE scope to resolve. Defaults to CurrentUserAllHosts (profile.ps1).
	.OUTPUTS
		[string] The full path to the requested PowerShell 7 profile.
	.NOTES
		Falls back to the conventional Documents\PowerShell path when pwsh is not yet on
		PATH, which happens when PowerShell 7 was installed earlier in the same session.
	.EXAMPLE
		Get-PwshProfilePath
	.EXAMPLE
		Get-PwshProfilePath -Scope CurrentUserCurrentHost
	#>
	Param (
		[ValidateSet('CurrentUserAllHosts', 'CurrentUserCurrentHost', 'AllUsersAllHosts', 'AllUsersCurrentHost')]
		[string]$Scope = 'CurrentUserAllHosts'
	)
	$path = $null
	if (Get-Command -Name pwsh -ErrorAction SilentlyContinue) {
		$path = & pwsh -NoProfile -NoLogo -Command "`$PROFILE.$Scope" 2>$null
	}
	if ([string]::IsNullOrWhiteSpace($path)) {
		$leaf = if ($Scope -like '*AllHosts') { 'profile.ps1' } else { 'Microsoft.PowerShell_profile.ps1' }
		$root = if ($Scope -like 'AllUsers*') { Join-Path $env:ProgramFiles 'PowerShell\7' }
			else { Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell' }
		$path = Join-Path $root $leaf
	}
	return $path.Trim()
}

function Test-Symlink {
	<#
	.SYNOPSIS
		Tests whether a path is a symbolic link pointing to a given target.
	.PARAMETER Path
		The path of the symbolic link to test.
	.PARAMETER Target
		The expected target path of the symbolic link.
	.OUTPUTS
		[bool] $true if the path exists, is a symbolic link, and points to the expected target; $false otherwise.
	.EXAMPLE
		Test-Symlink -Path 'C:\Users\user\AppData\Local\settings.json' -Target 'C:\dotfiles\settings.json'
	#>
	Param (
		[string]$Path,
		[string]$Target
	)
	if (-not (Test-Path -Path $Path)) {
		return $false
	}
	$item = Get-Item -Path $Path
	return $item.LinkType -eq 'SymbolicLink' -and $item.Target -eq $Target
}

function Test-SymlinkConfig {
	<#
	.SYNOPSIS
		Tests whether all path-to-target mappings are valid symbolic links.
	.PARAMETER Config
		A hashtable where each key is a symlink path and each value is its expected target.
	.OUTPUTS
		[bool] $true if all mappings are valid symbolic links; otherwise $false.
	.EXAMPLE
		Test-SymlinkConfig -Config @{ 'C:\Users\user\AppData\Local\nvim' = 'C:\dotfiles\common\config\nvim' }
	#>
	Param (
		[hashtable]$Config
	)
	foreach ($entry in $Config.GetEnumerator()) {
		if (-not (Test-Symlink -Path $entry.Key -Target $entry.Value)) {
			return $false
		}
	}
	return $true
}

function Get-SymlinkConfigResult {
	<#
	.SYNOPSIS
		Builds a DSC-compatible result object for a symbolic link configuration.
	.PARAMETER Config
		A hashtable where each key is a symlink path and each value is its expected target.
	.OUTPUTS
		[hashtable] A result object containing whether the symlink configuration is correct.
	.EXAMPLE
		Get-SymlinkConfigResult -Config @{ 'C:\Users\user\AppData\Local\nvim' = 'C:\dotfiles\common\config\nvim' }
	#>
	Param (
		[hashtable]$Config
	)
	return @{ Result = (Test-SymlinkConfig -Config $Config) }
}

function New-Symlink {
	<#
	.SYNOPSIS
		Creates a symbolic link at the specified path pointing to a target, removing any existing file or link at that path.
	.PARAMETER Path
		The path where the symbolic link will be created.
	.PARAMETER Target
		The target path the symbolic link will point to.
	.EXAMPLE
		New-Symlink -Path 'C:\Users\user\AppData\Local\settings.json' -Target 'C:\dotfiles\settings.json'
	#>
	Param (
		[string]$Path,
		[string]$Target
	)
	if (Test-Path -Path $Path) {
		$item = Get-Item -Path $Path -Force
		if ($item.PSIsContainer -and -not $item.LinkType) {
			Remove-Item -Path $Path -Recurse -Force
		}
		else {
			Remove-Item -Path $Path -Force
		}
	}
	$parentDir = Split-Path -Path $Path -Parent
	if (-not (Test-Path -Path $parentDir)) {
		New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
	}
	New-Item -ItemType SymbolicLink -Path $Path -Target $Target | Out-Null
}

function New-SymlinkConfig {
	<#
	.SYNOPSIS
		Creates all symbolic links defined in a path-to-target mapping.
	.PARAMETER Config
		A hashtable where each key is a symlink path and each value is its target.
	.EXAMPLE
		New-SymlinkConfig -Config @{ 'C:\Users\user\AppData\Local\nvim' = 'C:\dotfiles\common\config\nvim' }
	#>
	Param (
		[hashtable]$Config
	)
	foreach ($entry in $Config.GetEnumerator()) {
		New-Symlink -Path $entry.Key -Target $entry.Value
	}
}
