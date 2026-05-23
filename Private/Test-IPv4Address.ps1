function Test-IPv4Address {
<#
.Synopsis
    Returns $true if the input is a valid dotted-quad IPv4 address (each octet 0-255).
.Description
    Validates both format (x.x.x.x with 1-3 digits per octet) and octet range. The
    format check first rejects .NET's legacy IPAddress parsing of partial forms
    like "192.168.1" or numeric "16909060"; TryParse then catches octet overflow
    like "999.999.999.999".
#>
	[CmdletBinding()]
	[OutputType([bool])]
	param(
		[Parameter(Mandatory)]
		[AllowEmptyString()]
		[string]$Value
	)

	if ($Value -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { return $false }
	$ip = $null
	return [System.Net.IPAddress]::TryParse($Value, [ref]$ip)
}
