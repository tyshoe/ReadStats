import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/data/database/database_helper.dart';
import '/data/repositories/session_repository.dart';
import '/data/repositories/book_repository.dart';
import '/viewmodels/SettingsViewModel.dart';
import '../../sessions/session_form_page.dart';

/// List of every reading session logged for a single book. Tapping a session
/// opens it for editing. A book-filtered version of the Sessions page list.
class BookSessionsContent extends StatefulWidget {
  final Map<String, dynamic> book;
  final String dateFormatString;
  final SettingsViewModel settingsViewModel;

  /// Called after a session is edited, so the parent can refresh.
  final VoidCallback onChanged;

  /// When true, shows an "Expand" action that opens the full list in a tall
  /// sheet. The expanded sheet embeds this widget with [expandable] false.
  final bool expandable;

  const BookSessionsContent({
    super.key,
    required this.book,
    required this.dateFormatString,
    required this.settingsViewModel,
    required this.onChanged,
    this.expandable = true,
  });

  @override
  State<BookSessionsContent> createState() => _BookSessionsContentState();
}

class _BookSessionsContentState extends State<BookSessionsContent> {
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
    final all = List<Map<String, dynamic>>.from(
        await DatabaseHelper().getSessionsByBookId(widget.book['id'] as int));
    all.sort((a, b) =>
        (b['date'] as String? ?? '').compareTo(a['date'] as String? ?? ''));
    if (mounted) {
      setState(() {
        _sessions = all;
        _loading = false;
      });
    }
  }

  Future<void> _editSession(Map<String, dynamic> session) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => SessionFormPage(
          session: session,
          book: widget.book,
          availableBooks: const [],
          onSave: widget.onChanged,
          settingsViewModel: widget.settingsViewModel,
          sessionRepository: SessionRepository(DatabaseHelper()),
          bookRepository: BookRepository(DatabaseHelper()),
        ),
        transitionsBuilder: (_, animation, _, child) {
          final offsetAnimation = animation.drive(
            Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeInOut)),
          );
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
    await _load();
  }

  Future<void> _openExpanded() async {
    final theme = Theme.of(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final t = Theme.of(ctx);
        return SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.85,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Text('Sessions',
                        style: t.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Text('${_sessions.length}',
                        style: t.textTheme.titleMedium?.copyWith(
                            color: t.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: BookSessionsContent(
                  book: widget.book,
                  dateFormatString: widget.dateFormatString,
                  settingsViewModel: widget.settingsViewModel,
                  onChanged: widget.onChanged,
                  expandable: false,
                ),
              ),
            ],
          ),
        );
      },
    );
    // Reflect any edits made inside the expanded sheet.
    await _load();
  }

  String _formatDate(String raw) {
    try {
      return DateFormat(widget.dateFormatString).format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _durationStr(int minutes) {
    if (minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  Widget _sessionCard(BuildContext context, Map<String, dynamic> s) {
    final theme = Theme.of(context);
    final onVariant = theme.colorScheme.onSurfaceVariant;
    final pages = (s['pages_read'] as int?) ?? 0;
    final minutes = (s['duration_minutes'] as int?) ?? 0;
    final notes = (s['notes'] as String?)?.trim() ?? '';
    final duration = _durationStr(minutes);
    final secondary = [
      if (pages > 0) '$pages ${pages == 1 ? 'page' : 'pages'}',
      if (pages > 0 && minutes > 0) '${(pages / minutes).toStringAsFixed(1)}/min',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _editSession(s),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: date + note
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(s['date'] as String? ?? ''),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          notes,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurface),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Right: data cluster (duration headline, pages/pace beneath)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (duration.isNotEmpty)
                      Text(duration,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    if (secondary.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(secondary,
                          style: theme.textTheme.labelSmall?.copyWith(color: onVariant)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
              Icon(Icons.menu_book_rounded,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text('No sessions yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('Log a session to see it here.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
            ],
          ),
        ),
      );
    }

    final list = Scrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(16, widget.expandable ? 4 : 16, 16, 16),
        itemCount: _sessions.length,
        itemBuilder: (ctx, i) => _sessionCard(ctx, _sessions[i]),
      ),
    );

    if (!widget.expandable) return list;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
          child: Row(
            children: [
              Text(
                '${_sessions.length} ${_sessions.length == 1 ? 'session' : 'sessions'}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _openExpanded,
                icon: const Icon(Icons.open_in_full),
                iconSize: 18,
                color: theme.colorScheme.onSurfaceVariant,
                visualDensity: VisualDensity.compact,
                tooltip: 'Expand',
              ),
            ],
          ),
        ),
        Expanded(child: list),
      ],
    );
  }
}
