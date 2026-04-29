# =============================
# Setup + Logging
# =============================
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"
$VerbosePreference = "Continue"

$shared = "C:\Shared"
$tools = "C:\Tools"
$imgDir = Join-Path $shared "images"

New-Item -ItemType Directory -Force -Path $tools  | Out-Null
New-Item -ItemType Directory -Force -Path $imgDir | Out-Null

$logFile = Join-Path $shared "sandbox_log.txt"

Start-Transcript -Path $logFile -Force

$scriptStart = Get-Date
Write-Host "=== SANDBOX SCRIPT START === $($scriptStart.ToString('yyyy-MM-dd HH:mm:ss'))"

function Write-Step {
	param([string]$Label, [scriptblock]$Action)
	Write-Host "[START] $Label"
	$elapsed = (Measure-Command { & $Action }).TotalSeconds
	Write-Host ("[DONE] $Label ({0:N1}s)" -f $elapsed)
}

# =============================
# Helper: Download with retry + skip
# =============================
function Deploy-File {
	param (
		[string]$Url,
		[string]$OutFile,
		[int]$Retries = 3
	)

	if (Test-Path $OutFile) {
		Write-Host "Skipping download (already exists): $OutFile"
		return
	}

	for ($i = 1; $i -le $Retries; $i++) {
		try {
			Write-Host "Downloading $Url (Attempt $i)..."
			$heartbeat = Start-Job { while ($true) { Start-Sleep -Seconds 10; Write-Host "  ...download in progress" } }
			Invoke-WebRequest $Url -OutFile $OutFile -UseBasicParsing
			Stop-Job $heartbeat; Remove-Job $heartbeat
			if (Test-Path $OutFile) {
				Write-Host "[OK] Download successful: $OutFile"
				return
			}
		} catch {
			if ($heartbeat) { Stop-Job $heartbeat; Remove-Job $heartbeat }
			Write-Host "Download failed: $_"
			Start-Sleep -Seconds 3
		}
	}

	throw "[FAIL] Failed to download after $Retries attempts: $Url"
}

# =============================
# Network init
# =============================
Write-Step 'Network init' { Start-Sleep -Seconds 5 }

# =============================
# Install VC++ Runtime
# =============================
$vcUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
$vcExe = "$tools\vc_redist.x64.exe"

Write-Step 'Download VC++' { Deploy-File $vcUrl $vcExe }

Write-Step 'Install VC++' {
	$vcInstalled = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" -ErrorAction SilentlyContinue
	if ($vcInstalled) {
		Write-Host "Skipping VC++ install (already installed)"
	} else {
		Write-Host "Installing VC++ runtime (this may take 30-60 seconds)..."
		$proc = Start-Process $vcExe -ArgumentList "/quiet", "/norestart" -PassThru
		while (-not $proc.HasExited) {
			Write-Host "  ...VC++ install in progress"
			Start-Sleep -Seconds 10
		}
		Write-Host "VC++ install exited with code: $($proc.ExitCode)"
	}
}

# =============================
# 7-Zip Setup (idempotent)
# =============================
$sevenZipExe = "$tools\7zr.exe"
Write-Step 'Download 7-Zip' { Deploy-File "https://www.7-zip.org/a/7zr.exe" $sevenZipExe }

if (!(Test-Path $sevenZipExe)) { throw "7zr.exe missing" }

# =============================
# ImageMagick (.7z)
# =============================
$imUrl = "https://github.com/ImageMagick/ImageMagick/releases/download/7.1.2-21/ImageMagick-7.1.2-21-portable-Q16-x64.7z"
$imArchive = "$tools\imagemagick.7z"
$imExtract = "$tools\imagemagick"

Write-Step 'Download ImageMagick' { Deploy-File $imUrl $imArchive }

Write-Step 'Extract ImageMagick' {
	if (!(Test-Path $imExtract)) {
		Write-Host "Extracting ImageMagick..."
		& $sevenZipExe x $imArchive "-o$imExtract" -y | Out-Null
	} else {
		Write-Host "Skipping ImageMagick extraction (already exists)"
	}
}

$magick = Get-ChildItem $imExtract -Recurse -Filter magick.exe | Select-Object -First 1
if (-not $magick) { throw "magick.exe not found" }

# =============================
# FFmpeg (.zip)
# =============================
$ffUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
$ffZip = "$tools\ffmpeg.zip"
$ffExtract = "$tools\ffmpeg"

Write-Step 'Download FFmpeg' { Deploy-File $ffUrl $ffZip }

Write-Step 'Extract FFmpeg' {
	if (!(Test-Path $ffExtract)) {
		Write-Host "Extracting FFmpeg..."
		Expand-Archive $ffZip -DestinationPath $ffExtract -Force
	} else {
		Write-Host "Skipping FFmpeg extraction (already exists)"
	}
}

$ffmpeg = Get-ChildItem $ffExtract -Recurse -Filter ffmpeg.exe | Select-Object -First 1
if (-not $ffmpeg) { throw "ffmpeg.exe not found" }

# =============================
# Load Input
# =============================
$inputFile = Join-Path $shared "input.txt"

if (!(Test-Path $inputFile)) { throw "input.txt not found" }

$quotes = Get-Content $inputFile | Where-Object { $_.Trim() -ne "" }

if ($quotes.Count -eq 0) { throw "input.txt is empty" }

Write-Host "Loaded $($quotes.Count) items"

# =============================
# Generate PNGs
# =============================
$width = 1280
$height = 720

$fontPath = "C:/Windows/Fonts/arial.ttf"
if (!(Test-Path $fontPath)) {
	$fontPath = (Get-ChildItem "C:\Windows\Fonts" -Filter *.ttf | Select-Object -First 1).FullName -replace '\\', '/'
}
if (!(Test-Path $fontPath)) { throw "No font found" }

$magickExe = $magick.FullName
$indexed = for ($n = 0; $n -lt $quotes.Count; $n++) { [PSCustomObject]@{ Index = $n + 1; Quote = $quotes[$n] } }

Write-Step 'Generate PNGs' {
	$jobs = @()

	foreach ($item in $indexed) {
		$outFile = Join-Path $imgDir ("frame_{0:D3}.png" -f $item.Index)

		if (Test-Path $outFile) {
			Write-Host "Skipping existing image: $outFile"
			continue
		}

		$jobs += Start-Job -ScriptBlock {
			param($magickExe, $fontPath, $width, $height, $quote, $outFile, $tools)

			$tmpTxt = Join-Path $tools "frame_$PID.txt"
			Set-Content -Path $tmpTxt -Value $quote -Encoding UTF8

			$magickArgs = @(
				'-size', "${width}x${height}",
				'gradient:#1a1a2e-#16213e',
				'-fill', '#c9a84c',
				'-draw', "line 80,$($height - 60) $($width - 80),$($height - 60)",
				'(',
				'-background', 'none',
				'-fill', 'white',
				'-font', $fontPath,
				'-pointsize', '42',
				'-size', "$($width - 160)x$($height - 160)",
				'-gravity', 'center',
				"caption:@$tmpTxt",
				')',
				'-gravity', 'center',
				'-composite',
				$outFile
			)
			& $magickExe @magickArgs 2>&1

			Remove-Item $tmpTxt -ErrorAction SilentlyContinue

			if (!(Test-Path $outFile)) { throw "Image creation failed: $outFile" }

		} -ArgumentList $magickExe, $fontPath, $width, $height, $item.Quote, $outFile, $tools
	}

	if ($jobs) {
		Write-Host "Waiting for $($jobs.Count) image job(s)..."
		$jobs | Wait-Job | ForEach-Object {
			$out = Receive-Job $_
			if ($_.State -eq 'Failed' -or $out -match 'ERROR|exception') {
				Write-Host "[FAIL] Job $($_.Id) failed: $out"
			} else {
				Write-Host "[OK] Job $($_.Id) completed"
			}
			Remove-Job $_
		}
	}
}

# =============================
# Generate Video (idempotent)
# =============================
$videoOut = Join-Path $shared "slideshow.mp4"

Write-Step 'Generate Video' {
	if (Test-Path $videoOut) {
		Write-Host "Skipping video creation (already exists)"
	} else {
		Write-Host "Generating video..."

		$ffmpegArgs = @(
			'-y',
			'-stream_loop', '0',
			'-framerate', '0.33',
			'-i', "$imgDir\frame_%03d.png",
			'-c:v', 'libx264',
			'-pix_fmt', 'yuv420p',
			'-r', '30',
			$videoOut
		)
		& $ffmpeg.FullName @ffmpegArgs

		if (!(Test-Path $videoOut)) { throw "Video creation failed" }

		Write-Host "[OK] Video created: $videoOut"
	}
}

# =============================
# Done
# =============================
$totalElapsed = [math]::Round(((Get-Date) - $scriptStart).TotalSeconds, 1)
Write-Host "=== COMPLETE === Total elapsed: ${totalElapsed}s"

Start-Process explorer.exe $shared

Stop-Transcript
