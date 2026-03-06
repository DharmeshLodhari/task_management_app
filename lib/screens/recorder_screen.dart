import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../models/recording.dart';
import '../services/storage_service.dart';

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  final _recorder = Record();
  final _storage = StorageService();

  bool _isRecording = false;
  Duration _duration = Duration.zero;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      path: path,
      encoder: AudioEncoder.aacLc,
    );

    setState(() {
      _isRecording = true;
      _duration = Duration.zero;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _duration += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();

    if (path == null || !File(path).existsSync()) {
      setState(() => _isRecording = false);
      return;
    }

    final now = DateTime.now();
    final recording = Recording(
      id: now.millisecondsSinceEpoch.toString(),
      filePath: path,
      name: _formatName(now),
      createdAt: now,
    );

    final recordings = await _storage.load();
    recordings.insert(0, recording);
    await _storage.save(recordings);

    setState(() => _isRecording = false);
    if (mounted) Navigator.pop(context, true);
  }

  String _formatName(DateTime dt) {
    final date = '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
    final time = '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
    return 'Recording $date $time';
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Recording'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording
                    ? Colors.red.withOpacity(0.15)
                    : Colors.grey.withOpacity(0.1),
              ),
              child: Icon(
                _isRecording ? Icons.mic : Icons.mic_none,
                size: 64,
                color: _isRecording ? Colors.red : Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _formatDuration(_duration),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _isRecording ? 'Recording...' : 'Tap to start recording',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: _isRecording ? Colors.red : Colors.grey,
                  ),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              icon: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
              label: Text(_isRecording ? 'Stop & Save' : 'Start Recording'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.red : Colors.indigo,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
