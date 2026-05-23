function Confirm-RokuDeveloperMode {
<#
.Synopsis
    Verifies that a Roku device has developer mode enabled, walking the user
    through enabling it in-place if it isn't.
.Description
    Returns the device info object (with Index, IPAddress, ModelName,
    DeveloperEnabled) once developer mode is confirmed enabled.
    Returns $null if the user chose to abort.

    If $DeviceInfo is supplied (e.g. from an earlier Get-RokuDeviceInfo call
    during discovery) it's used as the initial state. Otherwise the device is
    queried fresh, which also serves as a reachability test for manually-entered
    IPs.
#>
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	param(
		[Parameter(Mandatory)]
		[string]$Device,
		$DeviceInfo
	)

	while ($true) {
		if (-not $DeviceInfo) {
			$queryResult = Get-RokuDeviceInfo -Devices @([PSCustomObject]@{IPAddress = $Device})
			$DeviceInfo = $queryResult | Select-Object -First 1
		}

		if (-not $DeviceInfo) {
			Write-Host ""
			Write-Host "Could not reach a Roku at $Device. The device may still be rebooting, or the IP may be wrong." -ForegroundColor $script:Theme.Error
			$retry = Read-Host "Press Enter to try again, or type 'x' to exit"
			if ($retry.Trim() -match '^[xX]$') { return $null }
			continue
		}

		if ($DeviceInfo.DeveloperEnabled) { return $DeviceInfo }

		Write-Host ""
		Write-Host "Developer mode is not enabled on the Roku at $Device ($($DeviceInfo.ModelName))." -ForegroundColor $script:Theme.Warning
		Write-Host ""
		Write-Host "To enable developer mode, press this sequence on your Roku remote:"
		Write-Host ""
		Write-Host "    Home (x3), Up (x2), Right, Left, Right, Left, Right" -ForegroundColor $script:Theme.Info
		Write-Host ""
		Write-Host "On the screen that appears:"
		Write-Host "  1. Accept the developer agreement"
		Write-Host "  2. Set a developer password (you'll need it at the next prompt)"
		Write-Host "  3. The device will reboot (give it ~30 seconds to come back up)"
		Write-Host ""
		$reply = Read-Host "Press Enter when developer mode is enabled, or type 'x' to exit"
		if ($reply.Trim() -match '^[xX]$') { return $null }
		# Force a fresh query on the next iteration to pick up the new state.
		$DeviceInfo = $null
	}
}
