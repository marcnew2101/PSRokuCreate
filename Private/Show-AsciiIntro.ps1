function Show-AsciiIntro {
<#
.Synopsis
    Prints the welcome banner.
#>
	[CmdletBinding()]
	param()

	$art = @"

 ____  ____  ____       _           ____                _
|  _ \/ ___||  _ \ ___ | | ___   _ / ___|_ __ ___  __ _| |_ ___
| |_) \___ \| |_) / _ \| |/ / | | | |   | '__/ _ \/ _` | __/ _ \
|  __/ ___) |  _ < (_) |   <| |_| | |___| | |  __/ (_| | ||  __/
|_|   |____/|_| \_\___/|_|\_\\__,_|\____|_|  \___|\__,_|\__\___|


"@
	Write-Host $art -ForegroundColor $script:Theme.Info
	Write-Host "Welcome to the PowerShell Roku Project Creator!" -ForegroundColor $script:Theme.Heading
	Write-Host "This tool will help you set up a new Roku project with all the necessary files and directories." -ForegroundColor $script:Theme.Success
	Write-Host "Let's get started!" -ForegroundColor $script:Theme.Neutral
	Write-Host "----------------------------------------------------------------" -ForegroundColor $script:Theme.Info
}
