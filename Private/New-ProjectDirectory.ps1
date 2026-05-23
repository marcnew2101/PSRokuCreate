function New-ProjectDirectory {
<#
.Synopsis
    Creates a directory inside a project.
.Description
    With -TestPath, asks the user before overwriting an existing directory.
    Returns $null if the user declines, otherwise returns the directory path.
#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[string]$Destination,
		[Parameter(Mandatory)]
		[string]$ChildPath,
		[switch]$TestPath
	)

	$directory = Join-Path -Path $Destination -ChildPath $ChildPath

	if ($TestPath -and (Test-Path -LiteralPath $directory)) {
		Write-Host ""
		Write-Host "A project already exists in $($directory)`n"
		$overwriteMsg = "Would you like to overwrite the project files? (y/n)"
		$overwrite = Read-Host $overwriteMsg
		while ($overwrite -notmatch '^[yYnN]$') {
			Write-Host "'$overwrite' is not a valid response. Please enter y or n." -ForegroundColor $script:Theme.Error
			$overwrite = Read-Host $overwriteMsg
		}
		if ($overwrite -match '^[nN]$') {
			return $null
		}
	}
	New-Item -ItemType Directory -Path $directory -Force | Out-Null
	return $directory
}
