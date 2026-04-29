# sandbox-slideshow-builder

A Windows Sandbox-based framework that transforms a set of source assets into a styled MP4 slideshow video. All processing runs inside an isolated Windows Sandbox — nothing is installed on your host machine.

## How It Works

```
source assets → ImageMagick (compose/overlay frames) → PNG frames → FFmpeg → MP4
```

1. `Start-Sandbox.ps1` launches a Windows Sandbox using `sandbox.wsb`
2. The sandbox mounts your local share folder as `C:\Shared`
3. `LetsPlay.ps1` runs automatically on sandbox login and:
   - Downloads and installs VC++ Runtime, 7-Zip, ImageMagick, and FFmpeg
   - Processes your source assets into PNG frames (parallelized)
   - Encodes all frames into an MP4 slideshow
4. The output MP4 is written back to your host share folder

## Requirements

- Windows 10/11 with [Windows Sandbox enabled](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-overview)
- PowerShell 5.1+
- Internet access (tools are downloaded on first run)

## Usage

### 1. Configure your host share path

Update the `HostFolder` path in `sandbox.wsb` and the `$wsbPath` in `Start-Sandbox.ps1` to match your local share directory:

```xml
<HostFolder>C:\YourShareFolder</HostFolder>
```

### 2. Add your source assets

Place your input files in the share folder. The default example reads from `quotes.txt` (one entry per line) and renders each as a styled PNG frame.

To adapt for images (e.g. sports photos), place your images in an `images\` subfolder and update the frame generation section of `LetsPlay.ps1` accordingly.

### 3. Run

```powershell
.\Start-Sandbox.ps1
```

The sandbox will launch, process your assets, and write the output MP4 to your share folder. Explorer will open automatically when complete.

## Output

| File | Description |
|---|---|
| `images\frame_NNN.png` | Generated PNG frames (build artifacts, gitignored) |
| `output.mp4` | Final encoded slideshow video (gitignored) |
| `sandbox_log.txt` | Full transcript log from the sandbox run (gitignored) |

## Customization

| Variable | Location | Description |
|---|---|---|
| `$width` / `$height` | `LetsPlay.ps1` | Output frame resolution (default: 1280x720) |
| `-framerate` | `LetsPlay.ps1` | Seconds per frame (default: `0.33` ≈ 3s per slide) |
| `-pointsize` | `LetsPlay.ps1` | Font size for text overlays |
| Background gradient | `LetsPlay.ps1` | ImageMagick gradient colors |

## Use Cases

- Text quote slideshows
- Sports image highlight reels
- Photo montages with overlays
- Any scenario requiring repeatable, isolated image-to-video rendering

## Tools Used

- [ImageMagick](https://imagemagick.org/) — frame composition and image processing
- [FFmpeg](https://ffmpeg.org/) — video encoding
- [Windows Sandbox](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-overview) — isolated execution environment
