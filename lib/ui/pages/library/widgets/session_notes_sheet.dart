import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/data/database/database_helper.dart';

Future<void> showSessionNotesSheet({
  required BuildContext context,
  required Map<String, dynamic> book,
  required String dateFormatString,
  required Color accentColor,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SessionNotesSheet(
      book: book,
      dateFormatString: dateFormatString,
      accentColor: accentColor,
    ),
  );
}

class _SessionNotesSheet extends StatefulWidget {
  final Map<String, dynamic> book;
  final String dateFormatString;
  final Color accentColor;

  const _SessionNotesSheet({
    required this.book,
    required this.dateFormatString,
    required this.accentColor,
  });

  @override
  State<_SessionNotesSheet> createState() => _SessionNotesSheetState();
}

class _SessionNotesSheetState extends State<_SessionNotesSheet> {
  List<Map<String, dynamic>> _notedSessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await DatabaseHelper().getSessionsByBookId(widget.book['id']);
    final withNotes = all
        .where((s) => (s['notes'] as String?)?.trim().isNotEmpty == true)
        .toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    if (mounted) setState(() { _notedSessions = withNotes; _loading = false; });
  }

  String _formatDate(String raw) {
    try {
      return DateFormat(widget.dateFormatString).format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _sessionMeta(Map<String, dynamic> s) {
    final parts = <String>[];
    final pages = s['pages_read'] as int?;
    final mins = s['duration_minutes'] as int?;
    if (pages != null && pages > 0) parts.add('$pages pages');
    if (mins != null && mins > 0) {
      final h = mins ~/ 60;
      final m = mins % 60;
      if (h > 0 && m > 0) parts.add('${h}h ${m}m');
      else if (h > 0) parts.add('${h}h');
      else parts.add('${m}m');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: widget.book['cover_path'] != null
                      ? Image.file(
                          File(widget.book['cover_path'] as String),
                          width: 52,
                          height: 78,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 52,
                          height: 78,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(Icons.book,
                              color: theme.colorScheme.onSurfaceVariant, size: 28),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reading Notes',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.book['title'] ?? '',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((widget.book['author'] as String?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.book['author'] as String,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _notedSessions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.notes_rounded,
                                  size: 48,
                                  color: theme.colorScheme.onSurfaceVariant.withAlpha(100)),
                              const SizedBox(height: 12),
                              Text(
                                'No notes yet',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add notes when logging a session.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + safeBottom),
                        itemCount: _notedSessions.length,
                        itemBuilder: (_, i) {
                          final s = _notedSessions[i];
                          final isLast = i == _notedSessions.length - 1;
                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Timeline spine
                                SizedBox(
                                  width: 40,
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(top: 5),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      if (!isLast)
                                        Expanded(
                                          child: Container(
                                            width: 1,
                                            color: theme.colorScheme.onSurfaceVariant.withAlpha(50),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Content
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              _formatDate(s['date'] as String),
                                              style: theme.textTheme.labelMedium?.copyWith(
                                                color: theme.colorScheme.onSurfaceVariant,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _sessionMeta(s),
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          s['notes'] as String,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class SessionNotesContent extends StatefulWidget {
  final int bookId;
  final String dateFormatString;

  const SessionNotesContent({
    super.key,
    required this.bookId,
    required this.dateFormatString,
  });

  @override
  State<SessionNotesContent> createState() => _SessionNotesContentState();
}

class _SessionNotesContentState extends State<SessionNotesContent> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await DatabaseHelper().getSessionsByBookId(widget.bookId);
    final withNotes = all
        .where((s) => (s['notes'] as String?)?.trim().isNotEmpty == true)
        .toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    if (mounted) setState(() { _sessions = withNotes; _loading = false; });
  }

  String _formatDate(String raw) {
    try {
      return DateFormat(widget.dateFormatString).format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _meta(Map<String, dynamic> s) {
    final parts = <String>[];
    final pages = s['pages_read'] as int?;
    final mins = s['duration_minutes'] as int?;
    if (pages != null && pages > 0) parts.add('$pages pages');
    if (mins != null && mins > 0) {
      final h = mins ~/ 60;
      final m = mins % 60;
      if (h > 0 && m > 0) parts.add('${h}h ${m}m');
      else if (h > 0) parts.add('${h}h');
      else parts.add('${m}m');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notes_rounded, size: 48,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(100)),
              const SizedBox(height: 12),
              Text('No notes yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('Add notes when logging a session.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(160))),
            ],
          ),
        ),
      );
    }

    return Scrollbar(
      controller: _scrollController,
      child: ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      itemCount: _sessions.length,
      itemBuilder: (_, i) {
        final s = _sessions[i];
        final isLast = i == _sessions.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 1,
                          color: theme.colorScheme.onSurfaceVariant.withAlpha(50),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(_formatDate(s['date'] as String),
                              style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text(_meta(s),
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(s['notes'] as String, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
    );
  }
}
