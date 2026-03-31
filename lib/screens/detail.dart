import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';
import '../services/store.dart';
import 'compose.dart';
import '../widgets/video_thumb.dart';

class DetailScreen extends StatefulWidget {
  final Entry entry;
  const DetailScreen({super.key, required this.entry});
  @override State<DetailScreen> createState() => _DetailState();
}

class _DetailState extends State<DetailScreen> {
  late Entry _e;
  final _audioPlayer = AudioPlayer();
  VideoPlayerController? _videoCtrl;
  bool _isPlayingAudio = false;
  bool _videoReady = false;
  Duration _audioDur = Duration.zero;
  Duration _audioPos = Duration.zero;

  static const _ink = Color(0xFF2C1F14);
  static const _muted = Color(0xFFB0998C);
  static const _light = Color(0xFFF0E6D3);
  static const _paper = Color(0xFFFFFDF9);
  static const _copper = Color(0xFFC48B56);
  static const _green = Color(0xFF4A7C35);
  static const _greenbg = Color(0xFFE3EED8);

  @override
  void initState() {
    super.initState();
    _e = widget.entry;
    _initAudio();
    _initVideo();
  }

  void _initAudio() {
    if (_e.audioPath == null) return;
    _audioPlayer.onDurationChanged.listen((d) => setState(() => _audioDur = d));
    _audioPlayer.onPositionChanged.listen((p) => setState(() => _audioPos = p));
    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() { _isPlayingAudio = false; _audioPos = Duration.zero; });
    });
  }

  Future<void> _initVideo() async {
    if (_e.videoPath == null) return;
    final file = File(_e.videoPath!);
    if (!file.existsSync()) return;
    _videoCtrl = VideoPlayerController.file(file);
    await _videoCtrl!.initialize();
    setState(() => _videoReady = true);
  }

  Future<void> _toggleAudio() async {
    if (_e.audioPath == null) return;
    if (_isPlayingAudio) {
      await _audioPlayer.pause();
      setState(() => _isPlayingAudio = false);
    } else {
      await _audioPlayer.play(DeviceFileSource(_e.audioPath!));
      setState(() => _isPlayingAudio = true);
    }
  }

  Future<void> _toggleVideo() async {
    if (_videoCtrl == null || !_videoReady) return;
    if (_videoCtrl!.value.isPlaying) {
      await _videoCtrl!.pause();
    } else {
      await _videoCtrl!.play();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  String _fmtDur(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2,'0')}';

  Future<void> _delete() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: _paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Delete entry?', style: TextStyle(fontStyle: FontStyle.italic)),
      content: const Text('This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete', style: TextStyle(color: Colors.red))),
      ]));
    if (ok == true) { await Store.delete(_e.id); if (mounted) Navigator.pop(context); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5EFE6),
    appBar: AppBar(actions: [
      IconButton(icon: const Icon(Icons.edit_outlined, size: 20),
        onPressed: () async {
          await Navigator.push(context,
            MaterialPageRoute(builder: (_) => ComposeScreen(type: _e.type, existing: _e)));
          final updated = Store.all().where((x) => x.id == _e.id).firstOrNull;
          if (updated != null && mounted) {
            setState(() { _e = updated; });
            _initAudio();
            _initVideo();
          }
        }),
      IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
        onPressed: _delete),
    ]),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: _e.type.bgColor, borderRadius: BorderRadius.circular(20)),
          child: Text(_e.type.label, style: TextStyle(fontSize: 10,
            fontWeight: FontWeight.w700, color: _e.type.color))),
        const SizedBox(height: 10),
        Text(_e.title, style: const TextStyle(fontSize: 24,
          fontStyle: FontStyle.italic, color: _ink, height: 1.3)),
        const SizedBox(height: 6),
        Text(DateFormat('EEEE, MMMM d · h:mm a').format(_e.date) +
          (_e.mood != null ? '  ·  ${_e.mood!.emoji} ${_e.mood!.label}' : ''),
          style: const TextStyle(fontSize: 11, color: _muted)),
        if (_e.tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, children: _e.tags.map((t) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: _light, borderRadius: BorderRadius.circular(20)),
            child: Text('# $t', style: const TextStyle(fontSize: 11, color: Color(0xFF8B5E3C))))).toList()),
        ],
        const SizedBox(height: 16),
        const Divider(color: Color(0xFFE8DDD0)),
        const SizedBox(height: 12),

        // ── PHOTO ──
        if (_e.type == EntryType.photo && _e.imagePath != null) ...[
          ClipRRect(borderRadius: BorderRadius.circular(12),
            child: Image.file(File(_e.imagePath!),
              width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(height: 120,
                color: const Color(0xFFD4C5B0),
                child: const Center(child: Text('Image not available',
                  style: TextStyle(color: _muted)))))),
          const SizedBox(height: 14),
        ],

        // ── AUDIO ──
        if (_e.type == EntryType.audio && _e.hasAudio) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _greenbg, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Row(children: [
                GestureDetector(
                  onTap: _toggleAudio,
                  child: Container(width: 46, height: 46,
                    decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
                    child: Icon(
                      _isPlayingAudio ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white, size: 26))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Audio recording',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
                  Text(
                    _audioDur > Duration.zero
                      ? '${_fmtDur(_audioPos)} / ${_fmtDur(_audioDur)}'
                      : _e.audioDuration > 0
                        ? 'Duration: ${_e.audioDuration ~/ 60}:${(_e.audioDuration % 60).toString().padLeft(2,'0')}'
                        : 'Tap to play',
                    style: const TextStyle(fontSize: 11, color: _muted)),
                ])),
              ]),
              const SizedBox(height: 10),
              // Progress bar
              if (_audioDur > Duration.zero)
                SliderTheme(
                  data: SliderThemeData(trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
                  child: Slider(
                    value: _audioPos.inSeconds.toDouble(),
                    max: _audioDur.inSeconds.toDouble(),
                    activeColor: _green, inactiveColor: _green.withOpacity(0.2),
                    onChanged: (v) async {
                      await _audioPlayer.seek(Duration(seconds: v.toInt()));
                    }))
              else
                // Waveform
                SizedBox(height: 30, child: Row(
                  children: List.generate(30, (i) {
                    const hs = [.3,.65,.9,.5,1,.7,.4,.85,.55,.8,.6,.35,.75,.5,.9,
                                .42,.68,.55,.88,.62,.45,.78,.52,.87,.33,.6,.8,.4,.7,.5];
                    return Expanded(child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: FractionallySizedBox(heightFactor: hs[i].toDouble(),
                        child: Container(decoration: BoxDecoration(
                          color: _green.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(2))))));
                  }))),
            ])),
          const SizedBox(height: 14),
        ],

        // ── VIDEO ──
        if (_e.type == EntryType.video && _e.videoPath != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: _toggleVideo,
              child: _videoReady && _videoCtrl != null
                ? AspectRatio(
                    aspectRatio: _videoCtrl!.value.aspectRatio,
                    child: Stack(alignment: Alignment.center, children: [
                      VideoPlayer(_videoCtrl!),
                      if (!_videoCtrl!.value.isPlaying)
                        Container(width: 60, height: 60,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                            color: Colors.black45,
                            border: Border.all(color: Colors.white54, width: 2)),
                          child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 36)),
                    ]))
                : VideoThumb(videoPath: _e.videoPath!, height: 220),
            )),
          if (_videoReady && _videoCtrl != null) ...[
            VideoProgressIndicator(_videoCtrl!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: _copper, bufferedColor: Color(0x44C48B56),
                backgroundColor: Color(0xFFE0D0C0))),
          ],
          const SizedBox(height: 14),
        ],

        // ── BODY TEXT ──
        if (_e.body.isNotEmpty) Container(
          width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _paper, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8DDD0))),
          child: CustomPaint(
            painter: _LinedPainter(),
            child: Text(_e.body, style: const TextStyle(fontSize: 15,
              fontStyle: FontStyle.italic, color: Color(0xFF3D2B20), height: 2.0)))),
      ])));
}

class _LinedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFFE8DDD0)..strokeWidth = 0.5;
    var y = 30.0;
    while (y < size.height) { canvas.drawLine(Offset(0,y), Offset(size.width,y), p); y += 30; }
  }
  @override bool shouldRepaint(_) => false;
}
