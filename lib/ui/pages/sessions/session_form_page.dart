import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/book_picker_sheet.dart';
import 'package:intl/intl.dart';
import '/data/models/session.dart';
import '/data/repositories/session_repository.dart';
import '/data/repositories/book_repository.dart';
import '/data/database/database_helper.dart';
import '/data/services/rating_service.dart';
import '/viewmodels/SettingsViewModel.dart';

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
  final TextEditingController _pagesController = TextEditingController();
  final TextEditingController _startPageController = TextEditingController();
  final TextEditingController _endPageController = TextEditingController();
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

  @override
  void initState() {
    super.initState();

    if (widget.isEditing) {
      final editDuration = widget.session!['duration_minutes'] as int?;
      if (editDuration != null && editDuration > 0) {
        _hoursController.text = (editDuration ~/ 60).toString();
        _minutesController.text = (editDuration % 60).toString();
      }

      // pages_read is nullable — .toString() on a null put the literal "null"
      // in the field.
      _pagesController.text =
          (widget.session!['pages_read'] as int?)?.toString() ?? '';
      _sessionDate = DateTime.parse(widget.session!['date']);
      _notesController.text = widget.session!['notes'] ?? '';
      _selectedBook = widget.book;
      // Without this the shelf selector renders with nothing highlighted, as
      // though the book were on no shelf at all.
      _targetShelfId = widget.book?['shelf_id'] as int?;
    } else {
      _pagesController.text = '';
      _startPageController.text = '';
      _endPageController.text = '';
      _sessionDate = DateTime.now();

      if (widget.book != null) {
        _selectedBook = widget.availableBooks.firstWhere(
          (book) => book['id'] == widget.book!['id'],
          orElse: () => widget.book!,
        );
        _targetShelfId = _selectedBook!['shelf_id'] as int?;
      }
    }
  }

  @override
  void dispose() {
    _pagesController.dispose();
    _startPageController.dispose();
    _endPageController.dispose();
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

  void _calculatePagesRead() {
    final startPage = int.tryParse(_startPageController.text) ?? 0;
    final endPage = int.tryParse(_endPageController.text) ?? 0;

    if (startPage > 0 && endPage > 0 && endPage >= startPage) {
      final pagesRead = endPage - startPage + 1;
      _pagesController.text = pagesRead.toString();
    } else {
      _pagesController.clear();
    }
  }

  void _resetInputs() {
    setState(() {
      _pagesController.clear();
      _startPageController.clear();
      _endPageController.clear();
      _hoursController.clear();
      _minutesController.clear();
      _startHoursController.clear();
      _startMinutesController.clear();
      _endHoursController.clear();
      _endMinutesController.clear();
      _sessionDate = DateTime.now();
      _targetShelfId = _selectedBook?['shelf_id'] as int?;
    });
  }

  /// Applies the "Move to shelf" choice, for both a new session and an edited
  /// one — the control is on screen either way, so it has to do the same thing
  /// either way. Returns true when the book was moved to Finished.
  ///
  /// Everything is gated on the shelf actually changing: the selector starts on
  /// the book's current shelf, so acting on the target alone would rewrite
  /// date_finished every time an already-finished book's session was saved.
  Future<bool> _applyShelfSelection() async {
    final originalShelfId = _selectedBook!['shelf_id'] as int?;
    final moved = _targetShelfId != null && _targetShelfId != originalShelfId;
    if (!moved) return false;

    final isFirstSession =
        _targetShelfId == DatabaseHelper.shelfCurrentlyReading &&
        originalShelfId == DatabaseHelper.shelfWantToRead;
    final isFinalSession = _targetShelfId == DatabaseHelper.shelfFinished;

    if (isFirstSession || isFinalSession) {
      await widget.bookRepository.updateBookDates(
        _selectedBook!['id'],
        isFirstSession: isFirstSession,
        isFinalSession: isFinalSession,
        sessionDate: _sessionDate,
      );
    }

    await widget.bookRepository.updateBookShelf(
      _selectedBook!['id'],
      _targetShelfId!,
    );

    return isFinalSession;
  }

  void _saveSession() async {
    if (_selectedBook == null) return;

    final int? pagesRead = int.tryParse(_pagesController.text);
    int? durationMinutes;

    final hasTimeRange =
        _startHoursController.text.isNotEmpty ||
        _startMinutesController.text.isNotEmpty ||
        _endHoursController.text.isNotEmpty ||
        _endMinutesController.text.isNotEmpty;
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
        durationMinutes: durationMinutes,
        date: _sessionDate.toIso8601String(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (widget.isEditing) {
        await widget.sessionRepository.updateSession(session);
        await _applyShelfSelection();
        widget.onSave();
        AppSnackbar.show('Session updated successfully!');
        if (mounted) Navigator.pop(context);
      } else {
        await widget.sessionRepository.addSession(session);

        final isFinalSession = await _applyShelfSelection();

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
      });
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

  Future<void> _pickBook() async {
    final picked = await showBookPickerSheet(
      context: context,
      books: widget.availableBooks,
      title: 'Select a book',
      emptyMessage: 'Add a book to your library first',
    );

    if (picked != null) {
      setState(() {
        _selectedBook = picked;
        _targetShelfId = picked['shelf_id'] as int?;
      });
    }
  }

  /// The book this session belongs to, as a banner rather than a text field.
  ///
  /// An editing session's book is fixed, so the banner is inert there; adding a
  /// session, it opens the same library picker sheet used by the timer.
  Widget _buildBookBanner(ThemeData theme) {
    final book = widget.isEditing ? widget.book : _selectedBook;
    final onTap = widget.isEditing ? null : _pickBook;

    if (book == null) return _buildEmptyBookBanner(theme, onTap);

    final coverPath = book['cover_path'] as String?;
    final author = book['author'] as String?;
    final hasCover = coverPath != null && coverPath.isNotEmpty;

    final content = Row(
      children: [
        if (hasCover)
          BookCover(
            path: coverPath,
            shape: book['cover_shape'] as int?,
            width: 60,
            borderRadius: 6,
          )
        else
          _coverPlaceholder(theme),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                book['title'] as String? ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: hasCover ? Colors.white : null,
                ),
              ),
              if (author?.isNotEmpty == true) ...[
                const SizedBox(height: 3),
                Text(
                  author!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: hasCover
                        ? Colors.white.withValues(alpha: 0.85)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          widget.isEditing ? Icons.lock_outline : Icons.unfold_more,
          size: 20,
          color: hasCover
              ? Colors.white.withValues(alpha: 0.8)
              : theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // The cover's own colours, blown up and blurred, stand in for a
          // background image — the art is portrait, the banner is not.
          if (hasCover)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Image.file(
                  File(coverPath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          if (hasCover)
            // Covers are any colour at all, so the text sits on a scrim rather
            // than on the art itself.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
            ),
          Material(
            color: hasCover
                ? Colors.transparent
                : theme.colorScheme.surfaceContainerHighest,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: content,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBookBanner(ThemeData theme, VoidCallback? onTap) {
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _coverPlaceholder(theme),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Choose a book',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverPlaceholder(ThemeData theme) {
    return Container(
      width: 60,
      height: 60 / DatabaseHelper.coverAspectRatio(null),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.menu_book_rounded,
        size: 24,
        color: theme.colorScheme.outline,
      ),
    );
  }

  /// A read-only field that opens a picker — date and time both behave this
  /// way, and a TextFormField would need a throwaway controller each build.
  Widget _buildTapField(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
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
                if (n.direction != ScrollDirection.idle && n.depth == 0)
                  FocusScope.of(context).unfocus();
                return false;
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBookBanner(theme),
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

                    if (_selectedBook?['book_type_id'] != 4)
                      Column(
                        children: [
                          TextField(
                            controller: _pagesController,
                            decoration: InputDecoration(
                              labelText: 'Pages',
                              hintText: 'Enter number of pages',
                              border: UnderlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              contentPadding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                6,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) => setState(() {}),
                            onTapOutside: (event) {
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withAlpha(120),
                              ),
                            ),
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'calculate pages — not saved',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _startPageController,
                                        decoration: InputDecoration(
                                          labelText: 'Start Page',
                                          border: UnderlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: UnderlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: UnderlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          filled: true,
                                          fillColor: theme
                                              .colorScheme
                                              .surfaceContainer,
                                          contentPadding:
                                              const EdgeInsets.fromLTRB(
                                                12,
                                                10,
                                                12,
                                                6,
                                              ),
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        onChanged: (value) {
                                          _calculatePagesRead();
                                          setState(() {});
                                        },
                                        onTapOutside: (event) {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.arrow_forward,
                                      color: theme.colorScheme.onSurface
                                          .withAlpha(100),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _endPageController,
                                        decoration: InputDecoration(
                                          labelText: 'End Page',
                                          border: UnderlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: UnderlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: UnderlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          filled: true,
                                          fillColor: theme
                                              .colorScheme
                                              .surfaceContainer,
                                          contentPadding:
                                              const EdgeInsets.fromLTRB(
                                                12,
                                                10,
                                                12,
                                                6,
                                              ),
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        onChanged: (value) {
                                          _calculatePagesRead();
                                          setState(() {});
                                        },
                                        onTapOutside: (event) {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),

                    // Duration Field
                    Row(
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
                              if (val != null && val > 59)
                                _minutesController.text = '59';
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
                    ),
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
                                onTap: () =>
                                    setState(() => _targetShelfId = shelf.id),
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
