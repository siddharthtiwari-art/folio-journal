import 'dart:io';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';

class MediaService {
  /// Pick photo from camera and save to gallery
  static Future<String?> pickPhotoFromCamera() async {
    final f = await ImagePicker().pickImage(
      source: ImageSource.camera, imageQuality: 90);
    if (f == null) return null;
    try {
      await Gal.putImage(f.path, album: 'Folio');
    } catch (_) {}
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
    try {
      await Gal.putVideo(f.path, album: 'Folio');
    } catch (_) {}
    return f.path;
  }

  /// Pick video from gallery
  static Future<String?> pickVideoFromGallery() async {
    final f = await ImagePicker().pickVideo(source: ImageSource.gallery);
    return f?.path;
  }
}
