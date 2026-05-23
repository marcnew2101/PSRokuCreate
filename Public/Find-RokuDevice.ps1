function Find-RokuDevice {
<#
.Synopsis
    Finds Roku devices on the local network.
.Description
    Uses SSDP M-SEARCH to discover Roku devices. Sends from every active IPv4
    interface so multi-NIC machines (Hyper-V, VPN, VMware) don't lose multicast
    to virtual adapters.
.Parameter SearchTimeout
    Maximum seconds to listen for SSDP replies after sending the M-SEARCH.
    Defaults to 10. The MX header on the wire is capped at 5 per UPnP spec
    regardless of this value (Roku ignores MX > 5).
.Parameter DeviceType
    SSDP Search Target. Defaults to 'roku:ecp' which targets only Roku
    devices' External Control Protocol service. Leave as-is for normal use.
.Outputs
    PSCustomObject with one IPAddress field (typed [System.Net.IPAddress])
    per discovered device, deduplicated by source IP. Returns nothing if no
    devices respond.
.Example
    Find-RokuDevice
.Example
    Find-RokuDevice -SearchTimeout 20 | Get-RokuDeviceInfo
#>
	[CmdletBinding()]
	param(
		[int]$SearchTimeout = 10,
		[string]$DeviceType = 'roku:ecp'
	)

	Write-Host "Searching for Roku devices on your network..." -ForegroundColor $script:Theme.Info

	$multicastIP = '239.255.255.250'
	$multicastPort = 1900
	# MX must be 1-5 per UPnP spec; Roku ignores requests with MX > 5.
	$mx = [Math]::Min($SearchTimeout, 5)
	$msearch = "M-SEARCH * HTTP/1.1`r`nHOST: ${multicastIP}:${multicastPort}`r`nMAN: `"ssdp:discover`"`r`nMX: $mx`r`nST: $DeviceType`r`n`r`n"
	$bytes = [Text.Encoding]::UTF8.GetBytes($msearch)
	$endpoint = [Net.IPEndPoint]::new([Net.IPAddress]::Parse($multicastIP), $multicastPort)

	$localIPs = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
		Where-Object { $_.OperationalStatus -eq 'Up' -and $_.NetworkInterfaceType -ne 'Loopback' } |
		ForEach-Object { $_.GetIPProperties().UnicastAddresses } |
		Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' } |
		ForEach-Object { $_.Address }

	$clients = @()
	$seen = @{}
	try {
		foreach ($localIP in $localIPs) {
			try {
				$c = [Net.Sockets.UdpClient]::new([Net.IPEndPoint]::new($localIP, 0))
				$c.Client.SetSocketOption(
					[Net.Sockets.SocketOptionLevel]::IP,
					[Net.Sockets.SocketOptionName]::MulticastInterface,
					$localIP.GetAddressBytes()
				)
				$c.Send($bytes, $bytes.Length, $endpoint) | Out-Null
				$clients += $c
				Write-Verbose "M-SEARCH sent from $localIP"
			} catch {
				Write-Verbose "Skipping ${localIP}: $($_.Exception.Message)"
			}
		}

		$start = [DateTime]::UtcNow
		$deadline = $start.AddSeconds($SearchTimeout)
		$lastProgress = [DateTime]::MinValue
		$barWidth = 30
		# [char]0x25A0 = filled square. Built from a codepoint so the source
		# stays ASCII-only (PS 5.1 reads BOM-less .psm1 as Windows-1252).
		$blockChar = [char]0x25A0
		while ([DateTime]::UtcNow -lt $deadline) {
			$now = [DateTime]::UtcNow
			if (($now - $lastProgress).TotalMilliseconds -ge 250) {
				$elapsed = ($now - $start).TotalSeconds
				$pct = [Math]::Min(100, [int](($elapsed / $SearchTimeout) * 100))
				$remaining = [Math]::Max(0, [int]($SearchTimeout - $elapsed))
				$filled = [int](($pct / 100) * $barWidth)
				$bar = ($blockChar.ToString() * $filled) + (' ' * ($barWidth - $filled))
				$line = "  [$bar] $pct% ($($seen.Count) found, $($remaining)s)"
				[Console]::Write("`r" + $line.PadRight(70))
				$lastProgress = $now
			}

			$gotData = $false
			foreach ($c in $clients) {
				while ($c.Available -gt 0) {
					$gotData = $true
					$remote = [Net.IPEndPoint]::new([Net.IPAddress]::Any, 0)
					$reply = [Text.Encoding]::UTF8.GetString($c.Receive([ref]$remote))
					if ($reply -like '*roku*') {
						$seen[$remote.Address.ToString()] = $reply
					}
				}
			}
			if (-not $gotData) { Start-Sleep -Milliseconds 100 }
		}
	} finally {
		Write-Progress -Activity "Searching for Roku devices" -Completed
		foreach ($c in $clients) { try { $c.Close() } catch {} }
	}

	foreach ($reply in $seen.Values) {
		# -like on an array returns an array even for one match; index [0] unwraps
		# so -as [uri] sees a string, not Object[] (which casts to $null).
		$locLine = ($reply -split "`r`n" -like 'LOCATION:*')[0]
		$loc = ($locLine -replace '^Location:\s{1,}') -as [uri]
		if ($loc.DnsSafeHost -like '*.*') {
			[PSCustomObject]@{ IPAddress = [IPAddress]$loc.DnsSafeHost }
		}
	}
}
