$wsbPath = Join-Path $PSScriptRoot "sandbox.wsb"

if (!(Test-Path $wsbPath)) {
	Write-Error "sandbox.wsb not found at: $wsbPath"
	exit
}

Start-Process $wsbPath