import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../widgets/app_snackbar.dart';
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
  final TextEditingController _bookController = TextEditingController();
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
        _bookController.text = _selectedBook!['title'];
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
    _bookController.dispose();
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

    if (date != null) {
      setState(() => _sessionDate = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
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
                    // Book Selection
                    if (!widget.isEditing) ...[
                      Autocomplete<Map<String, dynamic>>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return widget.availableBooks;
                          }
                          return widget.availableBooks.where(
                            (book) => book['title'].toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            ),
                          );
                        },
                        displayStringForOption: (option) => option['title'],
                        fieldViewBuilder:
                            (
                              context,
                              textEditingController,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              if (_selectedBook != null &&
                                  textEditingController.text !=
                                      _selectedBook!['title']) {
                                textEditingController.text =
                                    _selectedBook!['title'];
                              }

                              focusNode.addListener(() {
                                if (!focusNode.hasFocus &&
                                    _selectedBook != null) {
                                  textEditingController.text =
                                      _selectedBook!['title'];
                                }
                              });

                              return TextFieldTapRegion(
                                child: TextFormField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Book',
                                    hintText: 'Select a book',
                                    border: UnderlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    contentPadding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      6,
                                    ),
                                    suffixIcon: _selectedBook != null
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              textEditingController.clear();
                                              setState(() {
                                                _selectedBook = null;
                                                _targetShelfId = null;
                                              });
                                              focusNode.requestFocus();
                                            },
                                          )
                                        : const Icon(Icons.search),
                                  ),
                                  style: theme.textTheme.bodyLarge,
                                  onChanged: (value) {
                                    if (value.isEmpty) {
                                      setState(() => _selectedBook = null);
                                    }
                                  },
                                  onTap: () {
                                    textEditingController
                                        .selection = TextSelection.fromPosition(
                                      TextPosition(
                                        offset:
                                            textEditingController.text.length,
                                      ),
                                    );
                                  },
                                  onTapOutside: (event) {
                                    if (_selectedBook != null) {
                                      textEditingController.text =
                                          _selectedBook!['title'];
                                    }
                                  },
                                ),
                              );
                            },
                        onSelected: (option) {
                          setState(() {
                            _selectedBook = option;
                            _targetShelfId = option['shelf_id'] as int?;
                          });
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          final double itemHeight = 52;
                          final double maxHeight = 200;
                          final double height = (options.length * itemHeight)
                              .clamp(0, maxHeight);
                          return TextFieldTapRegion(
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: height,
                                  ),
                                  child: Scrollbar(
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      itemCount: options.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                            final option = options.elementAt(
                                              index,
                                            );
                                            return InkWell(
                                              onTap: () => onSelected(option),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  16.0,
                                                ),
                                                child: Text(
                                                  option['title'],
                                                  style:
                                                      theme.textTheme.bodyLarge,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (_selectedBook != null &&
                          (_selectedBook!['author'] as String?)?.isNotEmpty ==
                              true) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            'by ${_selectedBook!['author']}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Book',
                          labelStyle: TextStyle(color: colors.onSurfaceVariant),
                          border: UnderlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.fromLTRB(
                            12,
                            10,
                            12,
                            6,
                          ),
                          suffixIcon: const Icon(Icons.lock, size: 20),
                        ),
                        controller: TextEditingController(
                          text: widget.book!['title'],
                        ),
                      ),
                      if ((widget.book!['author'] as String?)?.isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            'by ${widget.book!['author']}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),

                    // Date Field
                    TextFormField(
                      readOnly: true,
                      onTap: () => _showDatePicker(context),
                      controller: TextEditingController(
                        text: DateFormat('MMMM d, y').format(_sessionDate),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Date',
                        hintText: 'Select date *',
                        border: UnderlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.fromLTRB(
                          12,
                          10,
                          12,
                          6,
                        ),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                      onTapOutside: (event) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
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
              child: Opacity(
                opacity: _selectedBook == null ? 0.4 : 1.0,
                child: FilledButton(
                  onPressed: _saveSession,
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    widget.isEditing ? 'Update Session' : 'Save Session',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
