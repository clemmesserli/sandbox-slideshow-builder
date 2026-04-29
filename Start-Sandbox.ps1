param(
	[Parameter(Mandatory)]
	[string]$SharePath
)

if (!(Test-Path $SharePath -PathType Container)) {
	Write-Error "SharePath not found: $SharePath"
	exit
}

$templatePath = Join-Path $PSScriptRoot "sandbox.wsb"
if (!(Test-Path $templatePath)) {
	Write-Error "sandbox.wsb template not found at: $templatePath"
	exit
}

$tmpWsb = Join-Path $env:TEMP "sandbox_run.wsb"
(Get-Content $templatePath -Raw) -replace 'C:\\path\\to\\your\\share', $SharePath | Set-Content $tmpWsb

Start-Process $tmpWsb
