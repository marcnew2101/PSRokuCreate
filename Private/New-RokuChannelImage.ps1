function New-RokuChannelImage {
<#
.Synopsis
    Generates a Roku channel icon or splash image with project text overlay.
#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[string]$FileName,
		[Parameter(Mandatory)]
		[int]$Width,
		[Parameter(Mandatory)]
		[int]$Height,
		[Parameter(Mandatory)]
		[AllowEmptyString()]
		[string]$Text,
		# When set, generate the gradient with Floyd-Steinberg dither (smoother
		# on TV but ~4x file size). Default uses LinearGradientBrush, which
		# bands visibly but compresses tightly - appropriate for icons and
		# splash that are seen at small size or briefly.
		[switch]$Dither,
		[byte[]]$GradientStart = $script:Theme.GradientStart,
		[byte[]]$GradientEnd   = $script:Theme.GradientEnd,
		[byte[]]$TextColor     = $script:Theme.TextColor
	)

	Add-Type -AssemblyName System.Drawing

	# Compile the Floyd-Steinberg gradient renderer once per session.
	# Source lives in GradientRenderer.cs alongside this file.
	if (-not ('Roku.Native.GradientRenderer' -as [type])) {
		Add-Type -Path (Join-Path $PSScriptRoot 'GradientRenderer.cs') -ReferencedAssemblies 'System.Drawing'
	}

	$bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)

	if ($Dither) {
		[Roku.Native.GradientRenderer]::Render($bitmap,
			$GradientStart[0], $GradientStart[1], $GradientStart[2],
			$GradientEnd[0],   $GradientEnd[1],   $GradientEnd[2])
	} else {
		$p0 = New-Object System.Drawing.Point(0, 0)
		$p1 = New-Object System.Drawing.Point($Width, $Height)
		$c0 = [System.Drawing.Color]::FromArgb(255, $GradientStart[0], $GradientStart[1], $GradientStart[2])
		$c1 = [System.Drawing.Color]::FromArgb(255, $GradientEnd[0],   $GradientEnd[1],   $GradientEnd[2])
		$brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($p0, $p1, $c0, $c1)
		$graphics.FillRectangle($brush, 0, 0, $bitmap.Width, $bitmap.Height)
		$brush.Dispose()
	}

	$scaleFactor = if ($Width -lt 1280) { 0.15 } else { 0.1 }
	$fontSize = [Math]::Ceiling($Width * $scaleFactor)

	# Shrink the font until the text fits within ~90% of the canvas (5% margin
	# each side). Stops at a readable floor; the smallest icon (290x218 HD) at
	# this floor still keeps Honk legible.
	$maxWidth = $Width * 0.9
	$maxHeight = $Height * 0.9
	$minFontSize = 12

	$font = New-Object System.Drawing.Font("Honk", $fontSize, "Regular", "Pixel")
	$measured = $graphics.MeasureString($Text, $font)
	while (($measured.Width -gt $maxWidth -or $measured.Height -gt $maxHeight) -and $fontSize -gt $minFontSize) {
		$font.Dispose()
		$fontSize -= 2
		$font = New-Object System.Drawing.Font("Honk", $fontSize, "Regular", "Pixel")
		$measured = $graphics.MeasureString($Text, $font)
	}

	$rect = [System.Drawing.RectangleF]::FromLTRB(0, 0, $Width, $Height)
	$format = [System.Drawing.StringFormat]::GenericDefault
	$format.Alignment = [System.Drawing.StringAlignment]::Center
	$format.LineAlignment = [System.Drawing.StringAlignment]::Center
	$textBrushColor = [System.Drawing.Color]::FromArgb(255, $TextColor[0], $TextColor[1], $TextColor[2])
	$textBrush = New-Object System.Drawing.SolidBrush($textBrushColor)
	$graphics.DrawString($Text, $font, $textBrush, $rect, $format)
	$textBrush.Dispose()
	$graphics.Dispose()

	try {
		switch -Regex ($FileName) {
			'\.png$'    { $bitmap.Save($FileName, [System.Drawing.Imaging.ImageFormat]::Png) }
			'\.jpe?g$'  { $bitmap.Save($FileName, [System.Drawing.Imaging.ImageFormat]::Jpeg) }
			default     { throw "Unsupported image extension. Expected .png, .jpg, or .jpeg; got: $FileName" }
		}
	} catch {
		Write-Host "Error saving image file: $($_.Exception.Message)" -ForegroundColor $script:Theme.Error
	}
	$bitmap.Dispose()
}
