import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/book_picker_sheet.dart';
import '../../widgets/book_selector_tile.dart';
import 'session_book_options.dart';
import 'widgets/reading_dates_row.dart';
import 'widgets/session_pages_field.dart';
import 'widgets/session_position_field.dart';
import 'package:intl/intl.dart';
import '/data/models/session.dart';
import '/data/repositories/session_repository.dart';
import '/data/repositories/book_repository.dart';
import '/data/database/database_helper.dart';
import '/data/services/rating_service.dart';
import '/viewmodels/settings_view_model.dart';

class SessionFormPage extends StatefulWidget {
  final Map<String, dynamic>? session;
  final Map<String, dynamic>? book;
  final List<Map<String, dynamic>> availableBooks;
  final Function() onSave;
  final SettingsViewModel settingsViewModel;
  final SessionRepository sessionRepository;
  final BookRepository bookRepository;
  final bool isEditing;

  const SessionFormPage({
    super.key,
    this.session,
    this.book,
    required this.availableBooks,
    required this.onSave,
    required this.settingsViewModel,
    required this.sessionRepository,
    required this.bookRepository,
  }) : isEditing = session != null;

  @override
  State<SessionFormPage> createState() => _SessionFormPageState();
}

class _SessionFormPageState extends State<SessionFormPage> {
  final _pages = SessionPages();
  final _position = SessionPosition();
  // The shelf the book was headed for before reaching its last page moved it
  // to Finished, to put back if the page is corrected.
  int? _shelfBeforeLastPage;
  bool _finishedByLastPage = false;
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _minutesController = TextEditingController();
  final TextEditingController _startHoursController = TextEditingController();
  final TextEditingController _startMinutesController = TextEditingController();
  final TextEditingController _endHoursController = TextEditingController();
  final TextEditingController _endMinutesController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late DateTime _sessionDate;
  int? _targetShelfId;
  bool _showTimeRange = false;
  String? _timeRangeError;
  Map<String, dynamic>? _selectedBook;

  // The book's own reading dates, shown here because this is where they get
  // set. They used to be written invisibly, inferred from a shelf move.
  final _readingDates = ReadingDates();

  @override
  void initState() {
    super.initState();

    if (widget.isEditing) {
      final editDuration = widget.session!['duration_minutes'] as int?;
      if (editDuration != null && editDuration > 0) {
        _hoursController.text = (editDuration ~/ 60).toString();
        _minutesController.text = (editDuration % 60).toString();
      }

      _pages.load(
        startPage: widget.session!['start_page'] as int?,
        endPage: widget.session!['end_page'] as int?,
        pagesRead: widget.session!['pages_read'] as int?,
      );
      _sessionDate = DateTime.parse(widget.session!['date']);
      _notesController.text = widget.session!['notes'] ?? '';
      _selectedBook = widget.book;
      _pages.bookPageCount = _bookPageCount;
      _position.bookMinutes = _bookMinutes;
      _position.load(
        startPosition: widget.session!['start_position'] as int?,
        endPosition: widget.session!['end_position'] as int?,
      );
      // Without this the shelf selector renders with nothing highlighted, as
      // though the book were on no shelf at all.
      _targetShelfId = widget.book?['shelf_id'] as int?;
      _loadReadingDates();
      _suggestStartPage();
      _suggestStartPosition();
    } else {
      _sessionDate = DateTime.now();

      if (widget.book != null) {
        _selectedBook = widget.availableBooks.firstWhere(
          (book) => book['id'] == widget.book!['id'],
          orElse: () => widget.book!,
        );
        _targetShelfId = _selectedBook!['shelf_id'] as int?;
        _pages.bookPageCount = _bookPageCount;
        _position.bookMinutes = _bookMinutes;
        _loadReadingDates();
        _presetFirstSession();
        _suggestStartPage();
        _suggestStartPosition();
      }
    }
  }

  int? get _bookPageCount => _selectedBook?['page_count'] as int?;
  int? get _bookMinutes => _selectedBook?['duration_minutes'] as int?;

  /// For an audiobook, fills the start time with the one the last session
  /// stopped on, logged the way that session was, so only the time reached
  /// this time is left to type — and loads the minutes logged around this
  /// session, for the bar.
  Future<void> _suggestStartPosition() async {
    final book = _selectedBook;
    if (book == null || _tracksPages) return;
    final bookId = book['id'] as int;
    final around = await widget.sessionRepository.getMinutesAround(
      bookId,
      _sessionDate,
      excludeId: widget.session?['id'] as int?,
    );
    final last = widget.isEditing
        ? null
        : await widget.sessionRepository.getLastPosition(bookId, _sessionDate);
    if (!mounted || _selectedBook != book) return;
    setState(() {
      _position.minutesBefore = around.before;
      _position.minutesAfter = around.after;
      if (last != null) {
        _position.suggestStart(
          lastStop: last.lastStop,
          countsDown: last.countsDown,
          byDuration: last.byDuration,
        );
      }
    });
  }

  /// The two times say how much of the book went by, which is the session's
  /// length. The length fields take it, so it is there to correct after
  /// switching to a bare duration.
  void _onPositionChanged() {
    final minutes = _position.minutes;
    if (minutes != null && minutes > 0) {
      _hoursController.text = minutes >= 60 ? '${minutes ~/ 60}' : '';
      _minutesController.text = '${minutes % 60}';
    }
    // Rebuilds, and moves the book to Finished when it has no time left.
    _onPagesChanged();
  }

  /// Loads what the page fields need to know about the book's other
  /// sessions: where the reader left off, to fill "From page" on a new
  /// session, and the pages logged before this one, to square the session
  /// that finishes the book with the book's length. A book read to its end
  /// starts over from the beginning.
  Future<void> _suggestStartPage() async {
    final book = _selectedBook;
    if (book == null || !_tracksPages) return;
    final bookId = book['id'] as int;
    final suggest = !widget.isEditing;
    final last = suggest
        ? await widget.sessionRepository.getLastPage(bookId, _sessionDate)
        : null;
    final around = await widget.sessionRepository.getPagesAround(
      bookId,
      _sessionDate,
      excludeId: widget.session?['id'] as int?,
    );
    if (!mounted || _selectedBook != book) return;
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
    final reached = !widget.isEditing &&
        (_tracksPages ? _pages.reachesEnd : _position.reachesEnd);
    if (reached &&
        !_finishedByLastPage &&
        _targetShelfId != DatabaseHelper.shelfFinished) {
      _shelfBeforeLastPage = _targetShelfId;
      _finishedByLastPage = true;
      _selectShelf(DatabaseHelper.shelfFinished);
    } else if (!reached && _finishedByLastPage) {
      _finishedByLastPage = false;
      final before = _shelfBeforeLastPage;
      if (_targetShelfId == DatabaseHelper.shelfFinished && before != null) {
        _selectShelf(before);
        return;
      }
      setState(() {});
    } else {
      setState(() {});
    }
  }

  /// A book's first session is when it gets started: offer Currently Reading
  /// and today's start date. Both land in the fields on screen, so the reader
  /// sees them and can change either before saving.
  Future<void> _presetFirstSession() async {
    final book = _selectedBook;
    if (widget.isEditing || book == null) return;
    final sessions =
        await widget.sessionRepository.getSessionsByBookId(book['id'] as int);
    // Skip if the book changed or a shelf was tapped while this was loading.
    if (sessions.isNotEmpty ||
        !mounted ||
        _selectedBook != book ||
        _targetShelfId != book['shelf_id']) {
      return;
    }
    _selectShelf(DatabaseHelper.shelfCurrentlyReading);
  }

  /// Reads the selected book's dates into the fields, dropping any edits that
  /// were meant for a different book.
  void _loadReadingDates() {
    DateTime? parse(Object? value) =>
        value is String ? DateTime.tryParse(value) : null;
    _readingDates.load(
      parse(_selectedBook?['date_started']),
      parse(_selectedBook?['date_finished']),
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    _position.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _startHoursController.dispose();
    _startMinutesController.dispose();
    _endHoursController.dispose();
    _endMinutesController.dispose();
    _scrollController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int _calculateDurationFromTimeRange() {
    final startH = int.tryParse(_startHoursController.text) ?? 0;
    final startM = int.tryParse(_startMinutesController.text) ?? 0;
    final endH = int.tryParse(_endHoursController.text) ?? 0;
    final endM = int.tryParse(_endMinutesController.text) ?? 0;

    final startTotal = startH * 60 + startM;
    final endTotal = endH * 60 + endM;

    if (endTotal <= startTotal) {
      setState(() => _timeRangeError = 'End time must be after start time');
      return 0;
    }

    setState(() => _timeRangeError = null);
    return endTotal - startTotal;
  }

  void _updateDurationFromTimeRange() {
    final hasStart =
        _startHoursController.text.isNotEmpty ||
        _startMinutesController.text.isNotEmpty;
    final hasEnd =
        _endHoursController.text.isNotEmpty ||
        _endMinutesController.text.isNotEmpty;
    if (!hasStart || !hasEnd) return;

    final durationMinutes = _calculateDurationFromTimeRange();
    if (durationMinutes > 0) {
      setState(() {
        _hoursController.text = durationMinutes ~/ 60 > 0
            ? (durationMinutes ~/ 60).toString()
            : '';
        _minutesController.text = durationMinutes % 60 > 0
            ? (durationMinutes % 60).toString()
            : '';
      });
    }
  }

  /// Audiobooks have no pages, so the form doesn't offer the field for them.
  /// The save has to ask the same question: the controller keeps whatever was
  /// typed for a previously selected paper book.
  bool get _tracksPages => _selectedBook?['book_type_id'] != 4;

  /// Applies the "Move to shelf" choice, for both a new session and an edited
  /// one — the control is on screen either way, so it has to do the same thing
  /// either way. Returns true when the book was moved to Finished.
  ///
  /// The shelf no longer decides the book's dates. It used to infer them from
  /// the transition it saw, which meant writing a date nothing on screen showed
  /// — and re-writing it on every later save. The dates are their own fields
  /// now; the shelf only offers to fill an empty one.
  Future<bool> _applyShelfSelection() async {
    final originalShelfId = _selectedBook!['shelf_id'] as int?;
    final moved = _targetShelfId != null && _targetShelfId != originalShelfId;
    if (!moved) return false;

    await widget.bookRepository.updateBookShelf(
      _selectedBook!['id'],
      _targetShelfId!,
    );

    return _targetShelfId == DatabaseHelper.shelfFinished;
  }

  /// Writes back only the dates the user touched — an untouched field is left
  /// alone rather than rewritten from this page's copy of the book.
  Future<void> _applyReadingDates() async {
    await widget.bookRepository.updateReadingDates(
      _selectedBook!['id'],
      _readingDates.changes,
    );
  }

  void _saveSession() async {
    if (_selectedBook == null) return;

    if (_tracksPages && _pages.isBackwards) return;
    if (!_tracksPages && _position.isBackwards) return;
    final int? pagesRead = _tracksPages ? _pages.pagesRead : null;
    int? durationMinutes;

    // Only a range the user can still see counts. Collapsing the calculator
    // leaves its fields filled in, and reading them anyway would overwrite the
    // hours and minutes typed afterwards with a number nothing on screen shows.
    final hasTimeRange =
        _tracksPages &&
        _showTimeRange &&
        (_startHoursController.text.isNotEmpty ||
            _startMinutesController.text.isNotEmpty ||
            _endHoursController.text.isNotEmpty ||
            _endMinutesController.text.isNotEmpty);
    if (hasTimeRange) {
      durationMinutes = _calculateDurationFromTimeRange();
      if (durationMinutes <= 0) return;
    } else if (_hoursController.text.isNotEmpty ||
        _minutesController.text.isNotEmpty) {
      final int? hours = int.tryParse(_hoursController.text);
      final int? minutes = int.tryParse(_minutesController.text);
      final calculatedDuration = (hours ?? 0) * 60 + (minutes ?? 0);
      if (calculatedDuration > 0) {
        durationMinutes = calculatedDuration;
      }
    }

    try {
      final session = Session(
        id: widget.isEditing ? widget.session!['id'] : null,
        bookId: _selectedBook!['id'],
        pagesRead: pagesRead,
        startPage: _tracksPages ? _pages.startPage : null,
        endPage: _tracksPages ? _pages.endPage : null,
        startPosition: _tracksPages ? null : _position.startPosition,
        endPosition: _tracksPages ? null : _position.endPosition,
        durationMinutes: durationMinutes,
        date: _sessionDate.toIso8601String(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (widget.isEditing) {
        await widget.sessionRepository.updateSession(session);
        await _applyShelfSelection();
        await _applyReadingDates();
        widget.onSave();
        AppSnackbar.show('Session updated successfully!');
        if (mounted) Navigator.pop(context);
      } else {
        await widget.sessionRepository.addSession(session);

        final isFinalSession = await _applyShelfSelection();
        await _applyReadingDates();

        AppSnackbar.show('Session added successfully!');

        widget.onSave();

        // Finishing a book is a moment of accomplishment — the right time to
        // (best-effort) ask for an App Store review. Gated inside the service.
        int? finishedBookCount;
        if (isFinalSession) {
          final finished = await widget.bookRepository
              .getBooks(shelfId: DatabaseHelper.shelfFinished);
          finishedBookCount = finished.length;
        }

        if (mounted) {
          Navigator.pop(context, isFinalSession ? _selectedBook : null);
        }

        if (finishedBookCount != null) {
          RatingService.instance
              .maybePromptAfterFinish(finishedBookCount: finishedBookCount);
        }
      }
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }


  Widget _buildTimeRow(
    String label,
    TextEditingController hoursCtrl,
    TextEditingController minutesCtrl,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: hoursCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) {
                  setState(() {});
                  _updateDurationFromTimeRange();
                },
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: InputDecoration(
                  labelText: 'Hours',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainer,
                  border: UnderlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: minutesCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final val = int.tryParse(v);
                  if (val != null && val > 59) minutesCtrl.text = '59';
                  setState(() {});
                  _updateDurationFromTimeRange();
                },
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: InputDecoration(
                  labelText: 'Minutes',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainer,
                  border: UnderlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// How long the session was. On its own line for a paper book; for an
  /// audiobook the times work it out, and these are for a bare duration.
  Widget _buildDurationRow(ThemeData theme) {
    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hoursController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => setState(() {}),
                            onTapOutside: (_) =>
                                FocusManager.instance.primaryFocus?.unfocus(),
                            decoration: InputDecoration(
                              labelText: 'Hours',
                              filled: true,
                              fillColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              border: UnderlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _minutesController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (v) {
                              final val = int.tryParse(v);
                              if (val != null && val > 59) {
                                _minutesController.text = '59';
                              }
                              setState(() {});
                            },
                            onTapOutside: (_) =>
                                FocusManager.instance.primaryFocus?.unfocus(),
                            decoration: InputDecoration(
                              labelText: 'Minutes',
                              filled: true,
                              fillColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              border: UnderlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _sessionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(data: Theme.of(context), child: child!);
      },
    );

    // Only the day moves — the time of day the session was read at is carried
    // over, or picking a date would silently reset it to midnight.
    if (date != null) {
      setState(() {
        _sessionDate = DateTime(
          date.year,
          date.month,
          date.day,
          _sessionDate.hour,
          _sessionDate.minute,
        );
        _readingDates.moveSessionDay(date);
      });
      // A session logged for an earlier day starts where the reader was then.
      _suggestStartPage();
      _suggestStartPosition();
    }
  }

  Future<void> _showTimePicker(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_sessionDate),
    );

    if (time != null) {
      setState(() {
        _sessionDate = DateTime(
          _sessionDate.year,
          _sessionDate.month,
          _sessionDate.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  /// One of the book's own dates. Bounded by each other and by today: a book
  /// can't be finished before it was started, or on a day that hasn't come.
  Future<void> _showReadingDatePicker(BuildContext context, bool isStart) async {
    final date = await pickReadingDate(
      context,
      isStart: isStart,
      started: _readingDates.started,
      finished: _readingDates.finished,
      fallback: _sessionDate,
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

  /// The shelf fills the date fields rather than writing behind them, with
  /// this session's day — see [ReadingDates.selectShelf] for the rules.
  void _selectShelf(int shelfId) {
    setState(() {
      _targetShelfId = shelfId;
      _readingDates.selectShelf(
        shelfId,
        DateTime(_sessionDate.year, _sessionDate.month, _sessionDate.day),
      );
    });
  }

  Future<void> _pickBook() async {
    final picked = await showBookPickerSheet(
      context: context,
      // Not every caller hands over a filtered, sorted list — the timer's
      // picker and this one should still open on the same books.
      books: sessionBookOptions(widget.availableBooks),
      title: 'Select a book',
      emptyMessage: 'Add a book to your library first',
      groupOf: sessionBookGroup,
    );

    if (picked != null) {
      setState(() {
        _selectedBook = picked;
        _targetShelfId = picked['shelf_id'] as int?;
        _loadReadingDates();
        _pages.clear();
        _pages.bookPageCount = _bookPageCount;
        _position.clear();
        _position.bookMinutes = _bookMinutes;
        _finishedByLastPage = false;
      });
      _presetFirstSession();
      _suggestStartPage();
      _suggestStartPosition();
    }
  }

  /// The book this session belongs to — the same control the reading timer
  /// uses, so the two look and behave alike.
  ///
  /// An editing session's book is fixed, so the tile is inert there; adding a
  /// session, it opens the same picker sheet the timer opens.
  Widget _buildBookBanner() {
    return BookSelectorTile(
      book: _selectedBook,
      placeholder: widget.availableBooks.isEmpty
          ? 'Add a book first'
          : 'Tap to choose...',
      onTap: widget.isEditing ? null : _pickBook,
      trailingIcon: widget.isEditing ? Icons.lock_outline : Icons.unfold_more,
    );
  }

  Widget _buildTapField(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return PickerField(
      label: label,
      value: value,
      icon: icon,
      onTap: onTap,
      onClear: onClear,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Session' : 'Add Session'),
        backgroundColor: theme.colorScheme.surfaceContainer,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: const [],
      ),
      body: Column(
        children: [
          Expanded(
            child: NotificationListener<UserScrollNotification>(
              onNotification: (n) {
                if (n.direction != ScrollDirection.idle && n.depth == 0) {
                  FocusScope.of(context).unfocus();
                }
                return false;
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBookBanner(),
                    const SizedBox(height: 16),

                    // A session is stored as the moment it was read at, so the
                    // time of day is editable alongside the date.
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildTapField(
                            theme,
                            label: 'Date',
                            value: DateFormat('MMM d, y').format(_sessionDate),
                            icon: Icons.calendar_today,
                            onTap: () => _showDatePicker(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: _buildTapField(
                            theme,
                            label: 'Time',
                            value: TimeOfDay.fromDateTime(
                              _sessionDate,
                            ).format(context),
                            icon: Icons.schedule,
                            onTap: () => _showTimePicker(context),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 48),

                    if (_tracksPages) _buildDurationRow(theme),
                    if (!_tracksPages) ...[
                      SessionPositionField(
                        position: _position,
                        lengthFields: _buildDurationRow(theme),
                        durationMinutes:
                            (int.tryParse(_hoursController.text) ?? 0) * 60 +
                                (int.tryParse(_minutesController.text) ?? 0),
                        onChanged: _onPositionChanged,
                      ),
                    ] else ...[
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withAlpha(
                            120,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => setState(
                              () => _showTimeRange = !_showTimeRange,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              children: [
                                Text(
                                  'calculate duration — not saved',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                AnimatedRotation(
                                  turns: _showTimeRange ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    Icons.expand_more,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            child: _showTimeRange
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      _buildTimeRow(
                                        'Start Time',
                                        _startHoursController,
                                        _startMinutesController,
                                        theme,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildTimeRow(
                                        'End Time',
                                        _endHoursController,
                                        _endMinutesController,
                                        theme,
                                      ),
                                      if (_timeRangeError != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          _timeRangeError!,
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: theme.colorScheme.error,
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    ],

                    if (_tracksPages) ...[
                      const SizedBox(height: 24),
                      SessionPagesField(
                        pages: _pages,
                        onChanged: _onPagesChanged,
                      ),
                    ],

                    const SizedBox(height: 24),
                    Text('Move to shelf', style: textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          for (final shelf in [
                            (
                              id: DatabaseHelper.shelfWantToRead,
                              label: 'To Read',
                              icon: Icons.bookmark,
                            ),
                            (
                              id: DatabaseHelper.shelfCurrentlyReading,
                              label: 'Reading',
                              icon: Icons.menu_book_rounded,
                            ),
                            (
                              id: DatabaseHelper.shelfFinished,
                              label: 'Finished',
                              icon: Icons.check,
                            ),
                            (
                              id: DatabaseHelper.shelfUnfinished,
                              label: 'Unfinished',
                              icon: Icons.do_not_disturb_on,
                            ),
                          ])
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _selectShelf(shelf.id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
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
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: _targetShelfId == shelf.id
                                                  ? theme.colorScheme.onPrimary
                                                  : theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                              fontWeight:
                                                  _targetShelfId == shelf.id
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

                    // The book's dates, not the session's — the shelf above
                    // fills them in when they're empty, and they stay editable
                    // either way.
                    const SizedBox(height: 16),
                    ReadingDatesRow(
                      started: _readingDates.started,
                      finished: _readingDates.finished,
                      onPickStarted: () => _showReadingDatePicker(context, true),
                      onPickFinished: () =>
                          _showReadingDatePicker(context, false),
                      onClearStarted: () => _clearReadingDate(true),
                      onClearFinished: () => _clearReadingDate(false),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Reflect on your reading session...',
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        border: UnderlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.fromLTRB(
                          12,
                          10,
                          12,
                          6,
                        ),
                        alignLabelWithHint: true,
                        suffixIcon: _notesController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () =>
                                    setState(() => _notesController.clear()),
                              )
                            : null,
                      ),
                      minLines: 2,
                      maxLines: null,
                      onChanged: (_) => setState(() {}),
                      onTapOutside: (event) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                onPressed: _selectedBook == null ? null : _saveSession,
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  disabledBackgroundColor: accentColor.withValues(alpha: 0.4),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  widget.isEditing ? 'Update Session' : 'Save Session',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
