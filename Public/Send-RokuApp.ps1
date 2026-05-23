function Send-RokuApp {
<#
.Synopsis
    Side-loads a Roku channel zip to a developer-enabled Roku device.
.Description
    Zips the project directory, POSTs it to http://<Device>/plugin_install
    using HTTP Digest auth (username rokudev), parses Roku's response, and
    returns a result object. Always uses Roku's Replace mode so the call is
    idempotent whether or not a dev channel is already installed.
.Parameter Device
    IP address of the Roku device. Developer mode must be enabled.
.Parameter Password
    Developer password (plain string). Leading and trailing whitespace is
    trimmed before use.
.Parameter ProjectPath
    Local directory containing the channel project. Must include a manifest
    file at the root.
.Outputs
    PSCustomObject with Success (bool), Message (string), RawResponse (string).
.Example
    $pw = Read-Host "Roku dev password"
    Send-RokuApp -Device 10.1.40.113 -Password $pw -ProjectPath C:\proj\MyChannel
#>
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password',
		Justification = 'Plain string is intentional - the wizard shows the password during entry so the user can visually verify it was typed correctly.')]
	param(
		[Parameter(Mandatory)]
		[string]$Device,
		[Parameter(Mandatory)]
		[string]$Password,
		[Parameter(Mandatory)]
		[string]$ProjectPath
	)

	if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
		return [PSCustomObject]@{
			Success = $false
			Message = "Project path does not exist or is not a directory: $ProjectPath"
			RawResponse = $null
		}
	}

	Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue

	# Trim because trailing whitespace in the password input is a common
	# foot-gun that surfaces later as "Incorrect developer password".
	$plainPassword = $Password.Trim()

	# GetTempFileName creates a 0-byte file; remove it so Compress-Archive can write
	# the .zip in its place without -Update mode.
	$zipPath = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), '.zip')
	Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue

	try {
		Write-Host "Compressing project..." -ForegroundColor $script:Theme.Info
		# Compress-Archive writes backslash separators (source\main.brs) which Roku's
		# parser rejects with "Script directory '/source' does not exist in plugin".
		# Build the zip manually so entry paths use forward slashes.
		Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
		Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
		$projRoot = (Resolve-Path -LiteralPath $ProjectPath).Path.TrimEnd('\','/')
		$fs = [System.IO.File]::Create($zipPath)
		try {
			$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
			try {
				foreach ($file in (Get-ChildItem -LiteralPath $projRoot -Recurse -File)) {
					$rel = $file.FullName.Substring($projRoot.Length + 1).Replace('\','/')
					$entry = $zip.CreateEntry($rel, [System.IO.Compression.CompressionLevel]::Optimal)
					$entryStream = $entry.Open()
					try {
						$fileStream = [System.IO.File]::OpenRead($file.FullName)
						try { $fileStream.CopyTo($entryStream) } finally { $fileStream.Close() }
					} finally { $entryStream.Close() }
				}
			} finally { $zip.Dispose() }
		} finally { $fs.Close() }

		Write-Host "Sideloading to $Device..." -ForegroundColor $script:Theme.Info

		$uri = "http://${Device}/plugin_install"
		$handler = New-Object System.Net.Http.HttpClientHandler
		$cache = New-Object System.Net.CredentialCache
		$cache.Add([Uri]$uri, 'Digest', (New-Object System.Net.NetworkCredential('rokudev', $plainPassword)))
		$handler.Credentials = $cache
		$client = New-Object System.Net.Http.HttpClient($handler)
		$client.Timeout = [TimeSpan]::FromSeconds(30)

		$response = $null
		$body = $null
		try {
			# Build the multipart body manually. .NET's MultipartFormDataContent emits
			# unquoted field names (name=foo) and an RFC 5987 filename* parameter, both
			# of which Roku's parser chokes on with "mysubmit Field Not Found". We control
			# bytes directly to ensure quoted names, no filename*, and no Content-Type on
			# the form field. The mysubmit part also goes before archive.
			$boundary = "----rokuboundary$([guid]::NewGuid().ToString('N'))"
			$crlf = "`r`n"
			$fileBytes = [System.IO.File]::ReadAllBytes($zipPath)

			$ms = New-Object System.IO.MemoryStream
			try {
				$part1 = "--$boundary$crlf" +
					"Content-Disposition: form-data; name=`"mysubmit`"$crlf$crlf" +
					"Replace$crlf"
				$b1 = [Text.Encoding]::ASCII.GetBytes($part1)
				$ms.Write($b1, 0, $b1.Length)

				$part2 = "--$boundary$crlf" +
					"Content-Disposition: form-data; name=`"archive`"; filename=`"archive.zip`"$crlf" +
					"Content-Type: application/zip$crlf$crlf"
				$b2 = [Text.Encoding]::ASCII.GetBytes($part2)
				$ms.Write($b2, 0, $b2.Length)
				$ms.Write($fileBytes, 0, $fileBytes.Length)

				$b3 = [Text.Encoding]::ASCII.GetBytes("$crlf--$boundary--$crlf")
				$ms.Write($b3, 0, $b3.Length)
				$bodyBytes = $ms.ToArray()
			} finally {
				$ms.Dispose()
			}

			$content = New-Object System.Net.Http.ByteArrayContent (,$bodyBytes)
			$content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("multipart/form-data; boundary=$boundary")

			$response = $client.PostAsync($uri, $content).GetAwaiter().GetResult()
			$body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
		} catch {
			$inner = $_.Exception
			while ($inner.InnerException) { $inner = $inner.InnerException }
			return [PSCustomObject]@{
				Success = $false
				Message = "Could not reach Roku at ${Device}: $($inner.Message)"
				RawResponse = $null
			}
		} finally {
			if ($client) { $client.Dispose() }
			if ($handler) { $handler.Dispose() }
		}

		if ($response.StatusCode -eq [System.Net.HttpStatusCode]::Unauthorized) {
			return [PSCustomObject]@{
				Success = $false
				Message = "Incorrect developer password"
				RawResponse = $body
			}
		}

		# Roku reports both success and failure inside <font color="red">...</font>.
		# Extract every red-tagged message, strip inner HTML, collapse whitespace.
		$rokuMatches = [regex]::Matches($body, '<font[^>]*color="?red"?[^>]*>(.*?)</font>', 'Singleline,IgnoreCase')
		$messages = @($rokuMatches | ForEach-Object {
			($_.Groups[1].Value -replace '<[^>]+>', '' -replace '\s+', ' ').Trim()
		} | Where-Object { $_ })
		$combined = $messages -join '; '

		$successPatterns = @('Application Received', 'Install Success', 'Identical to previous')
		$isSuccess = $false
		foreach ($p in $successPatterns) {
			if ($combined -match [regex]::Escape($p)) { $isSuccess = $true; break }
		}

		if ($isSuccess) {
			return [PSCustomObject]@{
				Success = $true
				Message = if ($combined) { $combined } else { "Installed on $Device" }
				RawResponse = $body
			}
		} else {
			return [PSCustomObject]@{
				Success = $false
				Message = if ($combined) { $combined } else { "Sideload failed (HTTP $([int]$response.StatusCode))" }
				RawResponse = $body
			}
		}
	} catch {
		return [PSCustomObject]@{
			Success = $false
			Message = "Sideload error: $($_.Exception.Message)"
			RawResponse = $null
		}
	} finally {
		Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
	}
}
