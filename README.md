# sandbox-slideshow-builder

https://github.com/user-attachments/assets/4157b520-4221-474d-8fdf-907361dbd552

A Windows Sandbox-based framework that transforms a set of source assets into a styled MP4 slideshow video. All processing runs inside an isolated Windows Sandbox — nothing is installed on your host machine.

## How It Works

```
source assets → ImageMagick (compose/overlay frames) → PNG frames → FFmpeg → MP4
```

1. `Start-Sandbox.ps1` launches a Windows Sandbox using `sandbox.wsb`
2. The sandbox mounts your local share folder as `C:\Shared`
3. `Invoke-SlideshowBuilder.ps1` runs automatically on sandbox login and:
   - Downloads and installs VC++ Runtime, 7-Zip, ImageMagick, and FFmpeg
   - Processes your source assets into PNG frames (parallelized)
   - Encodes all frames into an MP4 slideshow
4. The output MP4 is written back to your host share folder

## Requirements

- Windows 10/11 **Pro, Enterprise, or Education** — Windows Sandbox is not available on Home editions
- [Windows Sandbox enabled](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-overview) — an optional Windows feature, not on by default. `Start-Sandbox.ps1` will detect if it's missing and offer to enable it (requires a reboot)
- Virtualization enabled in BIOS/UEFI
- PowerShell 5.1+
- Internet access (tools are downloaded on first run inside the sandbox)

## Usage

### 1. Run

For a text file (one entry per line):

```powershell
.\Start-Sandbox.ps1 -SharePath "C:\YourShareFolder" -InputPath "C:\Downloads\Quotes.txt"
```

For a folder of images *(future release — image pipeline not yet implemented)*:

```powershell
.\Start-Sandbox.ps1 -SharePath "C:\YourShareFolder" -InputPath "C:\Pics\Gallery01"
```

The script will:
- Create `-SharePath` if it doesn't exist
- Copy `Invoke-SlideshowBuilder.ps1` and `sandbox.wsb` into the share folder
- Copy a text file as `input.txt`, or copy image folder contents into `images\`
- Patch and launch the sandbox automatically

Explorer will open automatically when processing is complete.

> `sandbox.wsb` is used as a template — the `HostFolder` is patched at runtime using `-SharePath`. No manual edits to `sandbox.wsb` are needed.

## Output

| File | Description |
|---|---|
| `images\frame_NNN.png` | Generated PNG frames (build artifacts, gitignored) |
| `slideshow.mp4` | Final encoded slideshow video (gitignored) |
| `sandbox_log_YYYYMMDD_HHmmss.txt` | Full transcript log from the sandbox run — one file per run (gitignored) |

## Customization

| Variable | Location | Description |
|---|---|---|
| `$width` / `$height` | `Invoke-SlideshowBuilder.ps1` | Output frame resolution (default: 1280x720) |
| `-framerate` | `Invoke-SlideshowBuilder.ps1` | Seconds per frame (default: `0.33` ≈ 3s per slide) |
| `-pointsize` | `Invoke-SlideshowBuilder.ps1` | Font size for text overlays |
| Background gradient | `Invoke-SlideshowBuilder.ps1` | ImageMagick gradient colors |

## Use Cases

- Text quote slideshows
- Sports image highlight reels
- Photo montages with overlays
- Any scenario requiring repeatable, isolated image-to-video rendering

## Tools Used

- [ImageMagick](https://imagemagick.org/) — frame composition and image processing
- [FFmpeg](https://ffmpeg.org/) — video encoding
- [Windows Sandbox](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-overview) — isolated execution environment
