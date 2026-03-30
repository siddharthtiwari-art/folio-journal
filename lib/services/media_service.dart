import 'dart:io';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

class MediaService {
  /// Pick photo from camera and save to gallery
  static Future<String?> pickPhotoFromCamera() async {
    final f = await ImagePicker().pickImage(
      source: ImageSource.camera, imageQuality: 90);
    if (f == null) return null;
    // Save to gallery so it appears in Android Photos app
    await GallerySaver.saveImage(f.path, albumName: 'Folio');
    return f.path;
  }

  /// Pick photo from gallery
  static Future<String?> pickPhotoFromGallery() async {
    final f = await ImagePicker().pickImage(
      source: ImageSource.gallery, imageQuality: 90);
    return f?.path;
  }

  /// Record video from camera and save to gallery
  static Future<String?> recordVideo() async {
    final f = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 10));
    if (f == null) return null;
    // Save to gallery so it appears in Android Photos/Gallery app
    await GallerySaver.saveVideo(f.path, albumName: 'Folio');
    return f.path;
  }

  /// Pick video from gallery
  static Future<String?> pickVideoFromGallery() async {
    final f = await ImagePicker().pickVideo(source: ImageSource.gallery);
    return f?.path;
  }

  /// Copy a temp file to permanent app storage so it persists
  static Future<String> persistFile(String tempPath, String ext) async {
    final dir = await getApplicationDocumentsDirectory();
    final dest = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}$ext';
    await File(tempPath).copy(dest);
    return dest;
  }
}
