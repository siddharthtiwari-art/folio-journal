import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ThumbnailService {
  static final Map<String, String> _cache = {};

  static Future<String?> getVideoThumbnail(String videoPath) async {
    if (_cache.containsKey(videoPath)) return _cache[videoPath];

    try {
      final dir = await getTemporaryDirectory();
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: dir.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 300,
        quality: 75,
      );
      if (thumbPath != null) _cache[videoPath] = thumbPath;
      return thumbPath;
    } catch (e) {
      return null;
    }
  }

  static Future<Uint8List?> getVideoThumbnailBytes(String videoPath) async {
    try {
      return await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 300,
        quality: 75,
      );
    } catch (e) {
      return null;
    }
  }
}
