# Prompt the user for a yes or no response
function YesNoPrompt {
    param(
        [Parameter(Mandatory=$True)]
        [string]$Message
    )
    do {
        $prompt = "$Message [y/n]: "
        $input = Read-Host -Prompt $prompt
    } while ($input -ne "y" -and $input -ne "n")
    if ($input -eq "y") {
        return $True
    }
    return $False
}

function LinkFiles {
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[alias("s","source")]
		[string] $SourceFolder,
		[Parameter(Mandatory = $true, Position = 1)]
		[alias("t","target")]
		[string] $TargetFolder
	)

	Get-ChildItem -Path "$SourceFolder" -File | ForEach-Object {
		New-Item -ItemType SymbolicLink -Path "$TargetFolder\$($_.Name -replace 'dot-','.')" -Target "$($_.FullName)" | Out-Null
	}
}

function UnlinkFiles {
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[alias("s","source")]
		[string] $SourceFolder,
		[Parameter(Mandatory = $true, Position = 1)]
		[alias("t","target")]
		[string] $TargetFolder
	)

	Get-ChildItem -Path "$SourceFolder\" -File | ForEach-Object {
		$file = "$TargetFolder\$($_.Name -replace 'dot-','.')"
		if((Test-Path -Path $file) -and ((Get-Item $file).LinkType -eq 'SymbolicLink')) {
			(Get-Item $file).Delete()
		}
	}
}

function Reload-Path() {
	$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}