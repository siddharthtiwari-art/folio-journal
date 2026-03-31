import 'dart:io';
import 'dart:typed_data';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

class MediaService {
  /// Pick photo from camera and save to gallery
  static Future<String?> pickPhotoFromCamera() async {
    final f = await ImagePicker().pickImage(
      source: ImageSource.camera, imageQuality: 90);
    if (f == null) return null;
    // Save to gallery so it appears in Android Photos app
    final bytes = await File(f.path).readAsBytes();
    await ImageGallerySaver.saveImage(bytes, name: 'folio_${DateTime.now().millisecondsSinceEpoch}', isReturnImagePathOfIOS: false);
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
    // Save to gallery
    await ImageGallerySaver.saveFile(f.path, name: 'folio_video_${DateTime.now().millisecondsSinceEpoch}');
    return f.path;
  }

  /// Pick video from gallery
  static Future<String?> pickVideoFromGallery() async {
    final f = await ImagePicker().pickVideo(source: ImageSource.gallery);
    return f?.path;
  }
}
