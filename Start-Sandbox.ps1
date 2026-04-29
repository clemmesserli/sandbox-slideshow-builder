param(
	[Parameter(Mandatory)]
	[string]$SharePath,

	[Parameter(Mandatory)]
	[string]$InputPath
)

# Validate InputPath
if (!(Test-Path $InputPath)) {
	Write-Error "InputPath not found: $InputPath"
	exit
}

# Create SharePath if needed
New-Item -ItemType Directory -Force -Path $SharePath | Out-Null
Write-Host "[OK] Share folder ready: $SharePath"

# Copy framework files
foreach ($file in @('LetsPlay.ps1', 'sandbox.wsb')) {
	$src = Join-Path $PSScriptRoot $file
	if (!(Test-Path $src)) { Write-Error "Missing framework file: $src"; exit }
	Copy-Item $src -Destination $SharePath -Force
}
Write-Host "[OK] Framework files copied"

# Copy input assets
if (Test-Path $InputPath -PathType Leaf) {
	Copy-Item $InputPath -Destination (Join-Path $SharePath "input.txt") -Force
	Write-Host "[OK] Input file copied as input.txt"
} else {
	$imgDir = Join-Path $SharePath "images"
	New-Item -ItemType Directory -Force -Path $imgDir | Out-Null
	Copy-Item (Join-Path $InputPath '*') -Destination $imgDir -Recurse -Force
	Write-Host "[OK] Images copied to images\"
}

# Patch and launch sandbox
$templatePath = Join-Path $PSScriptRoot "sandbox.wsb"
$tmpWsb = Join-Path $env:TEMP "sandbox_run.wsb"
(Get-Content $templatePath -Raw) -replace 'C:\\path\\to\\your\\share', $SharePath | Set-Content $tmpWsb

Write-Host "[OK] Launching sandbox..."
Start-Process $tmpWsb
