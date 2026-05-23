function New-RokuManifest {
<#
.Synopsis
    Writes a Roku channel manifest file to the project root.
#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[string]$Destination,
		[Parameter(Mandatory)]
		[string]$ProjectName
	)

	$manifestContent = @"
title=$ProjectName
major_version=1
minor_version=0
build_version=1
mm_icon_focus_fhd=pkg:/images/icons/channel-icon_FHD.png
mm_icon_focus_hd=pkg:/images/icons/channel-icon_HD.png
splash_screen_fhd=pkg:/images/splash/splash-screen_FHD.png
splash_screen_hd=pkg:/images/splash/splash-screen_HD.png
splash_color=#2A0845
splash_min_time=1500
ui_resolutions=hd,fhd
"@
	$manifestPath = Join-Path -Path $Destination -ChildPath 'manifest'
	Set-Content -Path $manifestPath -Value $manifestContent -Encoding ascii -Force
}
