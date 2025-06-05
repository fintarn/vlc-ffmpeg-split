# vlc-ffmpeg-split
This repository contains two Lua-based VLC extensions that enable video and audio splitting using ffmpeg directly from VLC's interface.

Originally based on [mark_in_out.lua](https://github.com/easystreet/vlc-clip-extension), these scripts extend its functionality and add new workflows for media splitting and concatenation.

## 🎬 About the Extensions

### `VLC-ffmpeg-split.lua`
A streamlined version of the original script that:
- Automatically launches `ffmpeg` to split video/audio based on marked **In/Out** points.
- Adds a **Split at End** option to cut from a mark to the end of the media.
- Supports the `-copyts` flag via a checkbox.
- Retains the ability to preview the `ffmpeg` command before executing.

### `VLC-ffmpeg-multisplit.lua`
A more advanced script that:
- Allows marking **multiple In/Out pairs** (up to 10 segments).
- Extracts all marked segments using `ffmpeg`.
- Concatenates them into a single output file.
- Supports clip reordering and clearing.
- Includes cleanup of temporary files.
- Supports `-copyts` as an option.

## ✅ Features Summary

| Feature | `split` | `multisplit` |
|--------|--------|--------------|
| Mark In/Out | ✅ | ✅ (10 segments) |
| Run ffmpeg | ✅ | ✅ |
| Show ffmpeg command | ✅ | ✅ |
| Split at End of Media | ✅ | ❌ |
| Audio file support | ✅ | ✅ |
| -copyts support | ✅ | ✅ |
| Clip reordering | N/A | ✅ |
| Temp file cleanup | N/A | ✅ |
| Output concatenation | N/A | ✅ |

## 💾 Installation

1. Locate your VLC extensions folder:
   - **Windows**: `%APPDATA%\vlc\lua\extensions\`
   - **Linux**: `~/.local/share/vlc/lua/extensions/`
   - **macOS**: `~/Library/Application Support/org.videolan.vlc/lua/extensions/`

2. Copy the `.lua` files (`VLC-ffmpeg-split.lua`, `VLC-ffmpeg-multisplit.lua`) into that folder.

3. Restart VLC. Go to:
   - `View > Split: Mark In/Out and Create Clip`
   - `View > Split and concat multiple clips with ffmpeg`

## ▶️ Usage Instructions

### VLC-ffmpeg-split.lua
1. Open a media file in VLC.
2. Open the extension under **View > Split: Mark In/Out and Create Clip**.
3. Set your **Mark In** and **Mark Out** points.
4. Click **Split** to run `ffmpeg` and create the clip.
5. Optionally use **Split at End** or **Show ffmpeg cmd**.

### VLC-ffmpeg-multisplit.lua
1. Open a media file in VLC.
2. Open the extension under **View > Split: Mark In/Out (Multiple) and Create Clip**.
3. Mark multiple **In/Out** points (up to 10).
4. Reorder segments using ↑ / ↓, or clear as needed.
5. Once happy, click **Create Clip** to extract and join the segments.
6. Use **Clean Temp Files** after completion to remove intermediates, or simply remove them manually.

## 🛠 Requirements

- **VLC Media Player** 3.0.0 or higher.
- **ffmpeg** 4.0 or higher.
- (tested with ffmpeg 7.1.1 and VLC 3.0.2)

Ensure `ffmpeg` is accessible via your system's `PATH`.

## 📄 License

This project is licensed under the [**MIT License**](https://github.com/fintarn/vlc-ffmpeg-split/edit/main/LICENSE.md).

### Attribution

This project is based on [vlc-clip-extension](https://github.com/easystreet/vlc-clip-extension) by [easystreet](https://github.com/easystreet), originally released under the MIT License.

Additional modifications and extensions by [fintarn](https://github.com/fintarn).

## 🙋 Support

This is a personal utility project. Feel free to open issues for bugs. Support may be provided on a best-effort basis.
