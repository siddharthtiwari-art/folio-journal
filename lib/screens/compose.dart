import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../models/entry.dart';
import '../services/store.dart';
import '../services/media_service.dart';

class ComposeScreen extends StatefulWidget {
  final EntryType type;
  final Entry? existing;
  final DateTime? forDate;
  const ComposeScreen({super.key, required this.type, this.existing, this.forDate});
  @override
  State<ComposeScreen> createState() => _ComposeState();
}

class _ComposeState extends State<ComposeScreen> {
  final _tc = TextEditingController();
  final _bc = TextEditingController();
  Mood? _mood;
  final List<String> _tags = [];
  String? _imgPath;
  String? _vidPath;
  String? _audioPath;
  bool _saving = false;
  bool _isRecording = false;
  bool _recDone = false;
  int _recSecs = 0;
  final _recorder = AudioRecorder();

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
    final e = widget.existing;
    if (e != null) {
      _tc.text = e.title;
      _bc.text = e.body;
      _mood = e.mood;
      _tags.addAll(e.tags);
      _imgPath = e.imagePath;
      _vidPath = e.videoPath;
      _audioPath = e.audioPath;
      if (e.hasAudio) {
        _recDone = true;
        _recSecs = e.audioDuration;
      }
    }
  }

  @override
  void dispose() {
    _tc.dispose();
    _bc.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_tc.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a title'),
          backgroundColor: _ink, behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _saving = true);
    await Store.save(Entry(
      id: widget.existing?.id ?? const Uuid().v4(),
      type: widget.type,
      title: _tc.text.trim(),
      body: _bc.text.trim(),
      date: widget.existing?.date ?? widget.forDate ?? DateTime.now(),
      mood: _mood,
      tags: List.from(_tags),
      imagePath: _imgPath,
      videoPath: _vidPath,
      audioPath: _audioPath,
      hasAudio: _recDone,
      audioDuration: _recSecs,
    ));
    if (mounted) Navigator.pop(context);
  }

  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission needed'),
          backgroundColor: _ink, behavior: SnackBarBehavior.floating));
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() { _isRecording = true; _recSecs = 0; _recDone = false; });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_isRecording) return false;
      setState(() => _recSecs++);
      return true;
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    setState(() { _isRecording = false; _recDone = true; _audioPath = path; });
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = widget.forDate != null
      ? ' · ${widget.forDate!.day}/${widget.forDate!.month}' : '';
    return Scaffold(
      backgroundColor: const Color(0xFFF5EFE6),
      appBar: AppBar(
        title: Text(
          '${widget.existing != null ? "Edit" : "New"} ${widget.type.label}$dateStr',
          style: const TextStyle(fontStyle: FontStyle.italic)),
        actions: [
          _saving
            ? const Padding(padding: EdgeInsets.all(14),
                child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)))
            : TextButton(onPressed: _save,
                child: const Text('Save',
                  style: TextStyle(color: _copper, fontWeight: FontWeight.w700))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputCard(),
            const SizedBox(height: 12),
            if (widget.type == EntryType.photo) _buildPhotoSection(),
            if (widget.type == EntryType.audio) _buildAudioSection(),
            if (widget.type == EntryType.video) _buildVideoSection(),
            const SizedBox(height: 12),
            _buildMoodSection(),
            const SizedBox(height: 12),
            _buildTagsSection(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0D0C0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _tc,
            style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500, color: _ink),
            decoration: const InputDecoration(
              hintText: 'Title...', border: InputBorder.none,
              hintStyle: TextStyle(color: _muted),
              isDense: true, contentPadding: EdgeInsets.zero)),
          Container(margin: const EdgeInsets.symmetric(vertical: 10),
            height: 0.5, color: const Color(0xFFE0D0C0)),
          CustomPaint(
            painter: _LinedPainter(),
            child: TextField(
              controller: _bc, maxLines: null, minLines: 8,
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic,
                color: _ink, height: 2.0),
              decoration: const InputDecoration(
                hintText: 'Write your thoughts...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: _muted),
                isDense: true, contentPadding: EdgeInsets.zero))),
        ]));
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Lbl('PHOTO'),
        const SizedBox(height: 8),
        if (_imgPath != null)
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(_imgPath!),
                height: 220, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _missingBox('Image unavailable'))),
            Positioned(top: 8, right: 8,
              child: _removeBtn(() => setState(() => _imgPath = null))),
          ])
        else
          Row(children: [
            Expanded(child: _mediaBox(
              icon: Icons.camera_alt_outlined, label: 'Camera',
              color: const Color(0xFFDDE8F5), iconColor: const Color(0xFF2C5F9E),
              onTap: () async {
                final path = await MediaService.pickPhotoFromCamera();
                if (path != null) setState(() => _imgPath = path);
              })),
            const SizedBox(width: 10),
            Expanded(child: _mediaBox(
              icon: Icons.photo_library_outlined, label: 'Gallery',
              color: _light, iconColor: _copper,
              onTap: () async {
                final path = await MediaService.pickPhotoFromGallery();
                if (path != null) setState(() => _imgPath = path);
              })),
          ]),
        const SizedBox(height: 12),
      ]);
  }

  Widget _buildAudioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Lbl('AUDIO RECORDING'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _paper, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE0D0C0))),
          child: Column(children: [
            SizedBox(
              height: 52,
              child: Row(
                children: List.generate(28, (i) {
                  const hs = [.3,.65,.9,.5,1,.7,.4,.85,.55,.8,.6,.35,.75,.5,.9,
                              .42,.68,.55,.88,.62,.45,.78,.52,.87,.33,.6,.8,.4];
                  final h = _isRecording
                    ? ((i % 5) * 0.18 + 0.2).clamp(0.1, 1.0)
                    : hs[i].toDouble();
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: FractionallySizedBox(
                        heightFactor: h,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: _recDone
                              ? _green.withOpacity(0.6)
                              : _isRecording
                                ? const Color(0xFFc0392b).withOpacity(0.7)
                                : _copper.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(3))))));
                }))),
            const SizedBox(height: 16),
            Text(
              _recDone
                ? '✓  Recorded  (${_fmt(_recSecs)})'
                : _isRecording
                  ? '● Recording...  ${_fmt(_recSecs)}'
                  : 'Tap mic to record',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic,
                fontWeight: _isRecording ? FontWeight.w600 : FontWeight.w400,
                color: _recDone ? _green
                  : _isRecording ? const Color(0xFFc0392b) : _muted)),
            const SizedBox(height: 18),
            if (!_recDone)
              GestureDetector(
                onTap: _toggleRecording,
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording ? const Color(0xFFc0392b) : _copper,
                    boxShadow: [BoxShadow(
                      color: (_isRecording
                        ? const Color(0xFFc0392b) : _copper).withOpacity(0.35),
                      blurRadius: 14, offset: const Offset(0, 4))]),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white, size: 32)))
            else
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Re-record'),
                  onPressed: () => setState(() {
                    _recDone = false; _recSecs = 0;
                    _isRecording = false; _audioPath = null;
                  }),
                  style: OutlinedButton.styleFrom(foregroundColor: _muted,
                    side: const BorderSide(color: Color(0xFFD0C0B0)))),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _greenbg, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle_outline, size: 14, color: _green),
                    const SizedBox(width: 5),
                    Text('${_fmt(_recSecs)} ready',
                      style: const TextStyle(fontSize: 12,
                        color: _green, fontWeight: FontWeight.w600)),
                  ])),
              ]),
          ])),
        const SizedBox(height: 12),
      ]);
  }

  Widget _buildVideoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Lbl('VIDEO'),
        const SizedBox(height: 8),
        if (_vidPath != null)
          Stack(alignment: Alignment.center, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 220, width: double.infinity,
                color: const Color(0xFF1a120b),
                child: const Center(child: Icon(Icons.videocam,
                  color: Color(0x88E8D5B7), size: 48)))),
            Container(width: 64, height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.black45,
                border: Border.all(color: Colors.white54, width: 2)),
              child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 38)),
            Positioned(top: 8, right: 8,
              child: _removeBtn(() => setState(() => _vidPath = null))),
          ])
        else
          Row(children: [
            Expanded(child: _mediaBox(
              icon: Icons.videocam_rounded, label: 'Record video',
              color: const Color(0xFFEEDDE8), iconColor: const Color(0xFF9E2C6E),
              onTap: () async {
                final path = await MediaService.recordVideo();
                if (path != null) setState(() => _vidPath = path);
              })),
            const SizedBox(width: 10),
            Expanded(child: _mediaBox(
              icon: Icons.video_library_rounded, label: 'From gallery',
              color: _light, iconColor: _copper,
              onTap: () async {
                final path = await MediaService.pickVideoFromGallery();
                if (path != null) setState(() => _vidPath = path);
              })),
          ]),
        const SizedBox(height: 12),
      ]);
  }

  Widget _buildMoodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Lbl('MOOD'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: Mood.values.map((m) {
            final on = _mood == m;
            return GestureDetector(
              onTap: () => setState(() => _mood = on ? null : m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: on ? _light : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: on ? _copper.withOpacity(.5) : const Color(0xFFD0C0B0))),
                child: Text('${m.emoji}  ${m.label}',
                  style: TextStyle(fontSize: 12,
                    color: on ? const Color(0xFF5C4033) : _muted,
                    fontWeight: on ? FontWeight.w600 : FontWeight.w400))));
          }).toList()),
      ]);
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Lbl('TAGS'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: [
            ..._tags.map((t) => GestureDetector(
              onTap: () => setState(() => _tags.remove(t)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _light, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('# $t', style: const TextStyle(
                    fontSize: 11, color: Color(0xFF8B5E3C))),
                  const SizedBox(width: 4),
                  const Icon(Icons.close, size: 12, color: _muted),
                ])))),
            GestureDetector(
              onTap: _addTag,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD0C0B0))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add, size: 13, color: _muted),
                  SizedBox(width: 3),
                  Text('Add tag', style: TextStyle(fontSize: 11, color: _muted)),
                ]))),
          ]),
      ]);
  }

  Widget _mediaBox({required IconData icon, required String label,
    required Color color, required Color iconColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: iconColor.withOpacity(0.2))),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 28, color: iconColor),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11,
            fontWeight: FontWeight.w600, color: iconColor)),
        ])));
  }

  Widget _removeBtn(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
        child: const Icon(Icons.close, size: 16, color: Colors.white)));
  }

  Widget _missingBox(String msg) {
    return Container(height: 100, color: const Color(0xFFE0D0C0),
      child: Center(child: Text(msg, style: const TextStyle(color: _muted))));
  }

  void _addTag() {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Add tag', style: TextStyle(fontStyle: FontStyle.italic)),
        content: TextField(controller: c, autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. travel, work')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (c.text.trim().isNotEmpty) {
                setState(() => _tags.add(c.text.trim().toLowerCase()));
              }
              Navigator.pop(context);
            },
            child: const Text('Add', style: TextStyle(color: _copper))),
        ]));
  }
}

class _LinedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFFE8DDD0)..strokeWidth = 0.5;
    var y = 28.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      y += 28.0;
    }
  }
  @override bool shouldRepaint(_) => false;
}

class _Lbl extends StatelessWidget {
  final String text;
  const _Lbl(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 10, color: Color(0xFFB0998C),
      letterSpacing: .8, fontWeight: FontWeight.w700));
}
