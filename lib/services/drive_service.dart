import 'dart:io';
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/entry.dart';

class DriveService {
  static const _clientId = '848750467129-7ejn3nmfkskn6h86le2cbrl7i35ok4mj.apps.googleusercontent.com';
  static const _folderName = 'Folio Journal';
  static const _scopes = [drive.DriveApi.driveFileScope];

  static final _googleSignIn = GoogleSignIn(
    clientId: _clientId,
    scopes: _scopes,
  );

  static GoogleSignInAccount? _currentUser;
  static drive.DriveApi? _driveApi;
  static String? _rootFolderId;

  // ── SIGN IN ──────────────────────────────────────────────────────────────
  static Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser == null) return false;
      await _initDriveApi();
      await _saveUserEmail(_currentUser!.email);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _driveApi = null;
    _rootFolderId = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('drive_email');
    await p.setBool('drive_connected', false);
  }

  static Future<bool> isSignedIn() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) await _initDriveApi();
      return _currentUser != null;
    } catch (e) {
      return false;
    }
  }

  static String? get userEmail => _currentUser?.email;

  static Future<void> _saveUserEmail(String email) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('drive_email', email);
    await p.setBool('drive_connected', true);
  }

  // ── INIT API ─────────────────────────────────────────────────────────────
  static Future<void> _initDriveApi() async {
    if (_currentUser == null) return;
    final headers = await _currentUser!.authHeaders;
    final client = _GoogleAuthClient(headers);
    _driveApi = drive.DriveApi(client);
    _rootFolderId = await _getOrCreateFolder(_folderName, null);
  }

  // ── FOLDER HELPERS ───────────────────────────────────────────────────────
  static Future<String> _getOrCreateFolder(String name, String? parentId) async {
    final q = parentId != null
      ? "name='$name' and mimeType='application/vnd.google-apps.folder' and '$parentId' in parents and trashed=false"
      : "name='$name' and mimeType='application/vnd.google-apps.folder' and trashed=false";

    final existing = await _driveApi!.files.list(q: q, spaces: 'drive');
    if (existing.files != null && existing.files!.isNotEmpty) {
      return existing.files!.first.id!;
    }

    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder';
    if (parentId != null) folder.parents = [parentId];

    final created = await _driveApi!.files.create(folder);
    return created.id!;
  }

  static Future<String> _getSubFolder(String name) async {
    return _getOrCreateFolder(name, _rootFolderId);
  }

  // ── SYNC ENTRY ───────────────────────────────────────────────────────────
  static Future<bool> syncEntry(Entry entry) async {
    if (_driveApi == null) {
      final ok = await isSignedIn();
      if (!ok) return false;
    }

    try {
      // Create a folder for this entry
      final entryFolderName = '${_formatDate(entry.date)}_${_sanitize(entry.title)}';
      final entryFolderId = await _getOrCreateFolder(entryFolderName, _rootFolderId);

      // Save text note
      final textContent = _buildTextContent(entry);
      await _uploadText('note.txt', textContent, entryFolderId);

      // Save photo
      if (entry.imagePath != null) {
        final file = File(entry.imagePath!);
        if (file.existsSync()) {
          await _uploadFile('photo.jpg', file, 'image/jpeg', entryFolderId);
        }
      }

      // Save audio
      if (entry.audioPath != null) {
        final file = File(entry.audioPath!);
        if (file.existsSync()) {
          await _uploadFile('audio.m4a', file, 'audio/mp4', entryFolderId);
        }
      }

      // Save video
      if (entry.videoPath != null) {
        final file = File(entry.videoPath!);
        if (file.existsSync()) {
          await _uploadFile('video.mp4', file, 'video/mp4', entryFolderId);
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  static String _buildTextContent(Entry entry) {
    final buf = StringBuffer();
    buf.writeln('Title: ${entry.title}');
    buf.writeln('Date: ${entry.date.toLocal()}');
    buf.writeln('Type: ${entry.type.label}');
    if (entry.mood != null) buf.writeln('Mood: ${entry.mood!.label}');
    if (entry.tags.isNotEmpty) buf.writeln('Tags: ${entry.tags.join(', ')}');
    buf.writeln('---');
    if (entry.body.isNotEmpty) buf.writeln(entry.body);
    return buf.toString();
  }

  static Future<void> _uploadText(String name, String content, String folderId) async {
    final bytes = utf8.encode(content);
    final stream = Stream.fromIterable([bytes]);
    final media = drive.Media(stream, bytes.length, contentType: 'text/plain');
    final file = drive.File()..name = name..parents = [folderId];

    // Check if exists first
    final existing = await _driveApi!.files.list(
      q: "name='$name' and '$folderId' in parents and trashed=false");
    if (existing.files != null && existing.files!.isNotEmpty) {
      await _driveApi!.files.update(drive.File(), existing.files!.first.id!,
        uploadMedia: media);
    } else {
      await _driveApi!.files.create(file, uploadMedia: media);
    }
  }

  static Future<void> _uploadFile(String name, File file,
      String mimeType, String folderId) async {
    final stream = file.openRead();
    final length = await file.length();
    final media = drive.Media(stream, length, contentType: mimeType);
    final driveFile = drive.File()..name = name..parents = [folderId];

    final existing = await _driveApi!.files.list(
      q: "name='$name' and '$folderId' in parents and trashed=false");
    if (existing.files != null && existing.files!.isNotEmpty) {
      await _driveApi!.files.update(drive.File(), existing.files!.first.id!,
        uploadMedia: media);
    } else {
      await _driveApi!.files.create(driveFile, uploadMedia: media);
    }
  }

  // ── SYNC ALL ─────────────────────────────────────────────────────────────
  static Future<Map<String,int>> syncAll(List<Entry> entries) async {
    int success = 0, failed = 0;
    for (final entry in entries) {
      final ok = await syncEntry(entry);
      if (ok) success++; else failed++;
    }
    return {'success': success, 'failed': failed};
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────
  static String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  static String _sanitize(String s) =>
    s.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_').substring(0, s.length.clamp(0, 40));
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
