param(
	[Parameter(Mandatory)]
	[string]$SharePath,

	[Parameter(Mandatory)]
	[string]$InputPath
)

# =============================
# Preflight: Windows Sandbox
# =============================
$edition = (Get-WindowsEdition -Online).Edition
if ($edition -like '*Home*') {
	Write-Error "Windows Sandbox is not available on Home editions (detected: $edition). Pro, Enterprise, or Education required."
	exit
}

$sandboxFeature = Get-WindowsOptionalFeature -Online -FeatureName 'WindowsSandbox'
if ($sandboxFeature.State -ne 'Enabled') {
	$response = Read-Host "Windows Sandbox is not enabled. Enable it now? A reboot will be required. (y/n)"
	if ($response -eq 'y') {
		Enable-WindowsOptionalFeature -Online -FeatureName 'WindowsSandbox' -All -NoRestart
		Write-Host "[OK] Windows Sandbox enabled. Please reboot and re-run this script."
	} else {
		Write-Host "Aborted. Enable Windows Sandbox manually and re-run."
	}
	exit
}

# Validate InputPath
if (!(Test-Path $InputPath)) {
	Write-Error "InputPath not found: $InputPath"
	exit
}

# Create SharePath if needed
New-Item -ItemType Directory -Force -Path $SharePath | Out-Null
Write-Host "[OK] Share folder ready: $SharePath"

# Copy framework files
foreach ($file in @('Invoke-SlideshowBuilder.ps1', 'sandbox.wsb')) {
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
