# Changelog

All notable changes to the "Za Screenshot" project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-12-17

### Added

- **Full HD (1080p) YouTube video capture support** using yt-dlp integration
  - Automatically selects highest available quality (up to 1080p)
  - Falls back to lower qualities (720p, 480p, 360p) if higher not available
- **Automated screenshot capture** at predefined timestamps
  - Default timestamps: 0:15, 1:45, 3:00
  - Configurable via `captureTimestamps` constant
- **High-resolution PNG export** using RepaintBoundary with 4x pixel ratio
  - Output resolution matches source video resolution
  - Files saved to user's Downloads folder
- **Dark-themed UI** with "spremni" branding
  - Purple accent color scheme (#6C5CE7)
  - Clean, minimal interface with status indicators
- **Real-time progress tracking** during capture process
  - Visual progress bar
  - Status messages for each operation
- **Comprehensive debug logging** for troubleshooting
  - Player state monitoring
  - Stream selection logging
  - Capture verification with file sizes

### Dependencies

- `media_kit: ^1.2.6` - Video playback engine
- `media_kit_video: ^2.0.1` - Video rendering widget
- `media_kit_libs_macos_video: ^1.1.4` - macOS native libraries
- `path_provider: ^2.1.5` - File system access

### Technical Details

- Uses yt-dlp CLI tool for reliable YouTube stream URL extraction
- Supports video-only streams (DASH) which provide higher quality than muxed streams
- RepaintBoundary capture with configurable `videoScaleFactor` (default: 4.0)
- Player seeks to timestamp, plays briefly to decode frame, then captures

### macOS Configuration

- Sandbox disabled for yt-dlp process execution
- Network client entitlement for YouTube API access
- File system access for Downloads folder

### Known Limitations

- Requires yt-dlp to be installed (`brew install yt-dlp`)
- macOS only (uses platform-specific entitlements)
- Maximum quality depends on YouTube video availability
- Sandbox must be disabled for external process execution

## [1.0.0] - 2025-12-17

### Added

- Initial Flutter project setup
- Basic project structure with macOS platform support
