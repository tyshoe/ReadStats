import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/data/models/session.dart';
import '/data/repositories/session_repository.dart';
import '/data/repositories/book_repository.dart';
import '/viewmodels/SettingsViewModel.dart';

class LogSessionPage extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final Function() refreshSessions;
  final int? initialBookId;
  final SettingsViewModel settingsViewModel;
  final SessionRepository sessionRepository;
  final BookRepository bookRepository;

  const LogSessionPage({
    super.key,
    required this.books,
    required this.refreshSessions,
    this.initialBookId,
    required this.settingsViewModel,
    required this.sessionRepository,
    required this.bookRepository,
  });

  @override
  State<LogSessionPage> createState() => _LogSessionPageState();
}

class _LogSessionPageState extends State<LogSessionPage> {
  Map<String, dynamic>? _selectedBook;
  final TextEditingController _pagesController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _minutesController = TextEditingController();
  DateTime _sessionDate = DateTime.now();
  String _statusMessage = '';
  bool _isSuccess = false;
  bool _isFirstSession = false;
  bool _isFinalSession = false;

  List<Map<String, dynamic>> _availableBooks = [];

  @override
  void initState() {
    super.initState();
    // Filter out completed books
    _availableBooks =
        widget.books.where((book) => book['is_completed'] == 0).toList();

    // Pre-select book if initialBookId is provided
    if (widget.initialBookId != null) {
      _selectedBook = _availableBooks.firstWhere(
            (book) => book['id'] == widget.initialBookId,
        orElse: () => <String, dynamic>{},
      );

      if (_selectedBook!.isEmpty) {
        _selectedBook = null;
      } else {
        // Check if this is the first session for the book
        _checkIfFirstSession();
      }
    }

    _hoursController.text = "0";
    _minutesController.text = "0";
  }

  Future<void> _checkIfFirstSession() async {
    if (_selectedBook == null) return;

    final sessions = await widget.sessionRepository.getSessionsByBookId(_selectedBook!['id']);
    if (sessions.isEmpty) {
      setState(() => _isFirstSession = true);
    }
  }

  void _saveSession() async {
    if (_selectedBook == null) {
      _showStatusMessage('Please select a book.', false);
      return;
    }

    final int? pagesRead = int.tryParse(_pagesController.text);
    final int? hours = int.tryParse(_hoursController.text);
    final int? minutes = int.tryParse(_minutesController.text);

    if (pagesRead == null || hours == null || minutes == null) {
      _showStatusMessage('Please enter valid numbers.', false);
      return;
    }

    final int durationMinutes = (hours * 60) + minutes;
    if (pagesRead <= 0 || durationMinutes <= 0) {
      _showStatusMessage('Pages and time must be greater than zero.', false);
      return;
    }

    try {
      // First create the session
      final session = Session(
        bookId: _selectedBook!['id'],
        pagesRead: pagesRead,
        durationMinutes: durationMinutes,
        date: _sessionDate.toIso8601String(),
      );

      await widget.sessionRepository.addSession(session);

      // Then update book dates if needed
      if (_isFirstSession || _isFinalSession) {
        await widget.bookRepository.updateBookDates(
          _selectedBook!['id'],
          isFirstSession: _isFirstSession,
          isFinalSession: _isFinalSession,
          sessionDate: _sessionDate,
        );
      }

      widget.refreshSessions();
      _showStatusMessage('Session added successfully!', true);
      _resetInputs();
    } catch (e) {
      _showStatusMessage('Failed to add session. Please try again.', false);
    }
  }

// Helper function to handle status messages
  void _showStatusMessage(String message, bool isSuccess) {
    setState(() {
      _statusMessage = message;
      _isSuccess = isSuccess;
    });
    _clearStatusMessage();
  }

  void _clearStatusMessage() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _statusMessage = '';
          _isSuccess = false;
        });
      }
    });
  }

  void _resetInputs() {
    setState(() {
      _selectedBook = null;
      _pagesController.clear();
      _hoursController.text = "0";
      _minutesController.text = "0";
      _sessionDate = DateTime.now();
    });
  }

  void _clearField(TextEditingController textEditController) {
    setState(() {
      textEditController.clear();
    });
  }

  String formatSessionTime(String hours, String minutes) {
    if (hours == '0' && minutes == '0') {
      return 'Select time';
    }

    String hourText = '';
    String minuteText = '';

    if (hours != '0') {
      hourText = '$hours hour${hours == '1' ? '' : 's'}';
    }

    if (minutes != '0') {
      minuteText = '$minutes minute${minutes == '1' ? '' : 's'}';
    }

    // If both hour and minute are present, combine them
    if (hourText.isNotEmpty && minuteText.isNotEmpty) {
      return '$hourText $minuteText';
    }

    // Return either hour or minute depending on what is available
    return hourText.isNotEmpty ? hourText : minuteText;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Reading Session'),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Book', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _selectedBook,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              items: _availableBooks.map((book) {
                return DropdownMenuItem(
                  value: book,
                  child: Text(
                    book['title'],
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBook = value;
                  _isFirstSession = false;
                  _isFinalSession = false;
                });
                if (value != null) _checkIfFirstSession();
              },
              hint: const Text('Select a book'),
              isExpanded: true,
              dropdownColor: Theme.of(context).colorScheme.surface,
              menuMaxHeight: 200,
              alignment: AlignmentDirectional.centerStart,
            ),
            const SizedBox(height: 24),
            Text('Pages', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _pagesController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'Number of Pages',
                suffixIcon: _pagesController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _clearField(_pagesController),
                      )
                    : null,
              ),
              keyboardType: TextInputType.number,
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
            const SizedBox(height: 24),
            Text('Time', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _showDurationPicker(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatSessionTime(
                          _hoursController.text, _minutesController.text),
                      style: textTheme.bodyLarge,
                    ),
                    Icon(Icons.arrow_drop_down, color: colors.onSurface),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Date', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _showDatePicker(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM d, y').format(_sessionDate),
                      style: textTheme.bodyLarge,
                    ),
                    Icon(Icons.calendar_today, color: colors.onSurface),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Session Type Checkboxes
            if (_selectedBook != null) ...[
              Text('Session Type', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Column(
                children: [
                  CheckboxListTile(
                    title: const Text('First session for this book'),
                    value: _isFirstSession,
                    onChanged: (value) {
                      setState(() => _isFirstSession = value ?? false);
                      if (value == true) {
                        setState(() => _isFinalSession = false);
                      }
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    title: const Text('Final session (book completed)'),
                    value: _isFinalSession,
                    onChanged: (value) {
                      setState(() => _isFinalSession = value ?? false);
                      if (value == true) {
                        setState(() => _isFirstSession = false);
                      }
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),
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
            const SizedBox(height: 16),
            if (_statusMessage.isNotEmpty)
              Text(
                _statusMessage,
                style: textTheme.bodyLarge?.copyWith(
                  color: _isSuccess ? colors.primary : colors.error,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDurationPicker(BuildContext context) async {
    int hours = int.tryParse(_hoursController.text) ?? 0;
    int minutes = int.tryParse(_minutesController.text) ?? 0;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Duration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: hours.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Hours',
                      // suffixText: 'h',
                    ),
                    onChanged: (value) => hours = int.tryParse(value) ?? 0,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: minutes.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minutes',
                      // suffixText: 'm',
                    ),
                    onChanged: (value) => minutes = int.tryParse(value) ?? 0,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _hoursController.text = hours.toString();
                _minutesController.text = minutes.toString();
              });
              Navigator.pop(context);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
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
            dialogTheme: DialogTheme(
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
}
