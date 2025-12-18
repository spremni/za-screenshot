# Za Screenshot

A macOS desktop app for capturing high-resolution screenshots from YouTube videos at specific timestamps.

## Features

- **HD Screenshot Capture** - Captures frames at up to 1920x1080 resolution
- **JSON Manifest Support** - Define timestamps, filenames, and metadata in a config file
- **Batch Processing** - Capture multiple screenshots in one session
- **Interactive Queue** - Click any thumbnail to seek to that timestamp
- **Pause/Resume** - Pause capturing anytime and resume where you left off
- **Local Video Mode** - Download video to disk for instant seeking (optional)
- **Stream Mode** - Quick preview without downloading (default)

## Requirements

- macOS
- [Flutter](https://flutter.dev) 3.10+
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) (`brew install yt-dlp`)
- [ffprobe](https://ffmpeg.org/) (`brew install ffmpeg`) - for local video mode

## Installation

```bash
cd app
flutter pub get
flutter run -d macos
```

## Usage

1. Create a JSON manifest file with your screenshot definitions:

```json
{
  "metadata": {
    "video_url": "https://www.youtube.com/watch?v=VIDEO_ID",
    "video_title": "Video Title",
    "output_directory": "screenshots"
  },
  "screenshots": [
    {
      "id": 1,
      "filename": "screenshot_001.png",
      "timestamp": "00:01:30",
      "timestamp_seconds": 90
    }
  ]
}
```

2. Launch the app and load your JSON config
3. (Optional) Enable "Local mode" for faster seeking
4. Click "Capture All Screenshots" or click individual thumbnails to preview

## Output

Screenshots are saved to `~/Downloads/{video_title}_{timestamp}/` as PNG files at the source video resolution.

## License

MIT License - see [LICENSE](LICENSE)
