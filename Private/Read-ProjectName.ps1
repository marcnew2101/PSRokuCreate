function Read-ProjectName {
<#
.Synopsis
    Prompts the user for a valid Roku project name.
.Description
    Rejects empty input, names longer than 25 characters, names with reserved
    filename characters, and names ending in a dot. All checks run on every
    attempt so a fix to one violation can't accidentally reveal a different
    one in the response. The 25-char cap aligns with Roku Channel Store
    guidance for legible titles in the tile UI.
#>
	[CmdletBinding()]
	param()

	$newProjectMsg = "Enter a name for your project"
	while ($true) {
		$projectName = (Read-Host $newProjectMsg).Trim()

		if ($projectName -eq '') {
			Write-Host "Project name cannot be empty.`n" -ForegroundColor $script:Theme.Error
			continue
		}
		if ($projectName.Length -gt 25) {
			Write-Host "Project name cannot be longer than 25 characters.`n" -ForegroundColor $script:Theme.Error
			continue
		}
		if ($projectName -match '[\\/:*?"<>|]') {
			Write-Host "Invalid character found: $($Matches[0])`n" -ForegroundColor $script:Theme.Error
			continue
		}
		if ($projectName -match '\.$') {
			Write-Host "Project name cannot end with '.'`n" -ForegroundColor $script:Theme.Error
			continue
		}
		return $projectName
	}
}
