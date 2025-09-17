import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/ui/pages/sessions/widgets/rate_book_dialog.dart';
import '/data/models/session.dart';
import '/data/repositories/session_repository.dart';
import '/data/repositories/book_repository.dart';
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
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode hoursFocusNode = FocusNode();
  final FocusNode minutesFocusNode = FocusNode();
  late DateTime _sessionDate;
  bool _isFirstSession = false;
  bool _isFinalSession = false;
  bool _useElapsedTimeFormat = false;
  Map<String, dynamic>? _selectedBook;

  @override
  void initState() {
    super.initState();

    if (widget.isEditing) {
      // Editing existing session
      int durationMinutes = widget.session!['duration_minutes'] ?? 0;
      int hours = durationMinutes ~/ 60;
      int minutes = durationMinutes % 60;

      _pagesController.text = widget.session!['pages_read'].toString();
      _hoursController.text = hours.toString();
      _minutesController.text = minutes.toString();
      _sessionDate = DateTime.parse(widget.session!['date']);
      _selectedBook = widget.book;
    } else {
      // Adding new session
      _pagesController.text = '';
      _startPageController.text = '';
      _endPageController.text = '';
      _hoursController.text = '0';
      _minutesController.text = '0';
      _sessionDate = DateTime.now();
      _startTimeController.text = '';
      _endTimeController.text = '';

      // Pre-select book if provided
      if (widget.book != null) {
        // Find the exact book object from availableBooks
        _selectedBook = widget.availableBooks.firstWhere(
          (book) => book['id'] == widget.book!['id'],
          orElse: () => widget.book!, // Fallback to the provided book if not found
        );
        _bookController.text = _selectedBook!['title'];

        if (_selectedBook != null) {
          _checkIfFirstSession();
        }
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
    _scrollController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  Future<void> _checkIfFirstSession() async {
    if (_selectedBook == null) return;

    final sessions = await widget.sessionRepository.getSessionsByBookId(_selectedBook!['id']);
    setState(() => _isFirstSession = sessions.isEmpty);
  }

  int _calculateDurationFromTimeRange() {
    try {
      if (_useElapsedTimeFormat) {
        // Elapsed time format (HH:MM) - for audiobooks, podcasts, videos, etc.
        final startParts = _startTimeController.text.split(':');
        final endParts = _endTimeController.text.split(':');

        if (startParts.length != 2 || endParts.length != 2) {
          throw FormatException('Invalid time format');
        }

        final startHours = int.parse(startParts[0]);
        final startMinutes = int.parse(startParts[1]);
        final endHours = int.parse(endParts[0]);
        final endMinutes = int.parse(endParts[1]);

        // Calculate total minutes
        final startTotalMinutes = (startHours * 60) + startMinutes;
        final endTotalMinutes = (endHours * 60) + endMinutes;

        if (endTotalMinutes < startTotalMinutes) {
          _showSnackBar('End time must be after start time');
          return 0;
        }

        return endTotalMinutes - startTotalMinutes;
      } else {
        // Clock time format (regular time with AM/PM)
        final startTime = DateFormat('h:mm a').parse(_startTimeController.text);
        final endTime = DateFormat('h:mm a').parse(_endTimeController.text);

        DateTime endDateTime = DateTime(
            _sessionDate.year, _sessionDate.month, _sessionDate.day, endTime.hour, endTime.minute);
        DateTime startDateTime = DateTime(_sessionDate.year, _sessionDate.month, _sessionDate.day,
            startTime.hour, startTime.minute);

        if (endDateTime.isBefore(startDateTime)) {
          endDateTime = endDateTime.add(const Duration(days: 1));
        }

        return endDateTime.difference(startDateTime).inMinutes;
      }
    } catch (e) {
      final errorMessage = _useElapsedTimeFormat
          ? 'Please enter valid times in the format HH:MM'
          : 'Please enter valid times in the format h:mm AM/PM';

      _showSnackBar(errorMessage);
      return 0;
    }
  }

  void _updateDurationFromTimeRange() {
    if (_startTimeController.text.isNotEmpty && _endTimeController.text.isNotEmpty) {
      try {
        final durationMinutes = _calculateDurationFromTimeRange();
        if (durationMinutes > 0) {
          final hours = durationMinutes ~/ 60;
          final minutes = durationMinutes % 60;

          setState(() {
            _hoursController.text = hours.toString();
            _minutesController.text = minutes.toString();
          });
        }
      } catch (e) {
        // Ignore parsing errors, user might still be typing
      }
    }
  }

  void _calculatePagesRead() {
    final startPage = int.tryParse(_startPageController.text) ?? 0;
    final endPage = int.tryParse(_endPageController.text) ?? 0;

    if (startPage > 0 && endPage > 0 && endPage >= startPage) {
      final pagesRead =
          endPage - startPage + 1; // +1 because both start and end pages are inclusive
      _pagesController.text = pagesRead.toString();
    } else {
      _pagesController.clear();
    }
  }

  String _formatSessionDuration(String hours, String minutes) {
    String hourText = hours != '0' ? '$hours hour${hours == "1" ? "" : "s"}' : '';
    String minuteText = minutes != '0' ? '$minutes minute${minutes == "1" ? "" : "s"}' : '';

    return [hourText, minuteText].where((e) => e.isNotEmpty).join(' ');
  }

  void _clearField(TextEditingController controller) {
    controller.clear();
    setState(() {});

    // If clearing time fields, also reset duration if needed
    if (controller == _startTimeController || controller == _endTimeController) {
      if (_startTimeController.text.isEmpty && _endTimeController.text.isEmpty) {
        setState(() {
          _hoursController.text = '0';
          _minutesController.text = '0';
        });
      } else {
        _updateDurationFromTimeRange();
      }
    }
  }

  void _resetInputs() {
    setState(() {
      _pagesController.clear();
      _startPageController.clear();
      _endPageController.clear();
      _hoursController.text = '0';
      _minutesController.text = '0';
      _sessionDate = DateTime.now();
      _isFirstSession = false;
      _isFinalSession = false;
      _startTimeController.clear();
      _endTimeController.clear();
    });
  }

  void _saveSession() async {
    if (_selectedBook == null) {
      _showSnackBar('Please select a book.');
      return;
    }

    final int? pagesRead = int.tryParse(_pagesController.text);
    int? durationMinutes;

    // Check if we should calculate duration from time range
    if (_startTimeController.text.isNotEmpty && _endTimeController.text.isNotEmpty) {
      try {
        durationMinutes = _calculateDurationFromTimeRange();
        if (durationMinutes <= 0) {
          _showSnackBar('End time must be after start time');
          return;
        }
      } catch (e) {
        _showSnackBar('Please enter valid times in the format "h:mm AM/PM"');
        return;
      }
    } else if (_hoursController.text.isNotEmpty || _minutesController.text.isNotEmpty) {
      // Use manual duration input
      final int? hours = int.tryParse(_hoursController.text);
      final int? minutes = int.tryParse(_minutesController.text);

      if ((hours != null && hours < 0) || (minutes != null && minutes < 0)) {
        _showSnackBar('Duration values cannot be negative');
        return;
      }

      // Only set duration if at least one field has a value greater than 0
      final calculatedDuration = (hours ?? 0) * 60 + (minutes ?? 0);
      if (calculatedDuration > 0) {
        durationMinutes = calculatedDuration;
      }
    }

    try {
      // Create/update session
      final session = Session(
        id: widget.isEditing ? widget.session!['id'] : null,
        bookId: _selectedBook!['id'],
        pagesRead: pagesRead,
        durationMinutes: durationMinutes,
        date: _sessionDate.toIso8601String(),
      );

      if (widget.isEditing) {
        await widget.sessionRepository.updateSession(session);
        widget.onSave();
        _showSnackBar('Session updated successfully!');
        if (mounted) Navigator.pop(context);
      } else {
        await widget.sessionRepository.addSession(session);

        // Update book dates if needed for new sessions
        if (_isFirstSession || _isFinalSession) {
          await widget.bookRepository.updateBookDates(
            _selectedBook!['id'],
            isFirstSession: _isFirstSession,
            isFinalSession: _isFinalSession,
            sessionDate: _sessionDate,
          );
        }

        _showSnackBar('Session added successfully!');

        if (_isFinalSession && mounted) {
          await _showRatingDialog();
          widget.onSave();
          if (mounted) Navigator.pop(context);
        } else {
          widget.onSave();
          _resetInputs();
        }
      }
    } catch (e) {
      _showSnackBar('Failed to save session. Please try again.');
    }
  }

  void _deleteSession() async {
    try {
      await widget.sessionRepository.deleteSession(widget.session!['id']);
      widget.onSave();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Failed to delete session. Please try again.');
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: const Text('Are you sure you want to delete this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSession();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRatingDialog() async {
    final completer = Completer<void>();

    showRateBookDialog(
      context: context,
      bookTitle: _selectedBook!['title'],
      accentColor: widget.settingsViewModel.accentColorNotifier.value,
      onRate: (rating) async {
        try {
          await widget.bookRepository.updateBookRating(
            _selectedBook!['id'],
            rating,
          );
          _showSnackBar("Rating saved!");
        } catch (e) {
          _showSnackBar("Failed to save rating: ${e.toString()}");
        } finally {
          completer.complete();
        }
      },
      onSkip: () {
        _showSnackBar("Skipped rating.");
        completer.complete();
      },
      useStarRating: widget.settingsViewModel.defaultRatingStyleNotifier.value == 0,
    );

    return completer.future;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.only(left: 20, right: 20),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _showDurationPicker(BuildContext context) async {
    int hours = int.tryParse(_hoursController.text) ?? 0;
    int minutes = int.tryParse(_minutesController.text) ?? 0;

    await showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth * 0.8;

        return AlertDialog(
          title: Text(
            'Set Duration',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          content: SizedBox(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: hours.toString(),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          filled: true,
                        ),
                        onChanged: (value) {
                          hours = int.tryParse(value) ?? 0;
                          if (hours < 0) hours = 0;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Vertically centered colon
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          ':',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: minutes.toString(),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          filled: true,
                        ),
                        onChanged: (value) {
                          minutes = int.tryParse(value) ?? 0;
                          if (minutes > 59) minutes = 59;
                          if (minutes < 0) minutes = 0;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Hours',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Minutes',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _hoursController.text = hours.toString();
                  _minutesController.text = minutes.toString();
                  // Clear time range when manually setting duration
                  _startTimeController.clear();
                  _endTimeController.clear();
                });
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showTimePicker(BuildContext context, bool isStartTime) async {
    final initialTime = TimeOfDay.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.inputOnly,
    );

    if (pickedTime != null) {
      final formattedTime = pickedTime.format(context);
      setState(() {
        if (isStartTime) {
          _startTimeController.text = formattedTime;
        } else {
          _endTimeController.text = formattedTime;
        }
      });

      // Update duration after selecting a time
      _updateDurationFromTimeRange();
    }
  }

  Future<void> _showElapsedTimePicker(BuildContext context, bool isStartTime) async {
    final currentText = isStartTime ? _startTimeController.text : _endTimeController.text;
    int initialHours = 0;
    int initialMinutes = 0;

    // Parse existing time if available
    if (currentText.isNotEmpty) {
      final parts = currentText.split(':');
      if (parts.length == 2) {
        initialHours = int.tryParse(parts[0]) ?? 0;
        initialMinutes = int.tryParse(parts[1]) ?? 0;
      }
    }

    int selectedHours = initialHours;
    int selectedMinutes = initialMinutes;

    await showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth * 0.8;

        return AlertDialog(
          title: Text(
            'Enter Time',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          content: SizedBox(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: initialHours.toString(),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          filled: true,
                        ),
                        onChanged: (value) {
                          selectedHours = int.tryParse(value) ?? 0;
                          if (selectedHours < 0) selectedHours = 0;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ':',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: initialMinutes.toString(),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          filled: true,
                        ),
                        onChanged: (value) {
                          selectedMinutes = int.tryParse(value) ?? 0;
                          if (selectedMinutes > 59) selectedMinutes = 59;
                          if (selectedMinutes < 0) selectedMinutes = 0;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Hour',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                    SizedBox(width: 32),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Minute',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final formattedTime =
                    '${selectedHours.toString().padLeft(2, '0')}:${selectedMinutes.toString().padLeft(2, '0')}';
                setState(() {
                  if (isStartTime) {
                    _startTimeController.text = formattedTime;
                  } else {
                    _endTimeController.text = formattedTime;
                  }
                });
                Navigator.pop(context);
                _updateDurationFromTimeRange();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _sessionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() => _sessionDate = date);
    }
  }

  Widget _buildShortDividerWithText(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.colorScheme.outline.withAlpha(77);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurface.withAlpha(128),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          child: Divider(
            thickness: 1,
            color: dividerColor,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: labelStyle,
          ),
        ),
        SizedBox(
          width: 80,
          child: Divider(
            thickness: 1,
            color: dividerColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeFormatToggle() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: false,
            icon: Icon(Icons.access_time, size: 18),
            label: Text('Clock Time'),
          ),
          ButtonSegment(
            value: true,
            icon: Icon(Icons.timer, size: 18),
            label: Text('Elapsed Time'),
          ),
        ],
        selected: {_useElapsedTimeFormat},
        onSelectionChanged: (Set<bool> newSelection) {
          setState(() {
            _useElapsedTimeFormat = newSelection.first;
          });
        },
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          selectedBackgroundColor: Theme.of(context).colorScheme.primaryContainer,
          selectedForegroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
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
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          TextButton(
            onPressed: _saveSession,
            child: Text(
              'Save',
              style: TextStyle(color: accentColor),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                  return widget.availableBooks.where((book) =>
                      book['title'].toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                displayStringForOption: (option) => option['title'],
                // Replace the Autocomplete widget's fieldViewBuilder with this corrected version:
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  // Sync the external _bookController with the internal textEditingController
                  if (_selectedBook != null &&
                      textEditingController.text != _selectedBook!['title']) {
                    textEditingController.text = _selectedBook!['title'];
                  }

                  // Listen for focus changes to keep the controllers in sync
                  focusNode.addListener(() {
                    if (!focusNode.hasFocus && _selectedBook != null) {
                      textEditingController.text = _selectedBook!['title'];
                    }
                  });

                  return TextFieldTapRegion(
                    child: TextFormField(
                      controller: textEditingController, // Use the internal controller
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Book',
                        hintText: 'Select a book',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        suffixIcon: _selectedBook != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  textEditingController.clear();
                                  setState(() {
                                    _selectedBook = null;
                                    _isFirstSession = false;
                                    _isFinalSession = false;
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
                        textEditingController.selection = TextSelection.fromPosition(
                            TextPosition(offset: textEditingController.text.length));
                      },
                      onTapOutside: (event) {
                        // Ensure selected book is shown when tapping outside
                        if (_selectedBook != null) {
                          textEditingController.text = _selectedBook!['title'];
                        }
                        focusNode.unfocus();
                      },
                    ),
                  );
                },
                onSelected: (option) {
                  setState(() {
                    _selectedBook = option;
                    _isFirstSession = false;
                    _isFinalSession = false;
                    _useElapsedTimeFormat = option['book_type_id'] == 4;
                  });
                  _checkIfFirstSession();
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    option['title'],
                                    style: theme.textTheme.bodyLarge,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ] else ...[
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Book',
                  labelStyle: TextStyle(color: colors.onSurfaceVariant),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  suffixIcon: const Icon(Icons.lock, size: 20),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.onSurfaceVariant),
                  ),
                ),
                controller: TextEditingController(
                  text: widget.book!['title'],
                ),
              ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: const Icon(Icons.calendar_today),
              ),
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
            const Divider(height: 48),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startPageController,
                    decoration: InputDecoration(
                      labelText: 'Start Page',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _startPageController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _clearField(_startPageController);
                              },
                            )
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _calculatePagesRead();
                      setState(() {});
                    },
                    onTapOutside: (event) {
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.arrow_forward, color: theme.colorScheme.onSurface.withAlpha(153)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _endPageController,
                    decoration: InputDecoration(
                      labelText: 'End Page',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _endPageController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _clearField(_endPageController);
                              },
                            )
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _calculatePagesRead();
                      setState(() {});
                    },
                    onTapOutside: (event) {
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            _buildShortDividerWithText(context),
            const SizedBox(height: 8),

            // Pages Field
            TextField(
              controller: _pagesController,
              decoration: InputDecoration(
                labelText: 'Pages',
                hintText: 'Enter number of pages',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _pagesController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _clearField(_pagesController),
                      )
                    : null,
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() {}), // Rebuild to update label
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
            const SizedBox(height: 36),

            // Time Range Input
            _buildTimeFormatToggle(),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    onTap: () => _useElapsedTimeFormat
                        ? _showElapsedTimePicker(context, true)
                        : _showTimePicker(context, true),
                    controller: _startTimeController,
                    decoration: InputDecoration(
                      labelText: 'Start Time',
                      hintText: 'Select start time',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _startTimeController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _clearField(_startTimeController),
                            )
                          : null,
                    ),
                    onTapOutside: (event) {
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.arrow_forward, color: theme.colorScheme.onSurface.withAlpha(153)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    onTap: () => _useElapsedTimeFormat
                        ? _showElapsedTimePicker(context, false)
                        : _showTimePicker(context, false),
                    controller: _endTimeController,
                    decoration: InputDecoration(
                      labelText: 'End Time',
                      hintText: 'Select end time',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _endTimeController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _clearField(_endTimeController),
                            )
                          : null,
                    ),
                    onTapOutside: (event) {
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            _buildShortDividerWithText(context),
            const SizedBox(height: 8),

            // Duration Field
            TextFormField(
              readOnly: true,
              onTap: () => _showDurationPicker(context),
              controller: TextEditingController(
                text: _formatSessionDuration(_hoursController.text, _minutesController.text),
              ),
              decoration: InputDecoration(
                labelText: 'Duration',
                hintText: 'Set duration',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: (_hoursController.text != '0' || _minutesController.text != '0')
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _hoursController.text = '0';
                            _minutesController.text = '0';
                            // Clear time range when clearing duration
                            _startTimeController.clear();
                            _endTimeController.clear();
                          });
                        },
                      )
                    : const Icon(Icons.access_time),
              ),
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
            const Divider(height: 48),

            // Session Type Checkboxes (only for new sessions)
            if (!widget.isEditing) ...[
              Text('Session Type', style: textTheme.bodyMedium),
              const SizedBox(height: 8),
              Column(
                children: [
                  if (_selectedBook != null)
                    FutureBuilder<List<Session>>(
                      future: widget.sessionRepository.getSessionsByBookId(_selectedBook!['id']),
                      builder: (context, snapshot) {
                        final hasExistingSessions = snapshot.hasData && snapshot.data!.isNotEmpty;

                        return Visibility(
                          visible: !hasExistingSessions,
                          child: CheckboxListTile(
                            title: const Text('First session'),
                            value: _isFirstSession,
                            onChanged: (value) {
                              setState(() => _isFirstSession = value ?? false);
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        );
                      },
                    ),
                  CheckboxListTile(
                    title: const Text('Final session (book finished)'),
                    value: _isFinalSession,
                    onChanged: (value) {
                      setState(() => _isFinalSession = value ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),

            // Action Buttons
            if (widget.isEditing) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _confirmDelete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.error,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: colors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saveSession,
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saveSession,
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save Session'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
