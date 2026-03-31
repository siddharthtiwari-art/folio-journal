import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';
import '../services/store.dart';
import 'compose.dart';
import 'detail.dart';
import '../widgets/video_thumb.dart';
import 'settings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  List<Entry> _all = [], _shown = [];
  Mood? _mood;
  String _q = '';
  int _tab = 0;
  final _sc = TextEditingController();
  DateTime _calMonth = DateTime.now();
  DateTime _calSelected = DateTime.now();

  // Pagination
  int _visibleDays = 5;
  static const _pageSize = 3;

  static const _ink = Color(0xFF2C1F14);
  static const _copper = Color(0xFFC48B56);
  static const _muted = Color(0xFFB0998C);
  static const _paper = Color(0xFFFFFDF9);
  static const _cream = Color(0xFFF5EFE6);
  static const _light = Color(0xFFF0E6D3);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() { _all = Store.all(); _filter(); });

  void _filter() {
    var l = List<Entry>.from(_all);
    if (_mood != null) l = l.where((e) => e.mood == _mood).toList();
    if (_q.isNotEmpty) {
      final q = _q.toLowerCase();
      l = l.where((e) =>
        e.title.toLowerCase().contains(q) ||
        e.body.toLowerCase().contains(q)).toList();
    }
    // Sort newest first
    l.sort((a, b) => b.date.compareTo(a.date));
    _shown = l;
  }

  // Group entries by date for journal view
  List<DateTime> get _visibleDates {
    final now = DateTime.now();
    return List.generate(_visibleDays, (i) =>
      DateTime(now.year, now.month, now.day - i));
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: _cream,
    body: SafeArea(child: IndexedStack(index: _tab, children: [
      _journal(), _calendar(), _memories(), _settingsTab(),
    ])),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _tab, onTap: (i) => setState(() => _tab = i),
      backgroundColor: _paper, selectedItemColor: _copper,
      unselectedItemColor: _muted,
      selectedFontSize: 10, unselectedFontSize: 10,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Journal'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: 'Calendar'),
        BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_outlined), label: 'Memories'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      backgroundColor: _copper, foregroundColor: Colors.white,
      onPressed: () => _picker(forDate: _tab == 1 ? _calSelected : null),
      child: const Icon(Icons.add, size: 28),
    ),
  );

  // ── JOURNAL ──────────────────────────────────────────────────────────────
  Widget _journal() => Column(children: [
    _topBar(), _searchBar(), _moodBar(),
    Expanded(child: _shown.isEmpty
      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('✦', style: TextStyle(fontSize: 30, color: Color(0xFFD0C0B0))),
          const SizedBox(height: 10),
          Text(_all.isEmpty
            ? 'Your journal awaits\nTap + to add your first entry'
            : 'No entries found',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: _muted)),
        ]))
      : NotificationListener<ScrollNotification>(
          onNotification: (n) {
            // Load more when reaching bottom
            if (n is ScrollEndNotification &&
                n.metrics.pixels >= n.metrics.maxScrollExtent - 50) {
              setState(() => _visibleDays += _pageSize);
            }
            return false;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 100),
            children: [
              // Group by date
              ..._visibleDates.expand((date) {
                final dayEntries = _shown.where((e) =>
                  e.date.year == date.year &&
                  e.date.month == date.month &&
                  e.date.day == date.day).toList();
                if (dayEntries.isEmpty) return <Widget>[];
                return [
                  // Date header
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6),
                    child: Row(children: [
                      Text(_dateHeader(date),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: _muted, letterSpacing: 0.5)),
                      const SizedBox(width: 8),
                      Expanded(child: Container(height: 0.5, color: const Color(0xFFE0D0C0))),
                    ])),
                  // Entries for this date
                  ...dayEntries.map((e) => _entryCard(e)),
                ];
              }),
              // Load more button
              if (_shown.any((e) {
                final cutoff = DateTime.now().subtract(Duration(days: _visibleDays));
                return e.date.isBefore(cutoff);
              }))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: TextButton.icon(
                    icon: const Icon(Icons.expand_more, color: _muted),
                    label: const Text('Load older entries',
                      style: TextStyle(color: _muted)),
                    onPressed: () => setState(() => _visibleDays += _pageSize),
                  ))),
            ],
          ),
        ),
    ),
  ]);

  String _dateHeader(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    return DateFormat('EEE, MMM d').format(d).toUpperCase();
  }

  Widget _entryCard(Entry e) {
    final feat = _shown.indexOf(e) == 0 && _mood == null && _q.isEmpty;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context,
          MaterialPageRoute(builder: (_) => DetailScreen(entry: e)));
        _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: feat ? _ink : _paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: feat ? Colors.transparent : const Color(0xFFE0D0C0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: feat ? Colors.white12 : e.type.bgColor,
                borderRadius: BorderRadius.circular(20)),
              child: Text(e.type.label, style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: feat ? const Color(0xFFE8D5B7) : e.type.color))),
            if (e.mood != null) ...[
              const SizedBox(width: 6),
              Text('${e.mood!.emoji} ${e.mood!.label}',
                style: TextStyle(fontSize: 10,
                  color: feat ? const Color(0x88E8D5B7) : _muted)),
            ],
            const Spacer(),
            Text(DateFormat('h:mm a').format(e.date),
              style: TextStyle(fontSize: 9,
                color: feat ? const Color(0x55E8D5B7) : _muted)),
          ]),
          const SizedBox(height: 8),
          // Photo thumbnail
          if (e.type == EntryType.photo && e.imagePath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(e.imagePath!),
                height: 140, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_,__,___) => Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: feat ? Colors.white12 : const Color(0xFFDDE8F5),
                    borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.image_outlined, size: 18,
                      color: feat ? const Color(0x88E8D5B7) : const Color(0xFF2C5F9E)),
                    const SizedBox(width: 6),
                    Text('Photo', style: TextStyle(fontSize: 11,
                      color: feat ? const Color(0x88E8D5B7) : const Color(0xFF2C5F9E))),
                  ])))),
            const SizedBox(height: 8),
          ],
          // Audio waveform
          if (e.type == EntryType.audio) ...[
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: feat ? Colors.white12 : const Color(0xFFE3EED8),
                borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Icon(Icons.mic, size: 14,
                  color: feat ? const Color(0x88E8D5B7) : const Color(0xFF4A7C35)),
                const SizedBox(width: 6),
                ...List.generate(22, (i) {
                  const hs = [.3,.65,.9,.5,1,.7,.4,.85,.55,.8,.6,.35,
                               .75,.5,.9,.42,.68,.55,.88,.62,.45,.78];
                  return Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: FractionallySizedBox(
                      heightFactor: hs[i].toDouble(),
                      child: Container(decoration: BoxDecoration(
                        color: feat
                          ? const Color(0x66E8D5B7)
                          : const Color(0xFF4A7C35).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2))))));
                }),
                const SizedBox(width: 6),
                Icon(Icons.play_arrow_rounded, size: 18,
                  color: feat ? const Color(0x88E8D5B7) : const Color(0xFF4A7C35)),
              ]),
            ),
            const SizedBox(height: 8),
          ],
          // Video thumbnail
          if (e.type == EntryType.video && e.videoPath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: VideoThumb(videoPath: e.videoPath!, height: 120)),
            const SizedBox(height: 8),
          ],
          if (e.type == EntryType.video && e.videoPath == null) ...[
            Container(height: 80,
              decoration: BoxDecoration(
                color: feat ? Colors.white12 : const Color(0xFF1a120b),
                borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Icon(Icons.videocam,
                color: Color(0x88E8D5B7), size: 32))),
            const SizedBox(height: 8),
          ],
          Text(e.title, style: TextStyle(
            fontSize: feat ? 17 : 14, fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            color: feat ? const Color(0xFFE8D5B7) : _ink)),
          if (e.body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(e.body.replaceAll('\n', ' '), maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12,
                color: feat ? const Color(0x77E8D5B7) : const Color(0xFF9C8878))),
          ],
        ]),
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const Text('Folio',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 28, color: _ink, fontStyle: FontStyle.italic)),
      Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: _muted)),
    ]),
  );

  Widget _searchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Container(height: 38,
      decoration: BoxDecoration(color: _paper, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0D0C0))),
      child: Row(children: [
        const SizedBox(width: 12),
        const Icon(Icons.search, size: 16, color: _muted),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _sc,
          style: const TextStyle(fontSize: 13, color: _ink),
          decoration: const InputDecoration(
            hintText: 'Search entries...', border: InputBorder.none,
            hintStyle: TextStyle(color: _muted, fontSize: 13),
            isDense: true, contentPadding: EdgeInsets.zero),
          onChanged: (q) => setState(() { _q = q; _filter(); }))),
        if (_q.isNotEmpty) GestureDetector(
          onTap: () { _sc.clear(); setState(() { _q = ''; _filter(); }); },
          child: const Padding(padding: EdgeInsets.all(10),
            child: Icon(Icons.close, size: 14, color: _muted))),
      ]),
    ),
  );

  Widget _moodBar() => SizedBox(height: 38, child: ListView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    children: [_chip(null, 'All'),
      ...Mood.values.map((m) => _chip(m, '${m.emoji} ${m.label}'))],
  ));

  Widget _chip(Mood? m, String l) {
    final on = _mood == m;
    return GestureDetector(
      onTap: () => setState(() { _mood = m; _filter(); }),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: on ? _light : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? const Color(0xFFB0998C) : const Color(0xFFD0C0B0))),
        child: Text(l, style: TextStyle(
          fontSize: 11.5, color: on ? const Color(0xFF5C4033) : _muted,
          fontWeight: on ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }

  // ── CALENDAR ─────────────────────────────────────────────────────────────
  Widget _calendar() {
    final yr = _calMonth.year;
    final mo = _calMonth.month;
    final fd = DateTime(yr, mo, 1).weekday % 7;
    final dim = DateTime(yr, mo + 1, 0).day;
    final days = <int>{};
    for (final e in _all) {
      if (e.date.year == yr && e.date.month == mo) days.add(e.date.day);
    }
    final selEntries = _all.where((e) =>
      e.date.year == _calSelected.year &&
      e.date.month == _calSelected.month &&
      e.date.day == _calSelected.day).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(children: [
      // Month nav
      Padding(padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 26),
            color: _ink,
            onPressed: () => setState(() =>
              _calMonth = DateTime(yr, mo - 1))),
          Expanded(child: Text(DateFormat('MMMM yyyy').format(_calMonth),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: _ink))),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 26),
            color: _ink,
            onPressed: () => setState(() =>
              _calMonth = DateTime(yr, mo + 1))),
        ])),
      // Day headers
      Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(children: ['S','M','T','W','T','F','S'].map((d) =>
          Expanded(child: Center(child: Text(d,
            style: const TextStyle(fontSize: 11, color: _muted,
              fontWeight: FontWeight.w700))))).toList())),
      const SizedBox(height: 4),
      // Day grid
      Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
        child: GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7, childAspectRatio: 1.15),
          itemCount: fd + dim,
          itemBuilder: (_, i) {
            if (i < fd) return const SizedBox();
            final d = i - fd + 1;
            final thisDate = DateTime(yr, mo, d);
            final now = DateTime.now();
            final isToday = d == now.day && mo == now.month && yr == now.year;
            final isSel = _calSelected.day == d &&
              _calSelected.month == mo && _calSelected.year == yr;
            final hasDot = days.contains(d);
            final isFuture = thisDate.isAfter(DateTime(now.year, now.month, now.day));
            return GestureDetector(
              onTap: () => setState(() => _calSelected = thisDate),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isToday ? _ink : isSel ? _copper : Colors.transparent,
                  borderRadius: BorderRadius.circular(8)),
                child: Stack(alignment: Alignment.center, children: [
                  Text('$d', style: TextStyle(
                    fontSize: 13,
                    fontWeight: isToday || isSel ? FontWeight.w700 : FontWeight.w400,
                    color: isToday || isSel
                      ? Colors.white
                      : isFuture ? _muted : _ink)),
                  if (hasDot && !isToday && !isSel)
                    Positioned(bottom: 2, child: Container(
                      width: 4, height: 4,
                      decoration: const BoxDecoration(
                        color: _copper, shape: BoxShape.circle))),
                ]),
              ),
            );
          })),
      const Divider(height: 16, color: Color(0xFFE0D0C0)),
      // Selected date header
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(children: [
          Text(DateFormat('EEEE, MMMM d').format(_calSelected),
            style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: _ink)),
          const Spacer(),
          Text('${selEntries.length} entr${selEntries.length == 1 ? "y" : "ies"}',
            style: const TextStyle(fontSize: 11, color: _muted)),
        ])),
      // Entries for selected day
      Expanded(child: selEntries.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('✦', style: TextStyle(fontSize: 24, color: Color(0xFFD0C0B0))),
            const SizedBox(height: 8),
            Text('No entries on ${DateFormat('MMM d').format(_calSelected)}',
              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: _muted)),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16, color: _copper),
              label: const Text('Add entry for this day',
                style: TextStyle(color: _copper)),
              onPressed: () => _picker(forDate: _calSelected)),
          ]))
        : ListView(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
            children: selEntries.map((e) => GestureDetector(
              onTap: () async {
                await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => DetailScreen(entry: e)));
                _load();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _paper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0D0C0))),
                child: Row(children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: e.type.bgColor,
                      borderRadius: BorderRadius.circular(9)),
                    child: Center(child: Text(e.type.icon,
                      style: const TextStyle(fontSize: 16)))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.title, style: const TextStyle(fontSize: 13,
                      fontStyle: FontStyle.italic, color: _ink)),
                    Text(DateFormat('h:mm a').format(e.date),
                      style: const TextStyle(fontSize: 10, color: _muted)),
                  ])),
                  const Icon(Icons.chevron_right, size: 16, color: _muted),
                ]),
              ),
            )).toList())),
    ]);
  }

  // ── MEMORIES ─────────────────────────────────────────────────────────────
  Widget _memories() {
    final now = DateTime.now();
    int streak = 0;
    var chk = DateTime(now.year, now.month, now.day);
    while (true) {
      final found = _all.any((e) =>
        e.date.year == chk.year &&
        e.date.month == chk.month &&
        e.date.day == chk.day);
      if (!found) break;
      streak++;
      chk = chk.subtract(const Duration(days: 1));
    }
    final oya = now.subtract(const Duration(days: 365));
    final oyaEntries = _all.where((e) =>
      e.date.month == oya.month && e.date.day == oya.day).toList();
    final rnd = List<Entry>.from(_all)..shuffle();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Memories',
          style: TextStyle(fontSize: 26, fontStyle: FontStyle.italic, color: _ink)),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _light, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Text('$streak', style: const TextStyle(
              fontSize: 32, color: _copper, fontStyle: FontStyle.italic)),
            const SizedBox(width: 14),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('day streak 🔥',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: Color(0xFF5C4033))),
              Text('Keep writing every day!',
                style: TextStyle(fontSize: 11, color: _muted)),
            ]),
          ])),
        const SizedBox(height: 14),
        Container(width: double.infinity, padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ON THIS DAY LAST YEAR',
              style: TextStyle(fontSize: 9, color: Color(0x55E8D5B7), letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(oyaEntries.isNotEmpty
              ? oyaEntries.first.title
              : 'Nothing written yet — come back next year.',
              style: const TextStyle(fontSize: 17, color: Color(0xFFE8D5B7),
                fontStyle: FontStyle.italic, height: 1.4)),
            const SizedBox(height: 6),
            Text(DateFormat('MMMM d, yyyy').format(oya),
              style: const TextStyle(fontSize: 10, color: Color(0x44E8D5B7))),
          ])),
        const SizedBox(height: 16),
        if (_all.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(20),
            child: Text('Start writing to see your memories here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: _muted))))
        else ...[
          const Text('Random highlights',
            style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: _ink)),
          const SizedBox(height: 10),
          ...rnd.take(4).map((e) => GestureDetector(
            onTap: () async {
              await Navigator.push(context,
                MaterialPageRoute(builder: (_) => DetailScreen(entry: e)));
              _load();
            },
            child: Container(margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _paper, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0D0C0))),
              child: Row(children: [
                Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: e.type.bgColor,
                    borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text(e.type.icon,
                    style: const TextStyle(fontSize: 15)))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.title, style: const TextStyle(fontSize: 12.5,
                    fontStyle: FontStyle.italic, color: _ink)),
                  Text(e.dateLabel, style: const TextStyle(fontSize: 10, color: _muted)),
                ])),
              ])),
          )),
        ],
      ]),
    );
  }

  Widget _settingsTab() => SettingsScreen(onChanged: _load);

  void _picker({DateTime? forDate}) => showModalBottomSheet(
    context: context,
    backgroundColor: _paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('New entry',
            style: TextStyle(fontSize: 17, fontStyle: FontStyle.italic, color: _ink)),
          if (forDate != null) ...[
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _light, borderRadius: BorderRadius.circular(20)),
              child: Text('for ${DateFormat("MMM d").format(forDate)}',
                style: const TextStyle(fontSize: 11, color: _copper))),
          ],
        ]),
        const SizedBox(height: 16),
        Row(children: EntryType.values.map((t) => Expanded(
          child: GestureDetector(
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => ComposeScreen(type: t, forDate: forDate)));
              _load();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: t.bgColor, borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text(t.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 5),
                Text(t.label, style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w600, color: t.color)),
              ]),
            ),
          ),
        )).toList()),
      ]),
    )),
  );
}
