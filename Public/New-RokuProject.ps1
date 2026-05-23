function New-RokuProject {
<#
.Synopsis
    Interactively scaffold a new Roku channel project.
.Description
    Prompts for a project name and target directory, copies template files,
    generates channel icons and a splash screen, writes a Roku manifest,
    and optionally side-loads to a Roku device on the local network.

    Fully interactive - no parameters. Cancel any prompt with Enter (or
    'x' in the developer-mode and unreachable-device prompts) to bail out
    cleanly; the project files stay on disk and Explorer opens to the folder.
.Outputs
    None. Side effects: creates a project directory and (optionally) sideloads
    to a Roku device.
.Example
    New-RokuProject
#>
	[CmdletBinding()]
	param()

	Show-AsciiIntro
	$projectName = Read-ProjectName
	$directoryPath = Show-FolderBrowserDialog
	if (-not $directoryPath) { return }

	$destination = New-ProjectDirectory -Destination $directoryPath -ChildPath $projectName -TestPath
	if (-not $destination) { return }

	# Templates/ mirrors the final project layout, so each subdirectory copies as-is.
	foreach ($dir in 'source', 'components', 'images') {
		Copy-Item -Path (Join-Path $script:TemplateRoot $dir) -Destination $destination -Recurse -Force
	}

	# Channel-side fonts: ship only what the channel actually references. Honk
	# stays in Templates/ for PowerShell-side icon generation but doesn't need
	# to be packaged with every channel (it's 3.7 MB).
	$fontDestination = Join-Path $destination 'fonts'
	New-Item -ItemType Directory -Path $fontDestination -Force | Out-Null
	foreach ($font in 'Comfortaa.ttf', 'LICENSE-FONT.txt') {
		Copy-Item -Path (Join-Path $script:TemplateRoot "fonts\$font") -Destination $fontDestination -Force
	}

	# Pre-create the generated-image targets so New-RokuChannelImage can write into them.
	$imagePath = Join-Path $destination 'images'
	New-Item -ItemType Directory -Path (Join-Path $imagePath 'icons') -Force | Out-Null
	New-Item -ItemType Directory -Path (Join-Path $imagePath 'splash') -Force | Out-Null
	New-Item -ItemType Directory -Path (Join-Path $imagePath 'gradients') -Force | Out-Null

	Register-CustomFont -FontPath (Join-Path $script:TemplateRoot 'fonts')
	New-RokuChannelImage -FileName (Join-Path $imagePath 'icons\channel-icon_FHD.png') -Width 540 -Height 405 -Text $projectName
	New-RokuChannelImage -FileName (Join-Path $imagePath 'icons\channel-icon_HD.png') -Width 290 -Height 218 -Text $projectName
	New-RokuChannelImage -FileName (Join-Path $imagePath 'splash\splash-screen_FHD.png') -Width 1920 -Height 1080 -Text $projectName
	New-RokuChannelImage -FileName (Join-Path $imagePath 'splash\splash-screen_HD.png') -Width 1280 -Height 720 -Text $projectName
	# Gradient-only (no text overlay) for the AppScene background URI.
	# -Dither here because the background is on-screen the entire app session.
	# Rendered at 640x360 - Roku bilinearly upscales to the display resolution,
	# which softens the dither pattern even further (a free second pass of
	# anti-banding) and quarters the source pixel count for a much smaller PNG.
	New-RokuChannelImage -FileName (Join-Path $imagePath 'gradients\background.png') -Width 640 -Height 360 -Text '' -Dither

	New-RokuManifest -Destination $destination -ProjectName $projectName

	Write-Host ""
	$sideloadPrompt = "Side load new project to a Roku device? (y/n)"
	$sideLoad = Read-Host $sideloadPrompt
	while ($sideLoad -notmatch '^[yYnN]$') {
		Write-Host "'$sideLoad' is not a valid response. Please enter y or n." -ForegroundColor $script:Theme.Error
		$sideLoad = Read-Host $sideloadPrompt
	}
	if ($sideLoad -match '^[nN]$') {
		Invoke-Item $destination
		return
	}

	Write-Host ""
	$methodPrompt = @"
How would you like to specify the Roku device?
  [1] Enter the IP address manually
  [2] Search for Roku devices on my network
  [3] Cancel sideload

Choose (1/2/3)
"@
	$method = Read-Host $methodPrompt
	while ($method -notmatch '^[123]$') {
		Write-Host "'$method' is not a valid choice. Please enter 1, 2, or 3." -ForegroundColor $script:Theme.Error
		$method = Read-Host "Choose (1/2/3)"
	}

	if ($method -eq '3') {
		Invoke-Item $destination
		return
	}

	if ($method -eq '1') {
		$ipPrompt = "Enter the IP address (x.x.x.x) of the Roku device"
		$device = Read-Host $ipPrompt
		while (-not (Test-IPv4Address $device)) {
			Write-Host "'$device' is not a valid IPv4 address (expected x.x.x.x with each value 0-255)." -ForegroundColor $script:Theme.Error
			$device = Read-Host $ipPrompt
		}
	} elseif ($method -eq '2') {
		# Discovery loop: keep searching until we find devices, the user manually
		# enters an IP, or the user exits.
		$deviceInfo = $null
		do {
			$devices = Find-RokuDevice
			$deviceInfo = Get-RokuDeviceInfo -Devices $devices
			if ($deviceInfo.Count -gt 0) { break }

			Write-Host ""
			Write-Host "No Roku devices found on your network (searched for 10 seconds)." -ForegroundColor $script:Theme.Warning
			Write-Host ""
			Write-Host "Common issues:" -ForegroundColor $script:Theme.Warning
			Write-Host "  - The Roku may be on a different network than this computer."
			Write-Host "    Check Settings > Network > About on the Roku for its current"
			Write-Host "    network name and IP address."
			Write-Host "  - Some networks (guest Wi-Fi, corporate VPN, hotel networks) block"
			Write-Host "    the multicast traffic that SSDP discovery relies on."
			Write-Host "  - Make sure the Roku device is powered on."
			Write-Host ""
			Write-Host "What would you like to do?"
			Write-Host "  [1] Search again"
			Write-Host "  [2] Enter the Roku's IP address manually"
			Write-Host "  [3] Exit"
			$choice = Read-Host "Choose (1/2/3)"
			while ($choice -notmatch '^[123]$') {
				Write-Host "'$choice' is not a valid choice. Please enter 1, 2, or 3." -ForegroundColor $script:Theme.Error
				$choice = Read-Host "Choose (1/2/3)"
			}
			if ($choice -eq '3') {
				Invoke-Item $destination
				return
			}
			if ($choice -eq '2') {
				$manualPrompt = "Enter the Roku's IP address (x.x.x.x), or press Enter to exit"
				$manualIP = Read-Host $manualPrompt
				while ($manualIP -and -not (Test-IPv4Address $manualIP)) {
					Write-Host "'$manualIP' is not a valid IPv4 address (expected x.x.x.x with each value 0-255)." -ForegroundColor $script:Theme.Error
					$manualIP = Read-Host $manualPrompt
				}
				if (-not $manualIP) {
					Invoke-Item $destination
					return
				}
				$device = $manualIP
				break
			}
			# choice == '1' falls through; loop retries discovery.
		} while ($true)

		# Only show the discovered-list selection if a manual IP wasn't entered above.
		if (-not $device) {
			$devicePrompt = "`nChoose a number from the list (or press Enter to exit)"
			$selectedDevice = Read-Host $devicePrompt
			if (-not $selectedDevice) {
				Invoke-Item $destination
				return
			}

			$matchingDevice = $null
			while (-not $matchingDevice) {
				if ($selectedDevice -match '^\d+$') {
					$idx = [int]$selectedDevice
					if ($idx -ge 1 -and $idx -le $deviceInfo.Count) {
						$matchingDevice = $deviceInfo[$idx - 1]
					}
				}

				if (-not $matchingDevice) {
					Write-Host "'$selectedDevice' isn't a valid choice. Pick a number between 1 and $($deviceInfo.Count)." -ForegroundColor $script:Theme.Error
					$selectedDevice = Read-Host "Choose a number from the list (or press Enter to exit)"
					if (-not $selectedDevice) {
						Invoke-Item $destination
						return
					}
				}
			}

			$device = $matchingDevice.IPAddress
		}
	}

	# Whether the IP came from discovery, manual fallback, or the up-front prompt,
	# verify dev mode is on (and guide the user through enabling it if not).
	$targetDevice = Confirm-RokuDeveloperMode -Device $device -DeviceInfo $matchingDevice
	if (-not $targetDevice) {
		Invoke-Item $destination
		return
	}

	$devPassword = Read-Host "Enter the developer password for the Roku device at $device"

	$result = Send-RokuApp -Device $device -Password $devPassword -ProjectPath $destination
	Write-Host ""

	$deviceLabel = if ($targetDevice.ModelName) { "$device ($($targetDevice.ModelName))" } else { $device }
	$color = if ($result.Success) { $script:Theme.Success } else { $script:Theme.Error }
	if ($result.Success) {
		Write-Host "SUCCESS: Sideloaded to $deviceLabel" -ForegroundColor $script:Theme.Success
	} else {
		Write-Host "FAILED: Sideload to $deviceLabel" -ForegroundColor $script:Theme.Error
	}

	# Break the result message into bullets and humanize byte counts in passing.
	$bullets = if ($result.Message) { $result.Message -split ';\s*' } else { @() }
	foreach ($b in $bullets) {
		$clean = $b.Trim().TrimEnd('.')
		if (-not $clean) { continue }
		$clean = [regex]::Replace($clean, '(\d+)\s*bytes', {
			param($m)
			$bytes = [long]$m.Groups[1].Value
			if ($bytes -ge 1MB)      { '{0:N1} MB' -f ($bytes / 1MB) }
			elseif ($bytes -ge 1KB)  { '{0:N0} KB' -f ($bytes / 1KB) }
			else                     { "$bytes bytes" }
		})
		Write-Host "   $clean" -ForegroundColor $color
	}
}
