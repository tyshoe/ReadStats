import 'package:flutter/material.dart';
import '/data/services/reading_timer_service.dart';
import '/data/repositories/session_repository.dart';
import '/data/repositories/book_repository.dart';
import '/data/database/database_helper.dart';
import '/viewmodels/SettingsViewModel.dart';
import 'rate_book_dialog.dart';
import '../post_session_page.dart';
import '../fullscreen_timer_page.dart';
import '/ui/widgets/book_picker_sheet.dart';
import '/ui/widgets/book_cover.dart';

class ReadingTimerWidget extends StatefulWidget {
  final ReadingTimerService timerService;
  final List<Map<String, dynamic>> books;
  final Map<String, dynamic>? defaultBook;
  final SessionRepository sessionRepository;
  final BookRepository bookRepository;
  final SettingsViewModel settingsViewModel;
  final VoidCallback onSessionSaved;

  const ReadingTimerWidget({
    super.key,
    required this.timerService,
    required this.books,
    this.defaultBook,
    required this.sessionRepository,
    required this.bookRepository,
    required this.settingsViewModel,
    required this.onSessionSaved,
  });

  @override
  State<ReadingTimerWidget> createState() => _ReadingTimerWidgetState();
}

class _ReadingTimerWidgetState extends State<ReadingTimerWidget> {
  Map<String, dynamic>? _selectedBook;

  @override
  void initState() {
    super.initState();
    widget.timerService.addListener(_onTimerChanged);
    _syncSelectedBook();
  }

  @override
  void didUpdateWidget(covariant ReadingTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timerService != widget.timerService) {
      oldWidget.timerService.removeListener(_onTimerChanged);
      widget.timerService.addListener(_onTimerChanged);
    }
    if (oldWidget.books != widget.books) _syncSelectedBook();
    // When a session is logged elsewhere (e.g. the session form), the
    // most-recent book changes — reflect it in the idle timer.
    if (oldWidget.defaultBook?['id'] != widget.defaultBook?['id'] &&
        widget.timerService.bookId == null &&
        widget.defaultBook != null) {
      setState(() => _selectedBook = widget.defaultBook);
    }
  }

  @override
  void dispose() {
    widget.timerService.removeListener(_onTimerChanged);
    super.dispose();
  }

  void _onTimerChanged() => _syncSelectedBook();

  void _syncSelectedBook() {
    final bookId = widget.timerService.bookId;
    if (bookId != null && _selectedBook?['id'] != bookId) {
      final match = widget.books.where((b) => b['id'] == bookId).firstOrNull;
      if (match != null) setState(() => _selectedBook = match);
    } else if (bookId == null && _selectedBook == null && widget.defaultBook != null) {
      setState(() => _selectedBook = widget.defaultBook);
    }
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showBookPicker() async {
    // Finished books are closed to new sessions, so they're not offered here.
    final sorted = widget.books
        .where((b) => DatabaseHelper.acceptsSessions(b['shelf_id'] as int?))
        .toList();
    sorted.sort((a, b) {
      const order = {1: 0, 2: 1, 4: 2, 3: 3};
      final sa = order[a['shelf_id'] as int? ?? 0] ?? 99;
      final sb = order[b['shelf_id'] as int? ?? 0] ?? 99;
      if (sa != sb) return sa.compareTo(sb);
      return (a['title'] as String? ?? '').compareTo(b['title'] as String? ?? '');
    });

    final result = await showBookPickerSheet(
      context: context,
      books: sorted,
      title: 'Select a book',
    );

    if (result != null) setState(() => _selectedBook = result);
  }

  void _handleSessionSaved() {
    setState(() => _selectedBook = null);
    widget.onSessionSaved();
  }

  void _openFullscreen() async {
    final book = _selectedBook;
    if (book == null || !mounted) return;

    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenTimerPage(
          book: book,
          timerService: widget.timerService,
          sessionRepository: widget.sessionRepository,
          bookRepository: widget.bookRepository,
          settingsViewModel: widget.settingsViewModel,
          onSessionSaved: _handleSessionSaved,
        ),
      ),
    );

    if (result != null && mounted) {
      await showRatingDialogForBook(
        context: context,
        book: result,
        bookRepository: widget.bookRepository,
        settingsViewModel: widget.settingsViewModel,
      );
    }
  }

  void _handleStop() async {
    final book = _selectedBook;
    if (book == null || !mounted) return;

    // Pause rather than stop so the user can resume from the save page.
    if (widget.timerService.state == TimerState.running) {
      widget.timerService.pause();
    }

    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => PostSessionPage(
          book: book,
          timerService: widget.timerService,
          sessionRepository: widget.sessionRepository,
          bookRepository: widget.bookRepository,
          settingsViewModel: widget.settingsViewModel,
          onSaved: _handleSessionSaved,
        ),
      ),
    );

    // If the user resumed instead of saving, the timer is running again — nothing to do.
    // If they saved and the book was marked finished, result is the book map.
    if (result != null && mounted) {
      await showRatingDialogForBook(
        context: context,
        book: result,
        bookRepository: widget.bookRepository,
        settingsViewModel: widget.settingsViewModel,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.timerService,
      builder: (context, _) {
        final state = widget.timerService.state;
        final theme = Theme.of(context);
        final accent = widget.settingsViewModel.accentColorNotifier.value;

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: state == TimerState.idle
              ? _buildIdleContent(theme, accent)
              : _buildActiveContent(theme, accent, state),
        );
      },
    );
  }

  Widget _buildIdleContent(ThemeData theme, Color accent) {
    final book = _selectedBook;
    final hasBook = book != null;
    final hasCover = book?['cover_path'] != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: widget.books.isEmpty ? null : _showBookPicker,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (hasCover) ...[
                    BookCover(
                      path: book!['cover_path'] as String,
                      shape: book['cover_shape'] as int?,
                      width: 42,
                      borderRadius: 4,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book?['title'] ??
                              (widget.books.isEmpty ? 'Add a book first' : 'Tap to choose...'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: hasBook ? FontWeight.w600 : FontWeight.normal,
                            color: hasBook
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface.withAlpha(140),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasBook && (book['author'] as String?)?.isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(
                            book['author'] as String,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(140),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.unfold_more,
                    size: 20,
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: (_selectedBook == null || widget.books.isEmpty)
                ? null
                : () => widget.timerService.start(_selectedBook!['id']),
            icon: const Icon(Icons.play_arrow, size: 20),
            label: const Text('Start Reading'),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              disabledBackgroundColor: accent.withAlpha(80),
              minimumSize: const Size.fromHeight(48),
              textStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveContent(ThemeData theme, Color accent, TimerState state) {
    final elapsed = widget.timerService.elapsed;
    final book = _selectedBook;
    final isRunning = state == TimerState.running;
    final coverPath = book?['cover_path'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (coverPath != null)
                BookCover(
                  path: coverPath,
                  shape: book?['cover_shape'] as int?,
                  width: 72,
                ),
              if (coverPath != null) const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatElapsed(elapsed),
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: [const FontFeature.tabularFigures()],
                          color: theme.colorScheme.onSurface,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book?['title'] ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withAlpha(160),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((book?['author'] as String?)?.isNotEmpty == true)
                      Text(
                        book!['author'] as String,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(100),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Full screen',
                icon: const Icon(Icons.open_in_full, size: 20),
                color: theme.colorScheme.onSurface.withAlpha(140),
                visualDensity: VisualDensity.compact,
                onPressed: _openFullscreen,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isRunning)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.timerService.pause,
                icon: const Icon(Icons.pause, size: 20),
                label: const Text('Pause'),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  minimumSize: const Size.fromHeight(52),
                  textStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: FilledButton.icon(
                    onPressed: widget.timerService.resume,
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: const Text('Resume'),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      minimumSize: const Size.fromHeight(52),
                      textStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    onPressed: _handleStop,
                    icon: const Icon(Icons.flag, size: 20),
                    label: const Text('Finish'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: BorderSide(color: theme.colorScheme.outline.withAlpha(80)),
                      textStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

