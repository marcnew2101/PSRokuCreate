function Show-FolderBrowserDialog {
<#
.Synopsis
    Opens the Windows shell folder picker.
.Description
    Returns the chosen path, or $null if the user cancels and declines to retry.
#>
	[CmdletBinding()]
	param()

	$folderMsg = "Select a location to save the project in"
	$initialDirectory = [Environment]::GetFolderPath('Desktop')

	Write-Host ""
	Write-Host "Choose a directory where your project should be saved (a folder browser has opened)..." -ForegroundColor $script:Theme.Info

	$app = New-Object -ComObject Shell.Application
	try {
		$folder = $app.BrowseForFolder(0, $folderMsg, 0, $initialDirectory)
		if ($folder) {
			return $folder.Self.Path
		}
	} finally {
		[System.Runtime.InteropServices.Marshal]::ReleaseComObject($app) > $null
	}

	$retryMsg = "No location selected. Try again? (y/n)"
	$tryAgain = Read-Host $retryMsg
	while ($tryAgain -notmatch '^[yYnN]$') {
		Write-Host "'$tryAgain' is not a valid response. Please enter y or n." -ForegroundColor $script:Theme.Error
		$tryAgain = Read-Host $retryMsg
	}
	if ($tryAgain -match '^[yY]$') {
		return Show-FolderBrowserDialog
	}
	return $null
}
