function Get-RokuDeviceInfo {
<#
.Synopsis
    Enriches a list of Roku devices with model info and developer-mode status.
.Description
    Queries each device's ECP /query/device-info endpoint over HTTP (port 8060)
    and returns enriched device objects. Prints a compact table with selectable
    indexes for use in interactive selection prompts. Unreachable devices are
    skipped with a red message and omitted from the returned list.
.Parameter Devices
    Array of objects with an IPAddress field (e.g., output from Find-RokuDevice).
    A single device can be passed by wrapping it in an array: @($device).
.Outputs
    PSCustomObject array with fields:
        Index            - 1-based position in the printed list
        IPAddress        - the device's IP
        ModelName        - "<model-name> <model-number>" (e.g. "Ultra 4850X")
        DeveloperEnabled - $true if developer mode is enabled on the device
.Example
    Find-RokuDevice | Get-RokuDeviceInfo
.Example
    Get-RokuDeviceInfo -Devices @([PSCustomObject]@{IPAddress='10.1.40.113'})
#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[array]$Devices
	)

	$deviceInfoList = @()
	Write-Host "Retrieving device information..." -ForegroundColor $script:Theme.Info
	$i = 0
	foreach ($device in $Devices) {
		if (-not ($device -and $device.IPAddress)) { continue }
		try {
			$response = Invoke-WebRequest -Uri "http://$($device.IPAddress):8060/query/device-info" -UseBasicParsing -ErrorAction SilentlyContinue
			if (-not $response) {
				Write-Host "Unable to get device info from $($device.IPAddress)" -ForegroundColor $script:Theme.Error
				continue
			}
			$modelName = $response.Content | Select-String -Pattern "<model-name>(.*?)</model-name>" | ForEach-Object { $_.Matches.Groups[1].Value }
			$modelNumber = $response.Content | Select-String -Pattern "<model-number>(.*?)</model-number>" | ForEach-Object { $_.Matches.Groups[1].Value }
			$developerEnabled = $response.Content | Select-String -Pattern "<developer-enabled>(.*?)</developer-enabled>" | ForEach-Object { $_.Matches.Groups[1].Value }
			$developerEnabled = [System.Convert]::ToBoolean(($developerEnabled.Substring(0,1)).ToUpper() + ($developerEnabled.Substring(1)).ToLower())

			$i++
			$deviceInfoList += [PSCustomObject]@{
				Index = $i
				IPAddress = $device.IPAddress
				ModelName = "$modelName $modelNumber".Trim()
				DeveloperEnabled = $developerEnabled
			}
		} catch {
			Write-Host "Cannot reach device at $($device.IPAddress): $($_.Exception.Message)" -ForegroundColor $script:Theme.Error
		}
	}

	if ($deviceInfoList.Count -gt 0) {
		Write-Host ""
		Write-Host "Found $($deviceInfoList.Count) Roku device(s):" -ForegroundColor $script:Theme.Info
		$table = $deviceInfoList |
			Format-Table @{Label='#'; Expression={$_.Index}; Alignment='Right'},
				@{Label='Model'; Expression={$_.ModelName}},
				@{Label='IP Address'; Expression={$_.IPAddress}},
				@{Label='Developer Mode'; Expression={if ($_.DeveloperEnabled) {'Enabled'} else {'Disabled'}}} `
				-AutoSize |
			Out-String
		Write-Host $table.TrimEnd() -ForegroundColor $script:Theme.Heading
		Write-Host ""
	}
	return $deviceInfoList
}
