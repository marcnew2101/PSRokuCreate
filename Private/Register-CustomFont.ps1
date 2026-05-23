function Register-CustomFont {
<#
.Synopsis
    Registers all .ttf files in a directory with the current process via GDI.
.Description
    Uses AddFontResource (gdi32.dll) so System.Drawing.Font can resolve fonts
    that aren't installed system-wide. Only affects the current PowerShell
    process - no persistent system change.
#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[string]$FontPath
	)

	$fonts = Get-ChildItem -Path $FontPath -Filter '*.ttf' -File -ErrorAction SilentlyContinue
	if (-not $fonts) {
		Write-Host "No font files found in fonts directory. Press any key to continue..."
		$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
		return
	}

	if (-not ('Roku.Native.Gdi' -as [type])) {
		Add-Type -Namespace 'Roku.Native' -Name 'Gdi' -MemberDefinition @"
[DllImport("gdi32.dll")]
public static extern int AddFontResource(string filePath);
"@
	}

	foreach ($font in $fonts) {
		[Roku.Native.Gdi]::AddFontResource($font.FullName) | Out-Null
	}
}
