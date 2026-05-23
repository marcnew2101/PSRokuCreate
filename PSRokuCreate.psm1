$script:ModuleRoot = $PSScriptRoot
$script:TemplateRoot = Join-Path $PSScriptRoot 'Templates'

# Defaults overridable via ~/.psrokucreate.json. Console roles are ConsoleColor
# names; image colors are RGB byte triplets passed to System.Drawing.
$script:Theme = @{
	Error         = 'Red'
	Warning       = 'Yellow'
	Success       = 'Green'
	Info          = 'Cyan'
	Neutral       = 'White'
	Heading       = 'Yellow'
	GradientStart = @(42, 8, 69)
	GradientEnd   = @(100, 65, 165)
	TextColor     = @(255, 255, 255)
}

$configPath = Join-Path $PSScriptRoot 'psrokucreate.json'
if (Test-Path $configPath) {
	try {
		$userTheme = Get-Content $configPath -Raw | ConvertFrom-Json
		foreach ($key in @($script:Theme.Keys)) {
			if ($userTheme.PSObject.Properties.Name -contains $key) {
				$script:Theme[$key] = $userTheme.$key
			}
		}
	} catch {
		Write-Warning "Could not load $configPath : $($_.Exception.Message)"
	}
}

foreach ($folder in 'Private', 'Public') {
	$dir = Join-Path $PSScriptRoot $folder
	if (Test-Path $dir) {
		Get-ChildItem -Path $dir -Filter '*.ps1' | ForEach-Object { . $_.FullName }
	}
}
