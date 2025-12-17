import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as media_kit;
import 'package:path_provider/path_provider.dart';

const double videoScaleFactor = 4.0;
const String targetVideoUrl = 'https://www.youtube.com/watch?v=Er5CcLF4xyg';

const List<Duration> captureTimestamps = [
  Duration(seconds: 15),
  Duration(minutes: 1, seconds: 45),
  Duration(minutes: 3),
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const ZaScreenshotApp());
}

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
  late final Player _player;
  late final media_kit.VideoController _videoController;
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  bool _isLoading = true;
  bool _isCapturing = false;
  String _statusMessage = 'Initializing...';
  double _progress = 0.0;
  int _sourceWidth = 0;
  int _sourceHeight = 0;
  List<String> _capturedFiles = [];

  // Debug state
  String _debugInfo = '';
  List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: PlayerConfiguration(
        logLevel: MPVLogLevel.debug,
      ),
    );
    _videoController = media_kit.VideoController(_player);
    _setupDebugListeners();
    _initializeVideo();
  }

  void _setupDebugListeners() {
    print('[DEBUG] Setting up player stream listeners...');

    // Listen to player state changes
    _subscriptions.add(_player.stream.playing.listen((playing) {
      print('[DEBUG] Player playing: $playing');
    }));

    _subscriptions.add(_player.stream.completed.listen((completed) {
      print('[DEBUG] Player completed: $completed');
    }));

    _subscriptions.add(_player.stream.position.listen((position) {
      // Only log every 5 seconds to avoid spam
      if (position.inSeconds % 5 == 0 && position.inMilliseconds % 1000 < 100) {
        print('[DEBUG] Position: $position');
      }
    }));

    _subscriptions.add(_player.stream.duration.listen((duration) {
      print('[DEBUG] Duration: $duration');
    }));

    _subscriptions.add(_player.stream.buffering.listen((buffering) {
      print('[DEBUG] Buffering: $buffering');
    }));

    _subscriptions.add(_player.stream.buffer.listen((buffer) {
      print('[DEBUG] Buffer: $buffer');
    }));

    _subscriptions.add(_player.stream.width.listen((width) {
      print('[DEBUG] Video width from player: $width');
      setState(() {
        _debugInfo = 'Player width: $width';
      });
    }));

    _subscriptions.add(_player.stream.height.listen((height) {
      print('[DEBUG] Video height from player: $height');
      setState(() {
        _debugInfo = 'Player height: $height';
      });
    }));

    _subscriptions.add(_player.stream.error.listen((error) {
      print('[DEBUG] ERROR: $error');
    }));

    _subscriptions.add(_player.stream.log.listen((log) {
      print('[DEBUG] Log: ${log.level} - ${log.prefix}: ${log.text}');
    }));
  }

  Future<void> _initializeVideo() async {
    try {
      setState(() {
        _statusMessage = 'Fetching YouTube stream via yt-dlp...';
      });

      // Use yt-dlp to get a working stream URL (supports all qualities)
      print('[DEBUG] Using yt-dlp to fetch stream URL...');

      // First, list available formats
      final listResult = await Process.run('yt-dlp', ['-F', targetVideoUrl]);
      print('[DEBUG] Available formats:\n${listResult.stdout}');

      // Try to get 1080p (format 137), fallback to 720p (136), then 480p (135)
      String? streamUrl;
      int selectedFormat = 0;

      for (final format in [137, 136, 135, 134, 18]) {
        print('[DEBUG] Trying format $format...');
        final result = await Process.run('yt-dlp', ['-f', '$format', '-g', targetVideoUrl]);

        if (result.exitCode == 0 && (result.stdout as String).trim().isNotEmpty) {
          streamUrl = (result.stdout as String).trim();
          selectedFormat = format;
          print('[DEBUG] Got URL for format $format');
          break;
        } else {
          print('[DEBUG] Format $format failed: ${result.stderr}');
        }
      }

      if (streamUrl == null) {
        throw Exception('Could not get any stream URL from yt-dlp');
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
        case 134:
          _sourceWidth = 640;
          _sourceHeight = 360;
          break;
        case 18:
          _sourceWidth = 640;
          _sourceHeight = 360;
          break;
        default:
          _sourceWidth = 1920;
          _sourceHeight = 1080;
      }

      print('[DEBUG] Selected format: $selectedFormat (${_sourceWidth}x$_sourceHeight)');
      print('[DEBUG] Stream URL length: ${streamUrl.length} chars');

      setState(() {
        _statusMessage = 'Loading video (${_sourceWidth}x$_sourceHeight)...';
      });

      print('[DEBUG] Opening media in player...');
      await _player.open(Media(streamUrl));
      print('[DEBUG] Media opened, waiting for playback to start...');

      // Wait for video to be ready with timeout
      print('[DEBUG] Waiting for player.stream.playing...');
      await _player.stream.playing.firstWhere((playing) => playing).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('[DEBUG] TIMEOUT waiting for playing state!');
          return false;
        },
      );

      print('[DEBUG] Video started playing, now pausing...');
      await _player.pause();

      // Wait for video dimensions to be available (indicates frame is decoded)
      print('[DEBUG] Waiting for video dimensions...');
      int waitCount = 0;
      while (_player.state.width == null && waitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }
      print('[DEBUG] Waited ${waitCount * 100}ms for dimensions');

      // Wait a bit more and check player state
      await Future.delayed(const Duration(seconds: 2));

      print('[DEBUG] After pause - checking player state:');
      print('[DEBUG]   state.playing: ${_player.state.playing}');
      print('[DEBUG]   state.position: ${_player.state.position}');
      print('[DEBUG]   state.duration: ${_player.state.duration}');
      print('[DEBUG]   state.width: ${_player.state.width}');
      print('[DEBUG]   state.height: ${_player.state.height}');
      print('[DEBUG]   state.buffering: ${_player.state.buffering}');
      print('[DEBUG]   state.buffer: ${_player.state.buffer}');

      setState(() {
        _isLoading = false;
        _statusMessage = 'Ready to capture';
        _debugInfo = 'Player: ${_player.state.width}x${_player.state.height}';
      });
    } catch (e, stackTrace) {
      print('[DEBUG] ERROR in _initializeVideo: $e');
      print('[DEBUG] Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _captureScreenshots() async {
    if (_isCapturing || _sourceWidth == 0) return;

    setState(() {
      _isCapturing = true;
      _progress = 0.0;
      _capturedFiles = [];
      _statusMessage = 'Starting capture...';
    });

    try {
      final downloadsDir = await _getDownloadsDirectory();
      print('[DEBUG] Downloads directory: $downloadsDir');

      for (int i = 0; i < captureTimestamps.length; i++) {
        final timestamp = captureTimestamps[i];

        setState(() {
          _statusMessage = 'Seeking to ${_formatDuration(timestamp)}...';
          _progress = (i / captureTimestamps.length);
        });

        print('[DEBUG] === Capturing frame $i at $timestamp ===');

        // Seek to position
        print('[DEBUG] Seeking to $timestamp...');
        await _player.seek(timestamp);

        // Play briefly to ensure frame is decoded
        print('[DEBUG] Playing briefly to decode frame...');
        await _player.play();

        // Wait for seek to complete and frame to buffer
        print('[DEBUG] Waiting for buffering...');
        await Future.delayed(const Duration(seconds: 3));

        // Wait for buffering to complete
        int bufferWait = 0;
        while (_player.state.buffering && bufferWait < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          bufferWait++;
        }
        print('[DEBUG] Buffering wait: ${bufferWait * 100}ms');

        // Check current state
        print('[DEBUG] After seek - player state:');
        print('[DEBUG]   position: ${_player.state.position}');
        print('[DEBUG]   buffering: ${_player.state.buffering}');
        print('[DEBUG]   width: ${_player.state.width}');
        print('[DEBUG]   height: ${_player.state.height}');

        // Pause for capture
        print('[DEBUG] Pausing for capture...');
        await _player.pause();

        // Extra wait to ensure frame is rendered
        await Future.delayed(const Duration(seconds: 1));

        setState(() {
          _statusMessage = 'Capturing frame at ${_formatDuration(timestamp)}...';
        });

        // Capture the frame using RepaintBoundary
        final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;

        if (boundary == null) {
          print('[DEBUG] ERROR: RepaintBoundary not found!');
          continue;
        }

        print('[DEBUG] RepaintBoundary found, size: ${boundary.size}');
        print('[DEBUG] Capturing with pixelRatio: $videoScaleFactor');

        // Capture at 4x scale to get full resolution
        final ui.Image image = await boundary.toImage(pixelRatio: videoScaleFactor);
        print('[DEBUG] Image captured: ${image.width}x${image.height}');

        // Convert to PNG
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          print('[DEBUG] ERROR: Could not convert image to bytes');
          continue;
        }
        print('[DEBUG] PNG byte data size: ${byteData.lengthInBytes} bytes');

        // Generate filename
        final filename = 'za_screenshot_${_formatFilename(timestamp)}.png';
        final filePath = '$downloadsDir/$filename';

        // Save file
        print('[DEBUG] Saving to: $filePath');
        final file = File(filePath);
        await file.writeAsBytes(byteData.buffer.asUint8List());

        _capturedFiles.add(filePath);

        // Print verification info
        print('[DEBUG] Saved: $filePath');
        print('[DEBUG] Resolution: ${image.width} x ${image.height}');

        image.dispose();
      }

      setState(() {
        _isCapturing = false;
        _progress = 1.0;
        _statusMessage = 'Capture complete! ${_capturedFiles.length} images saved.';
      });

      print('\n=== Capture Summary ===');
      for (final path in _capturedFiles) {
        print(path);
      }
    } catch (e, stackTrace) {
      print('[DEBUG] ERROR in _captureScreenshots: $e');
      print('[DEBUG] Stack trace: $stackTrace');
      setState(() {
        _isCapturing = false;
        _statusMessage = 'Error during capture: $e';
      });
    }
  }

  Future<String> _getDownloadsDirectory() async {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      return '$home/Downloads';
    }
    final dir = await getDownloadsDirectory();
    return dir?.path ?? (await getApplicationDocumentsDirectory()).path;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatFilename(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}_${minutes.toString().padLeft(2, '0')}_${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayWidth = _sourceWidth > 0 ? _sourceWidth / videoScaleFactor : 960.0;
    final displayHeight = _sourceHeight > 0 ? _sourceHeight / videoScaleFactor : 540.0;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.screenshot_monitor, size: 28),
            SizedBox(width: 12),
            Text(
              'Za Screenshot',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Debug info
              if (_debugInfo.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Debug: $_debugInfo',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                ),

              // Video Player Card
              Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Source info
                      if (_sourceWidth > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.videocam, size: 16, color: Colors.grey[400]),
                              const SizedBox(width: 8),
                              Text(
                                'Source: ${_sourceWidth}x$_sourceHeight',
                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.display_settings, size: 16, color: Colors.grey[400]),
                              const SizedBox(width: 8),
                              Text(
                                'Display: ${displayWidth.toInt()}x${displayHeight.toInt()}',
                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              ),
                            ],
                          ),
                        ),

                      // Video with RepaintBoundary
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: RepaintBoundary(
                          key: _repaintBoundaryKey,
                          child: SizedBox(
                            width: displayWidth,
                            height: displayHeight,
                            child: _isLoading
                                ? Container(
                                    color: const Color(0xFF2D2D44),
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : media_kit.Video(
                                    controller: _videoController,
                                    controls: media_kit.NoVideoControls,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Status message
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

                      // Progress bar
                      if (_isCapturing) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 300,
                          child: LinearProgressIndicator(
                            value: _progress,
                            backgroundColor: Colors.grey[800],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],

                      // Timestamps info
                      if (!_isCapturing && !_isLoading && _sourceWidth > 0) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Timestamps to capture:',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: captureTimestamps
                              .map((ts) => Chip(
                                    label: Text(_formatDuration(ts)),
                                    backgroundColor: const Color(0xFF2D2D44),
                                    labelStyle: const TextStyle(fontSize: 12),
                                  ))
                              .toList(),
                        ),
                      ],

                      // Captured files list
                      if (_capturedFiles.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'Saved to Downloads:',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        ...(_capturedFiles.map((path) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                path.split('/').last,
                                style: TextStyle(
                                  color: Colors.green[400],
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ))),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Capture Button
              ElevatedButton.icon(
                onPressed: (_isLoading || _isCapturing) ? null : _captureScreenshots,
                icon: const Icon(Icons.camera_alt),
                label: Text(_isCapturing ? 'Capturing...' : 'Capture Screenshots'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                ),
              ),

              const SizedBox(height: 16),

              // Help text
              Text(
                'Output: PNG images (${(_sourceWidth > 0 ? _sourceWidth : 3840)}x${(_sourceHeight > 0 ? _sourceHeight : 2160)})',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
