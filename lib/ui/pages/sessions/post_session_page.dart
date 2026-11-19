import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:read_stats/data/models/book_type.dart';
import 'package:read_stats/data/models/session.dart';
import 'package:read_stats/data/models/shelf.dart';
import 'package:read_stats/data/repositories/book_repository.dart';
import 'package:read_stats/data/repositories/session_repository.dart';
import 'package:read_stats/data/services/analytics_service.dart';
import 'package:read_stats/data/services/reading_timer_service.dart';
import 'package:read_stats/ui/pages/sessions/widgets/reading_dates_row.dart';
import 'package:read_stats/ui/pages/sessions/widgets/session_pages_field.dart';
import 'package:read_stats/ui/pages/sessions/widgets/session_position_field.dart';
import 'package:read_stats/ui/settings_view_model.dart';
import 'package:read_stats/ui/widgets/book_cover.dart';
import 'package:read_stats/ui/widgets/field_decoration.dart';

class PostSessionPage extends StatefulWidget {
  final Map<String, dynamic> book;
  final ReadingTimerService timerService;
  final SessionRepository sessionRepository;
  final BookRepository bookRepository;
  final SettingsViewModel settingsViewModel;
  final VoidCallback onSaved;

  const PostSessionPage({
    super.key,
    required this.book,
    required this.timerService,
    required this.sessionRepository,
    required this.bookRepository,
    required this.settingsViewModel,
    required this.onSaved,
  });

  @override
  State<PostSessionPage> createState() => _PostSessionPageState();
}

class _PostSessionPageState extends State<PostSessionPage> {
  final _pages = SessionPages();
  final _position = SessionPosition();
  // The shelf the book was headed for before reaching its last page moved it
  // to Finished, to put back if the page is corrected.
  int? _shelfBeforeLastPage;
  bool _finishedByLastPage = false;
  final _notesController = TextEditingController();
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();
  late int? _targetShelfId;
  bool _isSaving = false;
  bool _isEditingDuration = false;

  // The book's own reading dates, shown and set here the same way the session
  // form does it.
  final _readingDates = ReadingDates();

  /// The day the session started on — what the shelf fills empty dates with.
  late final DateTime _sessionDay;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen('post_session');
    _targetShelfId = widget.book['shelf_id'] as int?;
    DateTime? parse(Object? value) =>
        value is String ? DateTime.tryParse(value) : null;
    _readingDates.load(
      parse(widget.book['date_started']),
      parse(widget.book['date_finished']),
    );
    final started = widget.timerService.startedAt ?? DateTime.now();
    _sessionDay = DateTime(started.year, started.month, started.day);
    _fillDurationFields(_timerMinutes);
    _pages.bookPageCount = _bookPageCount;
    _position.bookMinutes = widget.book['duration_minutes'] as int?;
    _presetFirstSession();
    _suggestStartPage();
    _suggestStartPosition();
  }

  int? get _bookPageCount => widget.book['page_count'] as int?;

  /// For an audiobook, fills the start time with the one the last session
  /// stopped on, so only the time reached this time is left to type. The
  /// session's length stays the timer's: the times record where the reader
  /// is in the book, which at another speed isn't how long they listened.
  Future<void> _suggestStartPosition() async {
    if (widget.book['book_type_id'] != BookType.audiobook) return;
    final at = widget.timerService.startedAt ?? DateTime.now();
    final bookId = widget.book['id'] as int;
    final around = await widget.sessionRepository.getMinutesAround(bookId, at);
    final last = await widget.sessionRepository.getLastPosition(bookId, at);
    if (!mounted) return;
    setState(() {
      _position.minutesBefore = around.before;
      _position.minutesAfter = around.after;
      _position.suggestStart(
        lastStop: last.lastStop,
        minutesSince: last.minutesSince,
        countsDown: last.countsDown,
        byDuration: last.byDuration,
      );
    });
  }

  /// Fills "From page" with the page the last session stopped on, so only
  /// the page reached this time is left to type, and loads the pages logged
  /// before, to square the session that finishes the book with the book's
  /// length. A book read to its end starts over from the beginning.
  Future<void> _suggestStartPage() async {
    if (widget.book['book_type_id'] == BookType.audiobook) return;
    final bookId = widget.book['id'] as int;
    final at = widget.timerService.startedAt ?? DateTime.now();
    const suggest = true;
    final last = await widget.sessionRepository.getLastPage(bookId, at);
    final around = await widget.sessionRepository.getPagesAround(bookId, at);
    if (!mounted) return;
    final total = _bookPageCount ?? 0;
    // Read to its end already, by pages logged — not by page number, which
    // needn't run from 1 to the page count.
    final finished = total > 0 && around.pagesBefore >= total;
    setState(() {
      _pages.pagesBefore = around.pagesBefore;
      _pages.pagesAfter = around.pagesAfter;
      _pages.isLastSession = !around.hasLater;
      if (last case final last? when !finished) {
        _pages.suggestStart(last.page, exact: last.exact);
      } else if (suggest) {
        _pages.suggestStart(1, exact: true);
      }
    });
  }

  /// Reaching the end of the book — its last page, or no time left in an
  /// audiobook — offers the Finished shelf, and takes the offer back if what
  /// was typed is corrected.
  void _onPagesChanged() {
    final reached = widget.book['book_type_id'] == BookType.audiobook
        ? _position.reachesEnd
        : _pages.reachesEnd;
    if (reached &&
        !_finishedByLastPage &&
        _targetShelfId != Shelf.finished) {
      _shelfBeforeLastPage = _targetShelfId;
      _finishedByLastPage = true;
      _selectShelf(Shelf.finished);
    } else if (!reached && _finishedByLastPage) {
      _finishedByLastPage = false;
      final before = _shelfBeforeLastPage;
      if (_targetShelfId == Shelf.finished && before != null) {
        _selectShelf(before);
        return;
      }
      setState(() {});
    } else {
      setState(() {});
    }
  }

  /// A book's first session is when it gets started: the shelf opens on
  /// Reading and Started fills in, both visible and changeable before saving.
  Future<void> _presetFirstSession() async {
    final bookId = widget.book['id'] as int;
    final sessions = await widget.sessionRepository.getSessionsByBookId(bookId);
    // Leave it if the reader already picked a shelf while this was loading.
    if (sessions.isNotEmpty ||
        !mounted ||
        _targetShelfId != widget.book['shelf_id']) {
      return;
    }
    _selectShelf(Shelf.currentlyReading);
  }

  /// The shelf fills the date fields with the session's day — a book read in
  /// one sitting gets the same date for both. See [ReadingDates.selectShelf].
  void _selectShelf(int shelfId) {
    setState(() {
      _targetShelfId = shelfId;
      _readingDates.selectShelf(shelfId, _sessionDay);
    });
  }

  Future<void> _pickReadingDate(bool isStart) async {
    final date = await pickReadingDate(
      context,
      isStart: isStart,
      started: _readingDates.started,
      finished: _readingDates.finished,
      fallback: _sessionDay,
    );
    if (date == null) return;
    setState(() => isStart
        ? _readingDates.pickStarted(date)
        : _readingDates.pickFinished(date));
  }

  void _clearReadingDate(bool isStart) {
    setState(() => isStart
        ? _readingDates.clearStarted()
        : _readingDates.clearFinished());
  }

  @override
  void dispose() {
    _pages.dispose();
    _position.dispose();
    _notesController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  /// What the timer recorded, in the whole minutes a session is stored in.
  int get _timerMinutes {
    final elapsed = widget.timerService.elapsed;
    return elapsed.inSeconds > 0 ? (elapsed.inSeconds / 60).round() : 0;
  }

  /// What the fields currently say — this is what gets saved, whether or not
  /// the user touched it.
  int get _enteredMinutes {
    final h = int.tryParse(_hoursController.text) ?? 0;
    final m = int.tryParse(_minutesController.text) ?? 0;
    return h * 60 + m;
  }

  void _fillDurationFields(int minutes) {
    _hoursController.text = minutes >= 60 ? '${minutes ~/ 60}' : '';
    _minutesController.text = '${minutes % 60}';
  }

  void _resetDuration() {
    setState(() => _fillDurationFields(_timerMinutes));
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _toggleDurationEditor() {
    if (_isEditingDuration) {
      FocusManager.instance.primaryFocus?.unfocus();
      // An empty field reads as zero everywhere else; put the number back so
      // the collapsed row can't imply a value the fields don't hold.
      _fillDurationFields(_enteredMinutes);
      setState(() => _isEditingDuration = false);
      return;
    }

    // Minutes is the field that gets corrected; open on it with the value
    // selected so typing replaces it.
    _minutesController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _minutesController.text.length,
    );
    setState(() => _isEditingDuration = true);
  }

  // Mirrors the duration that will actually be saved (rounded to the
  // nearest minute) and the format used to display it elsewhere in the app.
  String _formatElapsed(Duration d) {
    final minutes = d.inSeconds > 0 ? (d.inSeconds / 60).round() : 0;
    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainingMinutes}m';
  }

  Widget _durationField({
    required TextEditingController controller,
    required String label,
    required ThemeData theme,
    int? clampTo,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      onChanged: (value) {
        if (clampTo != null && (int.tryParse(value) ?? 0) > clampTo) {
          controller.text = '$clampTo';
        }
        setState(() {});
      },
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: filledFieldDecoration(theme).copyWith(
        labelText: label,
      ),
    );
  }

  void _goBack() {
    Navigator.pop(context);
  }

  Future<bool> _confirmDiscard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard session?'),
        content: const Text('Your reading progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Discard',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    return confirm == true;
  }

  Future<void> _save() async {
    if (widget.book['book_type_id'] == BookType.audiobook && _position.isBackwards) return;
    setState(() => _isSaving = true);
    try {
      // Read the fields before stopping — they hold the timer's own figure
      // unless the user corrected it.
      final durationMinutes = _enteredMinutes > 0 ? _enteredMinutes : null;
      // The session belongs to the day it started on, not the day the reader
      // got round to saving it — the two differ whenever reading runs past
      // midnight. Also read before stopping, which clears it. The fallback
      // covers a session saved with no timer behind it.
      final sessionDate = widget.timerService.startedAt ?? DateTime.now();
      widget.timerService.stop();
      final isAudiobook = widget.book['book_type_id'] == BookType.audiobook;

      final session = Session(
        bookId: widget.book['id'],
        pagesRead: isAudiobook ? null : _pages.pagesRead,
        startPage: isAudiobook ? null : _pages.startPage,
        endPage: isAudiobook ? null : _pages.endPage,
        startPosition: isAudiobook ? _position.startPosition : null,
        endPosition: isAudiobook ? _position.endPosition : null,
        durationMinutes: durationMinutes,
        date: sessionDate.toIso8601String(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      await widget.sessionRepository.addSession(session);

      final originalShelfId = widget.book['shelf_id'] as int?;
      final isFinalSession = _targetShelfId == Shelf.finished;

      // Only the dates the user saw change are written — the shelf filled
      // them in on screen, so nothing is set behind the reader's back.
      await widget.bookRepository.updateReadingDates(
        widget.book['id'],
        _readingDates.changes,
      );

      if (_targetShelfId != null && _targetShelfId != originalShelfId) {
        await widget.bookRepository.updateBookShelf(widget.book['id'], _targetShelfId!);
      }

      final bookTypeId = widget.book['book_type_id'] as int?;
      AnalyticsService.instance
          .sessionLogged(method: 'timer', bookTypeId: bookTypeId);
      if (isFinalSession && originalShelfId != Shelf.finished) {
        AnalyticsService.instance.bookFinished(bookTypeId: bookTypeId);
      }

      widget.onSaved();
      if (mounted) Navigator.pop(context, isFinalSession ? widget.book : null);
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.settingsViewModel.accentColorNotifier.value;
    final isAudiobook = widget.book['book_type_id'] == BookType.audiobook;
    final elapsed = widget.timerService.elapsed;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Save Session'),
          backgroundColor: theme.colorScheme.surfaceContainer,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: NotificationListener<UserScrollNotification>(
                onNotification: (n) {
                  if (n.direction != ScrollDirection.idle) {
                    FocusScope.of(context).unfocus();
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if ((widget.book['cover_path'] as String?) != null) ...[
                            BookCover(
                              path: widget.book['cover_path'] as String,
                              shape: widget.book['cover_shape'] as int?,
                              width: 72,
                            ),
                            const SizedBox(width: 14),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.book['title'] ?? '',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if ((widget.book['author'] as String?)?.isNotEmpty == true)
                                  Text(
                                    widget.book['author'] as String,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withAlpha(140),
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Tracks the duration fields, so the
                                    // headline always reads as what gets saved.
                                    Text(
                                      _formatElapsed(
                                          Duration(minutes: _enteredMinutes)),
                                      style:
                                          theme.textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: _isSaving
                                          ? null
                                          : _toggleDurationEditor,
                                      borderRadius: BorderRadius.circular(20),
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Icon(
                                          _isEditingDuration
                                              ? Icons.check
                                              : Icons.edit_outlined,
                                          size: 16,
                                          color: _isEditingDuration
                                              ? accent
                                              : theme
                                                  .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // With the fields hidden, this is the only
                                // sign the saved length isn't the timer's.
                                if (!_isEditingDuration &&
                                    _enteredMinutes != _timerMinutes)
                                  Text(
                                    'Edited · timer ran ${_formatElapsed(elapsed)}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),

                      if (_isEditingDuration) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text('Duration',
                                  style: theme.textTheme.bodyMedium),
                            ),
                            // Only offered once the fields differ from what the
                            // timer recorded — nothing to reset to before that.
                            if (_enteredMinutes != _timerMinutes)
                              TextButton(
                                onPressed: _resetDuration,
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Reset to ${_formatElapsed(elapsed)}',
                                  style: theme.textTheme.labelMedium,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _durationField(
                                controller: _hoursController,
                                label: 'Hours',
                                theme: theme,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _durationField(
                                controller: _minutesController,
                                label: 'Minutes',
                                theme: theme,
                                // Overflow belongs in the hours field.
                                clampTo: 59,
                                autofocus: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      if (!isAudiobook) ...[
                        SessionPagesField(
                          pages: _pages,
                          onChanged: _onPagesChanged,
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        SessionPositionField(
                          position: _position,
                          durationMinutes: _enteredMinutes,
                          onChanged: _onPagesChanged,
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextField(
                        controller: _notesController,
                        minLines: 3,
                        maxLines: null,
                        onChanged: (_) => setState(() {}),
                        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                        decoration: filledFieldDecoration(theme).copyWith(
                          labelText: 'Notes',
                          hintText: 'Reflect on your reading session...',
                          alignLabelWithHint: true,
                          suffixIcon: _notesController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(() => _notesController.clear()),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text('Move to shelf', style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            for (final shelf in [
                              (id: Shelf.wantToRead, label: 'To Read', icon: Icons.bookmark),
                              (id: Shelf.currentlyReading, label: 'Reading', icon: Icons.menu_book_rounded),
                              (id: Shelf.finished, label: 'Finished', icon: Icons.check),
                              (id: Shelf.unfinished, label: 'Unfinished', icon: Icons.do_not_disturb_on),
                            ])
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _selectShelf(shelf.id),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _targetShelfId == shelf.id
                                          ? theme.colorScheme.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          shelf.icon,
                                          size: 18,
                                          color: _targetShelfId == shelf.id
                                              ? theme.colorScheme.onPrimary
                                              : theme.colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          shelf.label,
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: _targetShelfId == shelf.id
                                                ? theme.colorScheme.onPrimary
                                                : theme.colorScheme.onSurfaceVariant,
                                            fontWeight: _targetShelfId == shelf.id
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ReadingDatesRow(
                        started: _readingDates.started,
                        finished: _readingDates.finished,
                        onPickStarted: () => _pickReadingDate(true),
                        onPickFinished: () => _pickReadingDate(false),
                        onClearStarted: () => _clearReadingDate(true),
                        onClearFinished: () => _clearReadingDate(false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : () async {
                          if (await _confirmDiscard()) {
                            widget.timerService.stop();
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error.withAlpha(120)),
                        ),
                        child: const Text('Discard'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : const Text('Save Session'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
