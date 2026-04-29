$wsbPath = "C:\MySandboxShare\sandbox.wsb"

if (!(Test-Path $wsbPath)) {
	Write-Error "sandbox.wsb not found"
	exit
}

Start-Process $wsbPath