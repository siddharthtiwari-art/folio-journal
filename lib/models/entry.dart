import 'package:flutter/material.dart';

enum EntryType { text, audio, photo, video }
enum Mood { happy, calm, grateful, reflective, anxious, sad }

extension EntryTypeX on EntryType {
  String get label => ['Text','Audio','Photo','Video'][index];
  Color get color => [const Color(0xFF8B5E3C), const Color(0xFF4A7C35),
    const Color(0xFF2C5F9E), const Color(0xFF9E2C6E)][index];
  Color get bgColor => [const Color(0xFFF0E6D3), const Color(0xFFE3EED8),
    const Color(0xFFDDE8F5), const Color(0xFFEEDDE8)][index];
  String get icon => ['✏️','🎙','📷','🎬'][index];
}

extension MoodX on Mood {
  String get label => ['Happy','Calm','Grateful','Reflective','Anxious','Sad'][index];
  String get emoji => ['☀','◎','★','◇','△','▽'][index];
}

class Entry {
  final String id;
  final EntryType type;
  final String title;
  final String body;
  final DateTime date;
  final Mood? mood;
  final List<String> tags;
  final String? imagePath;
  final String? videoPath;
  final String? audioPath;
  final bool hasAudio;
  final int audioDuration;

  const Entry({
    required this.id, required this.type, required this.title,
    required this.body, required this.date,
    this.mood, this.tags = const [],
    this.imagePath, this.videoPath, this.audioPath,
    this.hasAudio = false, this.audioDuration = 0,
  });

  Map<String,dynamic> toMap() => {
    'id': id, 'type': type.name, 'title': title, 'body': body,
    'date': date.toIso8601String(), 'mood': mood?.name, 'tags': tags,
    'imagePath': imagePath, 'videoPath': videoPath, 'audioPath': audioPath,
    'hasAudio': hasAudio, 'audioDuration': audioDuration,
  };

  factory Entry.fromMap(Map<String,dynamic> m) => Entry(
    id: m['id'], type: EntryType.values.byName(m['type']),
    title: m['title'], body: m['body'], date: DateTime.parse(m['date']),
    mood: m['mood'] != null ? Mood.values.byName(m['mood']) : null,
    tags: List<String>.from(m['tags'] ?? []),
    imagePath: m['imagePath'], videoPath: m['videoPath'], audioPath: m['audioPath'],
    hasAudio: m['hasAudio'] ?? false, audioDuration: m['audioDuration'] ?? 0,
  );

  String get dateLabel {
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${mo[date.month-1]} ${date.day}';
  }
}
