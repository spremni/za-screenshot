import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

  // State
  ScreenshotManifest? _manifest;
  String? _configPath;
  bool _isLoading = false;
  bool _isCapturing = false;
  String _statusMessage = 'Select a JSON config file to start';
  double _progress = 0.0;
  int _sourceWidth = 0;
  int _sourceHeight = 0;
  List<String> _capturedFiles = [];
  ScreenshotConfig? _currentScreenshot;
  int _currentIndex = 0;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
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
    });

    try {
      final file = File(path);
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final manifest = ScreenshotManifest.fromJson(json);

      setState(() {
        _manifest = manifest;
        _statusMessage = 'Config loaded: ${manifest.metadata.videoTitle}';
      });

      print('[CONFIG] Loaded manifest:');
      print('  Video: ${manifest.metadata.videoTitle}');
      print('  URL: ${manifest.metadata.videoUrl}');
      print('  Screenshots: ${manifest.screenshots.length}');
      print('  Speakers: ${manifest.speakers.length}');

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

  Future<void> _initializeVideo() async {
    if (_manifest == null) return;

    setState(() {
      _statusMessage = 'Fetching video stream...';
    });

    try {
      // Use yt-dlp to get stream URL
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

      // Set resolution based on format
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

      setState(() {
        _statusMessage = 'Loading video (${_sourceWidth}x$_sourceHeight)...';
      });

      // Initialize player
      _player = Player(
        configuration: PlayerConfiguration(logLevel: MPVLogLevel.warn),
      );
      _videoController = media_kit.VideoController(_player!);

      await _player!.open(Media(streamUrl));
      await _player!.stream.playing.firstWhere((p) => p).timeout(
            const Duration(seconds: 30),
            onTimeout: () => false,
          );
      await _player!.pause();

      // Wait for dimensions
      int waitCount = 0;
      while (_player!.state.width == null && waitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }

      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _isLoading = false;
        _statusMessage = 'Ready to capture ${_manifest!.screenshots.length} screenshots';
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

  Future<void> _captureScreenshots() async {
    if (_manifest == null || _player == null || _isCapturing) return;

    setState(() {
      _isCapturing = true;
      _progress = 0.0;
      _capturedFiles = [];
      _currentIndex = 0;
    });

    try {
      // Determine output directory
      final outputDir = await _getOutputDirectory();
      print('[CAPTURE] Output directory: $outputDir');

      // Ensure directory exists
      final dir = Directory(outputDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final screenshots = _manifest!.screenshots;
      final total = screenshots.length;

      for (int i = 0; i < total; i++) {
        final config = screenshots[i];

        setState(() {
          _currentScreenshot = config;
          _currentIndex = i + 1;
          _progress = i / total;
          _statusMessage = 'Capturing ${i + 1}/$total: ${config.timestamp}';
        });

        print('[CAPTURE] === Screenshot ${i + 1}/$total ===');
        print('  Timestamp: ${config.timestamp} (${config.timestampSeconds}s)');
        print('  Filename: ${config.filename}');
        print('  Caption: ${config.captionHr}');

        // Seek to position
        await _player!.seek(config.duration);
        await _player!.play();
        await Future.delayed(const Duration(seconds: 2));

        // Wait for buffering
        int bufferWait = 0;
        while (_player!.state.buffering && bufferWait < 30) {
          await Future.delayed(const Duration(milliseconds: 100));
          bufferWait++;
        }

        await _player!.pause();
        await Future.delayed(const Duration(milliseconds: 500));

        // Capture frame
        final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;

        if (boundary == null) {
          print('[ERROR] RepaintBoundary not found');
          continue;
        }

        // Calculate pixel ratio to match source resolution
        final boundarySize = boundary.size;
        final pixelRatio = _sourceWidth / boundarySize.width;

        final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData == null) {
          print('[ERROR] Could not convert image to bytes');
          continue;
        }

        // Save file
        final filePath = '$outputDir/${config.filename}';
        final file = File(filePath);
        await file.writeAsBytes(byteData.buffer.asUint8List());

        _capturedFiles.add(filePath);
        print('[SAVED] $filePath (${image.width}x${image.height})');

        image.dispose();
      }

      setState(() {
        _isCapturing = false;
        _progress = 1.0;
        _currentScreenshot = null;
        _statusMessage = 'Capture complete! ${_capturedFiles.length} images saved.';
      });

      print('\n=== Capture Summary ===');
      print('Total: ${_capturedFiles.length} screenshots');
      print('Output: $outputDir');

    } catch (e, stackTrace) {
      print('[ERROR] Capture failed: $e');
      print(stackTrace);
      setState(() {
        _isCapturing = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<String> _getOutputDirectory() async {
    if (_manifest != null && _configPath != null) {
      // Use directory relative to config file
      final configDir = File(_configPath!).parent.path;
      return '$configDir/${_manifest!.metadata.outputDirectory}';
    }
    // Fallback to Downloads
    final home = Platform.environment['HOME'];
    return '$home/Downloads/screenshots';
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Config Section
            if (_manifest == null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
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
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Metadata Card
              Card(
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              setState(() {
                                _manifest = null;
                                _configPath = null;
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
                    ],
                  ),
                ),
              ),

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
                        if (_currentScreenshot != null) ...[
                          const SizedBox(height: 12),
                          Container(
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getSpeakerColor(_currentScreenshot!.speakerId),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _currentScreenshot!.timestamp,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_currentScreenshot!.speakerId != null)
                                      Text(
                                        _getSpeakerName(_currentScreenshot!.speakerId!),
                                        style: TextStyle(
                                          color: _getSpeakerColor(_currentScreenshot!.speakerId),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _currentScreenshot!.captionHr,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Status & Progress Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isLoading || _isCapturing)
                            const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          Flexible(
                            child: Text(
                              _statusMessage,
                              style: const TextStyle(fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      if (_isCapturing) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 400,
                          child: LinearProgressIndicator(
                            value: _progress,
                            backgroundColor: Colors.grey[800],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_currentIndex / ${_manifest!.screenshots.length}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                      if (_capturedFiles.isNotEmpty && !_isCapturing) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'Output: ${_capturedFiles.length} files saved',
                          style: TextStyle(color: Colors.green[400], fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: (_isLoading || _isCapturing || _player == null)
                        ? null
                        : _captureScreenshots,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(_isCapturing ? 'Capturing...' : 'Capture All Screenshots'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _isLoading || _isCapturing ? null : _pickConfigFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Load Different Config'),
                  ),
                ],
              ),
            ],

            // Loading indicator
            if (_isLoading && _manifest == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
          ],
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
