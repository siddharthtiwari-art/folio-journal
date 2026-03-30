import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/thumbnail_service.dart';

class VideoThumb extends StatefulWidget {
  final String videoPath;
  final double height;
  final BoxFit fit;
  final bool showPlayIcon;

  const VideoThumb({
    super.key, required this.videoPath,
    this.height = 140, this.fit = BoxFit.cover, this.showPlayIcon = true,
  });

  @override
  State<VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<VideoThumb> {
  Uint8List? _thumb;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final bytes = await ThumbnailService.getVideoThumbnailBytes(widget.videoPath);
    if (mounted) setState(() { _thumb = bytes; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height, width: double.infinity,
      child: Stack(fit: StackFit.expand, children: [
        _loading
          ? Container(color: const Color(0xFF1a120b),
              child: const Center(child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2,
                  color: Color(0x66E8D5B7)))))
          : _thumb != null
            ? Image.memory(_thumb!, fit: widget.fit)
            : Container(color: const Color(0xFF1a120b),
                child: const Center(child: Icon(Icons.videocam,
                  color: Color(0x88E8D5B7), size: 36))),
        Container(color: Colors.black26),
        if (widget.showPlayIcon)
          Center(child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: Colors.black45,
              border: Border.all(color: Colors.white60, width: 2)),
            child: const Icon(Icons.play_arrow_rounded,
              color: Colors.white, size: 28))),
      ]),
    );
  }
}
