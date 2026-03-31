import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/drive_service.dart';
import '../services/store.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onChanged;
  const SettingsScreen({super.key, this.onChanged});
  @override State<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsScreen> {
  bool _driveConnected = false;
  String _driveEmail = '';
  bool _reminderOn = false;
  bool _syncing = false;
  int _syncedCount = 0;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 21, minute: 0);

  static const _ink = Color(0xFF2C1F14);
  static const _muted = Color(0xFFB0998C);
  static const _paper = Color(0xFFFFFDF9);
  static const _light = Color(0xFFF0E6D3);
  static const _copper = Color(0xFFC48B56);
  static const _green = Color(0xFF4A7C35);
  static const _greenbg = Color(0xFFE3EED8);

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final connected = p.getBool('drive_connected') ?? false;
    if (connected) {
      final stillConnected = await DriveService.isSignedIn();
      setState(() {
        _driveConnected = stillConnected;
        _driveEmail = DriveService.userEmail ?? p.getString('drive_email') ?? '';
      });
    }
    setState(() {
      _reminderOn = p.getBool('reminder_on') ?? false;
      final h = p.getInt('reminder_hour') ?? 21;
      final m = p.getInt('reminder_minute') ?? 0;
      _reminderTime = TimeOfDay(hour: h, minute: m);
    });
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('reminder_on', _reminderOn);
    await p.setInt('reminder_hour', _reminderTime.hour);
    await p.setInt('reminder_minute', _reminderTime.minute);
  }

  Future<void> _connectDrive() async {
    setState(() => _syncing = true);
    final ok = await DriveService.signIn();
    if (ok) {
      setState(() {
        _driveConnected = true;
        _driveEmail = DriveService.userEmail ?? '';
        _syncing = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected as ${DriveService.userEmail} ✓'),
          backgroundColor: _green, behavior: SnackBarBehavior.floating));
    } else {
      setState(() => _syncing = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in cancelled or failed'),
          backgroundColor: _ink, behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _disconnectDrive() async {
    await DriveService.signOut();
    setState(() { _driveConnected = false; _driveEmail = ''; });
  }

  Future<void> _syncNow() async {
    if (!_driveConnected) return;
    setState(() => _syncing = true);
    final entries = Store.all();
    final result = await DriveService.syncAll(entries);
    setState(() {
      _syncing = false;
      _syncedCount = result['success'] ?? 0;
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Synced ${result['success']} entries to Drive'
          '${result['failed']! > 0 ? ", ${result['failed']} failed" : ""}'),
        backgroundColor: result['failed']! > 0 ? _copper : _green,
        behavior: SnackBarBehavior.floating));
  }

  Future<void> _toggleReminder(bool on) async {
    if (on) {
      final granted = await NotificationService.requestPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please allow notifications in phone settings'),
          backgroundColor: _ink, behavior: SnackBarBehavior.floating));
        return;
      }
      await NotificationService.scheduleDailyReminder(
        _reminderTime.hour, _reminderTime.minute);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Reminder set for ${_reminderTime.format(context)} daily ✓'),
        backgroundColor: _green, behavior: SnackBarBehavior.floating));
    } else {
      await NotificationService.cancelAll();
    }
    setState(() => _reminderOn = on);
    await _savePrefs();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _reminderTime);
    if (t == null) return;
    setState(() => _reminderTime = t);
    await _savePrefs();
    if (_reminderOn) {
      await NotificationService.scheduleDailyReminder(t.hour, t.minute);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Reminder updated to ${t.format(context)} ✓'),
        backgroundColor: _green, behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext ctx) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Settings', style: TextStyle(fontSize: 26,
        fontStyle: FontStyle.italic, color: _ink)),
      const SizedBox(height: 20),

      // ── GOOGLE DRIVE ──────────────────────────────────────────────────
      _secTitle('Google Drive Sync'),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: _paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0D0C0))),
        child: Column(children: [
          // Status row
          Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(
                color: _driveConnected ? _greenbg : _light,
                borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.cloud_outlined, size: 24,
                color: _driveConnected ? _green : _copper)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_driveConnected ? 'Connected ✓' : 'Not connected',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                  color: _driveConnected ? _green : _ink)),
              Text(_driveConnected ? _driveEmail : 'Tap below to connect',
                style: const TextStyle(fontSize: 11, color: _muted)),
            ])),
          ])),

          const Divider(height: 1, color: Color(0xFFE0D0C0)),

          // What gets stored info
          Padding(padding: const EdgeInsets.all(14), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Each note is synced as a folder in Drive:',
              style: TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            _driveRow('📝', 'Text', 'note.txt with full content'),
            _driveRow('📷', 'Photos', 'photo.jpg in the note folder'),
            _driveRow('🎙', 'Audio', 'audio.m4a in the note folder'),
            _driveRow('🎬', 'Videos', 'video.mp4 in the note folder'),
            const SizedBox(height: 14),

            if (!_driveConnected) ...[
              SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _syncing
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.account_circle_outlined, size: 18),
                  label: Text(_syncing ? 'Connecting...' : 'Connect Google Account'),
                  onPressed: _syncing ? null : _connectDrive,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ink, foregroundColor: const Color(0xFFE8D5B7),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
            ] else ...[
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                  icon: _syncing
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.sync, size: 18),
                  label: Text(_syncing ? 'Syncing...' : 'Sync all notes now'),
                  onPressed: _syncing ? null : _syncNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _disconnectDrive,
                  style: OutlinedButton.styleFrom(foregroundColor: _muted,
                    side: const BorderSide(color: Color(0xFFD0C0B0)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Disconnect')),
              ]),
              if (_syncedCount > 0) ...[
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _greenbg, borderRadius: BorderRadius.circular(9)),
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline, size: 14, color: _green),
                    const SizedBox(width: 8),
                    Text('$_syncedCount notes synced to Drive',
                      style: const TextStyle(fontSize: 11, color: _green)),
                  ])),
              ],
            ],
          ])),
        ])),

      const SizedBox(height: 20),

      // ── REMINDERS ─────────────────────────────────────────────────────
      _secTitle('Daily Reminder'),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: _paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0D0C0))),
        child: Column(children: [
          ListTile(
            leading: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: _light, borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.notifications_outlined, size: 18, color: _copper)),
            title: const Text('Daily reminder',
              style: TextStyle(fontSize: 14, color: _ink)),
            subtitle: const Text('Remind me to write every day',
              style: TextStyle(fontSize: 11, color: _muted)),
            trailing: Switch(value: _reminderOn, onChanged: _toggleReminder,
              activeColor: _copper),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4)),
          if (_reminderOn) ...[
            const Divider(height: 1, color: Color(0xFFE0D0C0)),
            ListTile(
              onTap: _pickTime,
              leading: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: _light, borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.access_time_outlined, size: 18, color: _copper)),
              title: const Text('Reminder time',
                style: TextStyle(fontSize: 14, color: _ink)),
              subtitle: Text(_reminderTime.format(ctx),
                style: const TextStyle(fontSize: 11, color: _muted)),
              trailing: const Icon(Icons.chevron_right, color: _muted),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4)),
            const Divider(height: 1, color: Color(0xFFE0D0C0)),
            ListTile(
              leading: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: _greenbg, borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.notifications_active_outlined, size: 18, color: _green)),
              title: const Text('Send test notification',
                style: TextStyle(fontSize: 14, color: _ink)),
              subtitle: const Text('Verify notifications are working',
                style: TextStyle(fontSize: 11, color: _muted)),
              trailing: const Icon(Icons.chevron_right, color: _muted),
              onTap: () async {
                await NotificationService.showTestNotification();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test sent — check your notification bar'),
                    backgroundColor: _green, behavior: SnackBarBehavior.floating));
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4)),
          ],
        ])),

      const SizedBox(height: 20),

      // ── ABOUT ──────────────────────────────────────────────────────────
      _secTitle('About'),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: _paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0D0C0))),
        child: Column(children: [
          _infoRow('Version', '1.0.0'),
          const Divider(height: 1, color: Color(0xFFE0D0C0)),
          _infoRow('Storage', 'Local + Google Drive'),
          const Divider(height: 1, color: Color(0xFFE0D0C0)),
          _infoRow('App', 'Folio Journal'),
        ])),
    ]));

  Widget _secTitle(String t) => Text(t,
    style: const TextStyle(fontSize: 11, color: _muted,
      letterSpacing: .8, fontWeight: FontWeight.w700));

  Widget _driveRow(String emoji, String title, String sub) =>
    Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12,
            fontWeight: FontWeight.w600, color: _ink)),
          Text(sub, style: const TextStyle(fontSize: 10, color: _muted)),
        ])),
      ]));

  Widget _infoRow(String label, String value) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 13, color: _muted)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13,
          color: _ink, fontWeight: FontWeight.w500)),
      ]));
}
