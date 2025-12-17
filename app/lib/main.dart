import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as media_kit;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const ZaScreenshotApp());
}

// ============================================================================
// JSON Models
// ============================================================================

class ScreenshotManifest {
  final ManifestMetadata metadata;
  final Map<String, Speaker> speakers;
  final List<ScreenshotConfig> screenshots;
  final List<PriorityScreenshot> priorityScreenshots;
  final List<Chapter> chapters;

  ScreenshotManifest({
    required this.metadata,
    required this.speakers,
    required this.screenshots,
    required this.priorityScreenshots,
    required this.chapters,
  });

  factory ScreenshotManifest.fromJson(Map<String, dynamic> json) {
    return ScreenshotManifest(
      metadata: ManifestMetadata.fromJson(json['metadata']),
      speakers: (json['speakers'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, Speaker.fromJson(value)),
          ) ??
          {},
      screenshots: (json['screenshots'] as List?)
              ?.map((e) => ScreenshotConfig.fromJson(e))
              .toList() ??
          [],
      priorityScreenshots: (json['priority_screenshots'] as List?)
              ?.map((e) => PriorityScreenshot.fromJson(e))
              .toList() ??
          [],
      chapters: (json['chapters'] as List?)
              ?.map((e) => Chapter.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class ManifestMetadata {
  final String videoUrl;
  final String videoId;
  final String videoTitle;
  final String? source;
  final String? series;
  final int totalScreenshots;
  final String? generatedAt;
  final String language;
  final String outputDirectory;
  final String filenameFormat;

  ManifestMetadata({
    required this.videoUrl,
    required this.videoId,
    required this.videoTitle,
    this.source,
    this.series,
    required this.totalScreenshots,
    this.generatedAt,
    required this.language,
    required this.outputDirectory,
    required this.filenameFormat,
  });

  factory ManifestMetadata.fromJson(Map<String, dynamic> json) {
    return ManifestMetadata(
      videoUrl: json['video_url'] ?? '',
      videoId: json['video_id'] ?? '',
      videoTitle: json['video_title'] ?? '',
      source: json['source'],
      series: json['series'],
      totalScreenshots: json['total_screenshots'] ?? 0,
      generatedAt: json['generated_at'],
      language: json['language'] ?? 'hr',
      outputDirectory: json['output_directory'] ?? 'screenshots',
      filenameFormat: json['filename_format'] ?? '{index:02d}_{timestamp_clean}_{slug}.png',
    );
  }

  String get sanitizedTitle {
    return videoTitle
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
  }
}

class Speaker {
  final String fullName;
  final String? role;
  final String? colorCode;
  final String slug;

  Speaker({
    required this.fullName,
    this.role,
    this.colorCode,
    required this.slug,
  });

  factory Speaker.fromJson(Map<String, dynamic> json) {
    return Speaker(
      fullName: json['full_name'] ?? '',
      role: json['role'],
      colorCode: json['color_code'],
      slug: json['slug'] ?? '',
    );
  }

  Color get color {
    if (colorCode == null) return Colors.grey;
    try {
      return Color(int.parse(colorCode!.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }
}

enum ScreenshotStatus { pending, inProgress, completed, failed }

class ScreenshotConfig {
  final int id;
  final String filename;
  final String timestamp;
  final int timestampSeconds;
  final String? speakerId;
  final String? chapter;
  final String? sceneDescription;
  final String captionHr;
  final String? captionEn;
  final String? slug;
  final bool isPriority;
  final int? priorityRank;
  final List<String> tags;

  // Runtime state
  ScreenshotStatus status = ScreenshotStatus.pending;
  Uint8List? thumbnailBytes;

  ScreenshotConfig({
    required this.id,
    required this.filename,
    required this.timestamp,
    required this.timestampSeconds,
    this.speakerId,
    this.chapter,
    this.sceneDescription,
    required this.captionHr,
    this.captionEn,
    this.slug,
    this.isPriority = false,
    this.priorityRank,
    this.tags = const [],
  });

  factory ScreenshotConfig.fromJson(Map<String, dynamic> json) {
    return ScreenshotConfig(
      id: json['id'] ?? 0,
      filename: json['filename'] ?? '',
      timestamp: json['timestamp'] ?? '00:00:00',
      timestampSeconds: json['timestamp_seconds'] ?? 0,
      speakerId: json['speaker_id'],
      chapter: json['chapter'],
      sceneDescription: json['scene_description'],
      captionHr: json['caption_hr'] ?? '',
      captionEn: json['caption_en'],
      slug: json['slug'],
      isPriority: json['is_priority'] ?? false,
      priorityRank: json['priority_rank'],
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
    );
  }

  Duration get duration => Duration(seconds: timestampSeconds);
}

class PriorityScreenshot {
  final int rank;
  final int id;
  final String timestamp;
  final String filename;
  final String description;

  PriorityScreenshot({
    required this.rank,
    required this.id,
    required this.timestamp,
    required this.filename,
    required this.description,
  });

  factory PriorityScreenshot.fromJson(Map<String, dynamic> json) {
    return PriorityScreenshot(
      rank: json['rank'] ?? 0,
      id: json['id'] ?? 0,
      timestamp: json['timestamp'] ?? '',
      filename: json['filename'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class Chapter {
  final int id;
  final String title;
  final String startTimestamp;
  final String? endTimestamp;
  final String? description;

  Chapter({
    required this.id,
    required this.title,
    required this.startTimestamp,
    this.endTimestamp,
    this.description,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      startTimestamp: json['start_timestamp'] ?? '00:00:00',
      endTimestamp: json['end_timestamp'],
      description: json['description'],
    );
  }
}

// ============================================================================
// App
// ============================================================================

class ZaScreenshotApp extends StatelessWidget {
  const ZaScreenshotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Za Screenshot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF6C5CE7),
          secondary: const Color(0xFFA29BFE),
          surface: const Color(0xFF1E1E2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D14),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E2E),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C5CE7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const ZaScreenshotHome(),
    );
  }
}

class ZaScreenshotHome extends StatefulWidget {
  const ZaScreenshotHome({super.key});

  @override
  State<ZaScreenshotHome> createState() => _ZaScreenshotHomeState();
}

class _ZaScreenshotHomeState extends State<ZaScreenshotHome> {
  Player? _player;
  media_kit.VideoController? _videoController;
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final ScrollController _queueScrollController = ScrollController();

  // State
  ScreenshotManifest? _manifest;
  String? _configPath;
  String? _outputDirectory;
  bool _isLoading = false;
  bool _isCapturing = false;
  bool _capturePaused = false;
  int _pausedAtIndex = -1;
  String _statusMessage = 'Select a JSON config file to start';
  int _sourceWidth = 0;
  int _sourceHeight = 0;
  int _currentIndex = -1;

  // Video download mode
  bool _useLocalVideo = false;
  String? _localVideoPath;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void dispose() {
    _player?.dispose();
    _queueScrollController.dispose();
    super.dispose();
  }

  // Handle tap on queue item - seek to timestamp and pause capturing
  Future<void> _onQueueItemTap(ScreenshotConfig config, int index) async {
    if (_player == null) return;

    // If capturing is in progress, pause it
    if (_isCapturing && !_capturePaused) {
      setState(() {
        _capturePaused = true;
        _pausedAtIndex = _currentIndex;
        _statusMessage = 'Paused at screenshot ${_pausedAtIndex + 1}. Click Continue to resume.';
      });
    }

    // Seek to the timestamp
    print('[MANUAL] Seeking to ${config.timestamp} (${config.timestampSeconds}s)');
    await _player!.pause();
    await _player!.seek(config.duration);
    await Future.delayed(const Duration(milliseconds: 300));

    // Play briefly to decode the frame
    await _player!.play();
    await Future.delayed(const Duration(milliseconds: 500));
    await _player!.pause();

    setState(() {
      _currentIndex = index;
      if (!_isCapturing) {
        _statusMessage = 'Viewing: ${config.timestamp} - ${config.captionHr}';
      }
    });
  }

  // Continue capturing from where it was paused
  Future<void> _continueCapturing() async {
    if (!_capturePaused || _pausedAtIndex < 0) return;

    setState(() {
      _capturePaused = false;
      _statusMessage = 'Resuming capture...';
    });

    // Resume from pausedAtIndex
    await _captureScreenshotsFromIndex(_pausedAtIndex);
  }

  Future<void> _pickConfigFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select Screenshot Manifest JSON',
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        await _loadConfig(path);
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error picking file: $e';
      });
    }
  }

  Future<void> _loadConfig(String path) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading config...';
      _configPath = path;
      _localVideoPath = null; // Reset cached video path for new config
    });

    try {
      final file = File(path);
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final manifest = ScreenshotManifest.fromJson(json);

      // Reset all screenshot statuses
      for (final screenshot in manifest.screenshots) {
        screenshot.status = ScreenshotStatus.pending;
        screenshot.thumbnailBytes = null;
      }

      setState(() {
        _manifest = manifest;
        _statusMessage = 'Config loaded: ${manifest.metadata.videoTitle}';
      });

      print('[CONFIG] Loaded manifest:');
      print('  Video: ${manifest.metadata.videoTitle}');
      print('  URL: ${manifest.metadata.videoUrl}');
      print('  Screenshots: ${manifest.screenshots.length}');

      await _initializeVideo();
    } catch (e, stackTrace) {
      print('[ERROR] Failed to load config: $e');
      print(stackTrace);
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error loading config: $e';
      });
    }
  }

  Future<void> _downloadVideo() async {
    if (_manifest == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Downloading video to disk...';
    });

    try {
      final home = Platform.environment['HOME'];
      final cacheDir = '$home/.cache/za_screenshot';
      await Directory(cacheDir).create(recursive: true);

      // Use video ID as filename
      final videoUrl = _manifest!.metadata.videoUrl;
      final videoId = Uri.parse(videoUrl).queryParameters['v'] ?? 'video';
      final outputPath = '$cacheDir/$videoId.mp4';

      // Check if already downloaded
      final existingFile = File(outputPath);
      if (await existingFile.exists()) {
        final fileSize = await existingFile.length();
        if (fileSize > 1024 * 1024) {
          // > 1MB, assume valid
          print('[DOWNLOAD] Using cached video: $outputPath');
          _localVideoPath = outputPath;
          setState(() {
            _isDownloading = false;
            _downloadProgress = 1.0;
          });
          return;
        }
      }

      print('[DOWNLOAD] Downloading video to: $outputPath');

      // Download with yt-dlp with progress
      final process = await Process.start(
        'yt-dlp',
        [
          '-f', 'bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[height<=1080]',
          '--merge-output-format', 'mp4',
          '--newline',
          '--progress',
          '-o', outputPath,
          videoUrl,
        ],
      );

      // Parse progress from yt-dlp output
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        print('[DOWNLOAD] $line');
        // Parse progress like "[download]  45.2% of 123.45MiB"
        final progressMatch = RegExp(r'\[download\]\s+(\d+\.?\d*)%').firstMatch(line);
        if (progressMatch != null) {
          final percent = double.tryParse(progressMatch.group(1) ?? '0') ?? 0;
          setState(() {
            _downloadProgress = percent / 100;
            _statusMessage = 'Downloading video... ${percent.toStringAsFixed(1)}%';
          });
        }
      });

      process.stderr.transform(utf8.decoder).listen((line) {
        print('[DOWNLOAD ERROR] $line');
      });

      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        throw Exception('yt-dlp download failed with exit code $exitCode');
      }

      _localVideoPath = outputPath;
      print('[DOWNLOAD] Complete: $outputPath');

      setState(() {
        _isDownloading = false;
        _downloadProgress = 1.0;
        _statusMessage = 'Download complete!';
      });
    } catch (e, stackTrace) {
      print('[ERROR] Download failed: $e');
      print(stackTrace);
      setState(() {
        _isDownloading = false;
        _statusMessage = 'Download failed: $e';
      });
      rethrow;
    }
  }

  Future<void> _initializeVideo() async {
    if (_manifest == null) return;

    try {
      String mediaSource;

      if (_useLocalVideo) {
        // Download video first if not already cached
        if (_localVideoPath == null) {
          await _downloadVideo();
        }

        if (_localVideoPath == null) {
          throw Exception('Failed to download video');
        }

        mediaSource = _localVideoPath!;
        // Get resolution from file using ffprobe
        final probeResult = await Process.run('ffprobe', [
          '-v', 'error',
          '-select_streams', 'v:0',
          '-show_entries', 'stream=width,height',
          '-of', 'csv=p=0',
          mediaSource,
        ]);

        if (probeResult.exitCode == 0) {
          final parts = (probeResult.stdout as String).trim().split(',');
          if (parts.length >= 2) {
            _sourceWidth = int.tryParse(parts[0]) ?? 1920;
            _sourceHeight = int.tryParse(parts[1]) ?? 1080;
          }
        } else {
          _sourceWidth = 1920;
          _sourceHeight = 1080;
        }

        print('[DEBUG] Using local video: $mediaSource (${_sourceWidth}x$_sourceHeight)');
      } else {
        // Stream mode - fetch URL
        setState(() {
          _statusMessage = 'Fetching video stream...';
        });

        print('[DEBUG] Using yt-dlp to fetch stream URL...');

        String? streamUrl;
        int selectedFormat = 0;

        for (final format in [137, 136, 135, 134, 18]) {
          print('[DEBUG] Trying format $format...');
          final result = await Process.run(
            'yt-dlp',
            ['-f', '$format', '-g', _manifest!.metadata.videoUrl],
          );

          if (result.exitCode == 0 && (result.stdout as String).trim().isNotEmpty) {
            streamUrl = (result.stdout as String).trim();
            selectedFormat = format;
            print('[DEBUG] Got URL for format $format');
            break;
          }
        }

        if (streamUrl == null) {
          throw Exception('Could not get stream URL from yt-dlp');
        }

        switch (selectedFormat) {
          case 137:
            _sourceWidth = 1920;
            _sourceHeight = 1080;
            break;
          case 136:
            _sourceWidth = 1280;
            _sourceHeight = 720;
            break;
          case 135:
            _sourceWidth = 854;
            _sourceHeight = 480;
            break;
          default:
            _sourceWidth = 640;
            _sourceHeight = 360;
        }

        print('[DEBUG] Selected format: $selectedFormat (${_sourceWidth}x$_sourceHeight)');
        mediaSource = streamUrl;
      }

      setState(() {
        _statusMessage = 'Loading video (${_sourceWidth}x$_sourceHeight)...';
      });

      _player = Player(
        configuration: PlayerConfiguration(logLevel: MPVLogLevel.warn),
      );
      _videoController = media_kit.VideoController(_player!);

      await _player!.open(Media(mediaSource));
      await _player!.stream.playing.firstWhere((p) => p).timeout(
            const Duration(seconds: 30),
            onTimeout: () => false,
          );
      await _player!.pause();

      int waitCount = 0;
      while (_player!.state.width == null && waitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }

      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _isLoading = false;
        _statusMessage = _useLocalVideo
            ? 'Ready (local video) - ${_manifest!.screenshots.length} screenshots'
            : 'Ready to capture ${_manifest!.screenshots.length} screenshots';
      });
    } catch (e, stackTrace) {
      print('[ERROR] Failed to initialize video: $e');
      print(stackTrace);
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<String> _createOutputDirectory() async {
    final home = Platform.environment['HOME'];
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedTitle = _manifest!.metadata.sanitizedTitle;
    final dirName = '${sanitizedTitle}_$timestamp';
    final path = '$home/Downloads/$dirName';

    final dir = Directory(path);
    await dir.create(recursive: true);

    print('[OUTPUT] Created directory: $path');
    return path;
  }

  Future<void> _captureScreenshots() async {
    if (_manifest == null || _player == null || _isCapturing) return;

    // Reset pause state
    setState(() {
      _capturePaused = false;
      _pausedAtIndex = -1;
    });

    // Create output directory for new capture session
    _outputDirectory = await _createOutputDirectory();
    print('[CAPTURE] Output directory: $_outputDirectory');

    await _captureScreenshotsFromIndex(0);
  }

  Future<void> _captureScreenshotsFromIndex(int startIndex) async {
    if (_manifest == null || _player == null) return;

    setState(() {
      _isCapturing = true;
      _currentIndex = startIndex;
      _statusMessage = 'Starting capture...';
    });

    try {
      final screenshots = _manifest!.screenshots;
      final total = screenshots.length;

      for (int i = startIndex; i < total; i++) {
        // Check if paused
        if (_capturePaused) {
          print('[CAPTURE] Paused by user at index $i');
          return;
        }

        final config = screenshots[i];

        setState(() {
          config.status = ScreenshotStatus.inProgress;
          _currentIndex = i;
          _statusMessage = 'Capturing ${i + 1}/$total: ${config.timestamp}';
        });

        // Scroll to current item
        _scrollToCurrentItem(i);

        print('[CAPTURE] === Screenshot ${i + 1}/$total ===');
        print('  Timestamp: ${config.timestamp} (${config.timestampSeconds}s)');
        print('  Filename: ${config.filename}');

        try {
          // IMPROVED SEEKING LOGIC v2 - ensures frame texture is actually updated
          final targetPosition = config.duration;
          final targetMs = targetPosition.inMilliseconds;

          // 1. Pause first, then seek
          print('[SEEK] Pausing and seeking to ${config.timestampSeconds}s...');
          await _player!.pause();
          await Future.delayed(const Duration(milliseconds: 200));
          await _player!.seek(targetPosition);
          await Future.delayed(const Duration(milliseconds: 500));

          // 2. Start playback to force frame decode
          print('[PLAY] Starting playback to decode frames...');
          await _player!.play();

          // 3. Wait for position to reach and PASS target (ensures frame was rendered)
          print('[SEEK] Waiting for position to reach target...');
          int seekAttempts = 0;
          const maxSeekAttempts = 150; // 15 seconds max
          Duration? lastPosition;
          int samePositionCount = 0;
          bool targetReached = false;

          while (seekAttempts < maxSeekAttempts) {
            final currentPos = _player!.state.position;
            final currentMs = currentPos.inMilliseconds;

            // Track if position is changing (indicates frames are rendering)
            if (lastPosition != null && currentPos == lastPosition) {
              samePositionCount++;
            } else {
              samePositionCount = 0;
            }
            lastPosition = currentPos;

            // Accept when:
            // 1. Position is at or past target (within 500ms window past target is OK)
            // 2. OR position has reached target and playback has advanced past it
            if (currentMs >= targetMs && currentMs < targetMs + 3000) {
              if (!targetReached) {
                print('[SEEK] Position reached target: $currentPos');
                targetReached = true;
              }
              // Wait a bit longer to ensure the frame at this position is rendered
              // (let video play for 1-2 more seconds so texture definitely updates)
              if (currentMs > targetMs + 500) {
                print('[SEEK] Position advanced past target: $currentPos');
                break;
              }
            }

            // If stuck at same position for too long, something is wrong
            if (samePositionCount > 20) {
              print('[SEEK] WARNING: Position stuck at $currentPos, breaking out');
              break;
            }

            await Future.delayed(const Duration(milliseconds: 100));
            seekAttempts++;
          }

          // 4. Wait for buffering to complete
          print('[BUFFER] Waiting for buffer...');
          int bufferWait = 0;
          while (_player!.state.buffering && bufferWait < 50) {
            await Future.delayed(const Duration(milliseconds: 100));
            bufferWait++;
          }
          print('[BUFFER] Buffer wait: ${bufferWait * 100}ms');

          // 5. If position was stuck, force a different approach
          if (samePositionCount >= 20) {
            print('[RETRY] Position was stuck, trying seek to before target...');
            // Seek to 3 seconds before target and play forward
            final beforeTarget = Duration(milliseconds: targetMs - 3000);
            await _player!.seek(beforeTarget > Duration.zero ? beforeTarget : Duration.zero);
            await Future.delayed(const Duration(milliseconds: 500));
            await _player!.play();

            // Wait until we pass target
            int retryAttempts = 0;
            while (retryAttempts < 100) {
              final pos = _player!.state.position.inMilliseconds;
              if (pos >= targetMs) {
                print('[RETRY] Position now at: ${_player!.state.position}');
                break;
              }
              await Future.delayed(const Duration(milliseconds: 100));
              retryAttempts++;
            }
          }

          // 6. Pause for clean capture (don't seek back, just capture current frame)
          await _player!.pause();

          // 7. Wait for Flutter to complete pending frames
          await Future.delayed(const Duration(milliseconds: 500));

          // Force a setState to trigger repaint
          setState(() {});
          await Future.delayed(const Duration(milliseconds: 200));

          // 8. Verify position
          print('[VERIFY] Final position: ${_player!.state.position}');

          // 10. Capture frame
          final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

          if (boundary == null) {
            throw Exception('RepaintBoundary not found');
          }

          final boundarySize = boundary.size;
          final pixelRatio = _sourceWidth / boundarySize.width;

          final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

          if (byteData == null) {
            throw Exception('Could not convert image to bytes');
          }

          // Save file
          final filePath = '$_outputDirectory/${config.filename}';
          final file = File(filePath);
          await file.writeAsBytes(byteData.buffer.asUint8List());

          // Generate thumbnail for queue display
          final thumbnailImage = await boundary.toImage(pixelRatio: 0.5);
          final thumbnailData = await thumbnailImage.toByteData(format: ui.ImageByteFormat.png);

          setState(() {
            config.status = ScreenshotStatus.completed;
            if (thumbnailData != null) {
              config.thumbnailBytes = thumbnailData.buffer.asUint8List();
            }
          });

          print('[SAVED] $filePath (${image.width}x${image.height})');

          image.dispose();
          thumbnailImage.dispose();

        } catch (e) {
          print('[ERROR] Failed to capture screenshot ${i + 1}: $e');
          setState(() {
            config.status = ScreenshotStatus.failed;
          });
        }

        // Small delay between captures
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Only show completion if not paused
      if (!_capturePaused) {
        final completed = screenshots.where((s) => s.status == ScreenshotStatus.completed).length;
        final failed = screenshots.where((s) => s.status == ScreenshotStatus.failed).length;

        setState(() {
          _isCapturing = false;
          _currentIndex = -1;
          _pausedAtIndex = -1;
          _statusMessage = 'Capture complete! $completed saved, $failed failed.';
        });

        print('\n=== Capture Summary ===');
        print('Total: $completed completed, $failed failed');
        print('Output: $_outputDirectory');
      }

    } catch (e, stackTrace) {
      print('[ERROR] Capture failed: $e');
      print(stackTrace);
      setState(() {
        _isCapturing = false;
        _capturePaused = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  void _scrollToCurrentItem(int index) {
    if (!_queueScrollController.hasClients) return;

    const itemHeight = 80.0;
    final targetOffset = index * itemHeight;
    final maxOffset = _queueScrollController.position.maxScrollExtent;
    final viewportHeight = _queueScrollController.position.viewportDimension;

    // Center the item if possible
    final centeredOffset = targetOffset - (viewportHeight / 2) + (itemHeight / 2);
    final clampedOffset = centeredOffset.clamp(0.0, maxOffset);

    _queueScrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayWidth = _sourceWidth > 0 ? _sourceWidth / 4.0 : 480.0;
    final displayHeight = _sourceHeight > 0 ? _sourceHeight / 4.0 : 270.0;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.screenshot_monitor, size: 28),
            SizedBox(width: 12),
            Text('Za Screenshot', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          if (_manifest != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_manifest!.screenshots.length} screenshots',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'spremni',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _manifest == null ? _buildConfigPicker() : _buildMainContent(displayWidth, displayHeight),
    );
  }

  Widget _buildConfigPicker() {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.upload_file, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 16),
              const Text(
                'Select Screenshot Manifest',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a JSON file that defines screenshots to capture',
                style: TextStyle(color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickConfigFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Select JSON File'),
              ),
              if (_isLoading) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(double displayWidth, double displayHeight) {
    return Row(
      children: [
        // Left side - Video and controls
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Metadata Card
                _buildMetadataCard(),

                const SizedBox(height: 16),

                // Video Player
                if (_videoController != null)
                  Card(
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: RepaintBoundary(
                              key: _repaintBoundaryKey,
                              child: SizedBox(
                                width: displayWidth,
                                height: displayHeight,
                                child: media_kit.Video(
                                  controller: _videoController!,
                                  controls: media_kit.NoVideoControls,
                                ),
                              ),
                            ),
                          ),
                          if (_currentIndex >= 0 && _currentIndex < _manifest!.screenshots.length)
                            _buildCurrentCaptionCard(_manifest!.screenshots[_currentIndex]),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Status & Controls
                _buildStatusCard(),

                const SizedBox(height: 16),

                // Action Buttons
                _buildActionButtons(),
              ],
            ),
          ),
        ),

        // Right side - Screenshot Queue
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: const Color(0xFF151520),
            border: Border(
              left: BorderSide(color: Colors.grey[800]!, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Queue Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[800]!, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.queue, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Screenshot Queue',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    _buildQueueStats(),
                  ],
                ),
              ),

              // Queue List
              Expanded(
                child: ListView.builder(
                  controller: _queueScrollController,
                  itemCount: _manifest!.screenshots.length,
                  itemBuilder: (context, index) {
                    return _buildQueueItem(_manifest!.screenshots[index], index);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.movie, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _manifest!.metadata.videoTitle,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _isCapturing
                      ? null
                      : () {
                          setState(() {
                            _manifest = null;
                            _configPath = null;
                            _outputDirectory = null;
                            _player?.dispose();
                            _player = null;
                            _videoController = null;
                            _statusMessage = 'Select a JSON config file to start';
                          });
                        },
                ),
              ],
            ),
            if (_manifest!.metadata.source != null) ...[
              const SizedBox(height: 4),
              Text(
                _manifest!.metadata.source!,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildInfoChip(Icons.photo_library, '${_manifest!.screenshots.length} shots'),
                _buildInfoChip(Icons.star, '${_manifest!.priorityScreenshots.length} priority'),
                _buildInfoChip(Icons.people, '${_manifest!.speakers.length} speakers'),
                if (_sourceWidth > 0)
                  _buildInfoChip(Icons.high_quality, '${_sourceWidth}x$_sourceHeight'),
              ],
            ),
            if (_outputDirectory != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder, size: 16, color: Colors.green[400]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _outputDirectory!.split('/').last,
                        style: TextStyle(fontSize: 11, color: Colors.green[400], fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentCaptionCard(ScreenshotConfig config) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getSpeakerColor(config.speakerId),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  config.timestamp,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              if (config.speakerId != null)
                Text(
                  _getSpeakerName(config.speakerId!),
                  style: TextStyle(
                    color: _getSpeakerColor(config.speakerId),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(config.captionHr, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Download mode toggle
            Row(
              children: [
                Icon(
                  _useLocalVideo ? Icons.folder : Icons.cloud,
                  size: 20,
                  color: _useLocalVideo ? Colors.green[400] : Colors.blue[400],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _useLocalVideo ? 'Local mode (faster seeking)' : 'Stream mode',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
                Switch(
                  value: _useLocalVideo,
                  onChanged: (_isLoading || _isCapturing || _isDownloading)
                      ? null
                      : (value) {
                          setState(() {
                            _useLocalVideo = value;
                            _localVideoPath = null; // Reset cache reference
                          });
                        },
                  activeColor: const Color(0xFF6C5CE7),
                ),
              ],
            ),

            // Download progress bar
            if (_isDownloading) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _downloadProgress,
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
                  minHeight: 6,
                ),
              ),
            ],

            const Divider(height: 24),

            // Status message
            Row(
              children: [
                if (_isLoading || _isCapturing || _isDownloading)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Main capture button or Continue button when paused
        if (_capturePaused)
          ElevatedButton.icon(
            onPressed: _continueCapturing,
            icon: const Icon(Icons.play_arrow),
            label: Text('Continue from #${_pausedAtIndex + 1}'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              backgroundColor: Colors.green[700],
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: (_isLoading || _isCapturing || _player == null)
                ? null
                : _captureScreenshots,
            icon: Icon(_isCapturing ? Icons.hourglass_top : Icons.camera_alt),
            label: Text(_isCapturing ? 'Capturing...' : 'Capture All Screenshots'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            ),
          ),
        const SizedBox(width: 16),
        // Cancel button when paused
        if (_capturePaused)
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _isCapturing = false;
                _capturePaused = false;
                _pausedAtIndex = -1;
                _statusMessage = 'Capture cancelled.';
              });
            },
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[400],
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: _isLoading || _isCapturing ? null : _pickConfigFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('Load Different Config'),
          ),
      ],
    );
  }

  Widget _buildQueueStats() {
    if (_manifest == null) return const SizedBox();

    final pending = _manifest!.screenshots.where((s) => s.status == ScreenshotStatus.pending).length;
    final inProgress = _manifest!.screenshots.where((s) => s.status == ScreenshotStatus.inProgress).length;
    final completed = _manifest!.screenshots.where((s) => s.status == ScreenshotStatus.completed).length;
    final failed = _manifest!.screenshots.where((s) => s.status == ScreenshotStatus.failed).length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pending > 0) _buildStatBadge(pending, Colors.grey),
        if (inProgress > 0) _buildStatBadge(inProgress, Colors.orange),
        if (completed > 0) _buildStatBadge(completed, Colors.green),
        if (failed > 0) _buildStatBadge(failed, Colors.red),
      ],
    );
  }

  Widget _buildStatBadge(int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildQueueItem(ScreenshotConfig config, int index) {
    final isActive = _currentIndex == index;

    Color statusColor;
    IconData statusIcon;
    switch (config.status) {
      case ScreenshotStatus.pending:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
        break;
      case ScreenshotStatus.inProgress:
        statusColor = Colors.orange;
        statusIcon = Icons.play_circle;
        break;
      case ScreenshotStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case ScreenshotStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
    }

    return GestureDetector(
      onTap: () => _onQueueItemTap(config, index),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 80,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2D2D44) : const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(color: const Color(0xFF6C5CE7), width: 2)
                : Border.all(color: Colors.grey[800]!, width: 1),
          ),
          child: Row(
            children: [
              // Thumbnail or placeholder
              Container(
                width: 100,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(7),
                    bottomLeft: Radius.circular(7),
                  ),
                ),
                child: config.thumbnailBytes != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(7),
                          bottomLeft: Radius.circular(7),
                        ),
                        child: Image.memory(
                          config.thumbnailBytes!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: statusColor, size: 24),
                            const SizedBox(height: 4),
                            Text(
                              config.timestamp,
                              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
              ),

              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '#${config.id}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            config.timestamp,
                            style: TextStyle(
                              fontSize: 11,
                              color: _getSpeakerColor(config.speakerId),
                            ),
                          ),
                          if (config.isPriority) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.star, size: 12, color: Colors.amber[400]),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        config.captionHr,
                        style: const TextStyle(fontSize: 10),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[400]),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[300])),
        ],
      ),
    );
  }

  Color _getSpeakerColor(String? speakerId) {
    if (speakerId == null || _manifest == null) return Colors.grey;
    final speaker = _manifest!.speakers[speakerId];
    return speaker?.color ?? Colors.grey;
  }

  String _getSpeakerName(String speakerId) {
    if (_manifest == null) return speakerId;
    final speaker = _manifest!.speakers[speakerId];
    return speaker?.fullName ?? speakerId;
  }
}
