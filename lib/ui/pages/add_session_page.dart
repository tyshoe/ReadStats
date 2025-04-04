import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '/data/models/session.dart';
import '/data/repositories/session_repository.dart';
import '/viewmodels/SettingsViewModel.dart';

class LogSessionPage extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final Function() refreshSessions;
  final int? initialBookId;
  final SettingsViewModel settingsViewModel;
  final SessionRepository sessionRepository;

  const LogSessionPage({
    super.key,
    required this.books,
    required this.refreshSessions,
    this.initialBookId,
    required this.settingsViewModel,
    required this.sessionRepository,
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
        orElse: () =>
            <String, dynamic>{}, // Return an empty map instead of null
      );

      // If an empty map was returned, set _selectedBook to null
      if (_selectedBook!.isEmpty) {
        _selectedBook = null;
      }
    }

    _hoursController.text = "0";
    _minutesController.text = "0";
  }

  void _saveSession() async {
    // Validate book selection
    if (_selectedBook == null) {
      _showStatusMessage('Please select a book.', false);
      return;
    }

    // Validate numeric inputs
    final int? pagesRead = int.tryParse(_pagesController.text);
    final int? hours = int.tryParse(_hoursController.text);
    final int? minutes = int.tryParse(_minutesController.text);

    if (pagesRead == null || hours == null || minutes == null) {
      setState(() {
        _statusMessage = 'Please enter valid numbers.';
        _isSuccess = false;
      });
      _clearStatusMessage();
      return;
    }

    final int durationMinutes = (hours * 60) + minutes;
    if (pagesRead <= 0 || durationMinutes <= 0) {
      setState(() {
        _statusMessage = 'Pages and time must be greater than zero.';
        _isSuccess = false;
      });
      _clearStatusMessage();
      return;
    }

    final session = Session(
      bookId: _selectedBook!['id'],
      pagesRead: pagesRead,
      durationMinutes: durationMinutes,
      date: _sessionDate.toIso8601String(),
    );

    try {
      await widget.sessionRepository.addSession(session);
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
    final bgColor = CupertinoColors.systemBackground.resolveFrom(context);
    final textColor = CupertinoColors.label.resolveFrom(context);
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Add Reading Session'),
        trailing: GestureDetector(
          onTap: _saveSession,
          child: Text(
            'Save',
            style: TextStyle(
              color: accentColor,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              const Text(
                'Book',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Center(
                child: CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  color: CupertinoColors.systemGrey5,
                  borderRadius: BorderRadius.circular(8),
                  onPressed: _availableBooks.isEmpty
                      ? null // Disable if no available books
                      : () {
                          setState(() {
                            // Set _selectedBook to the first available book when button is pressed
                            _selectedBook = _availableBooks[0];
                          });

                          showCupertinoModalPopup(
                            context: context,
                            builder: (_) => Container(
                              height: 200,
                              color: CupertinoColors.secondarySystemBackground
                                  .resolveFrom(context),
                              child: CupertinoPicker(
                                itemExtent: 32,
                                onSelectedItemChanged: (index) {
                                  setState(() {
                                    _selectedBook = _availableBooks[index];
                                  });
                                },
                                children: _availableBooks
                                    .map((book) => Text(book['title']))
                                    .toList(),
                              ),
                            ),
                          );
                        },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedBook?['title'] ?? 'Select a book',
                        style: TextStyle(fontSize: 16, color: textColor),
                      ),
                      Icon(CupertinoIcons.chevron_down,
                          color: CupertinoColors.systemGrey)
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pages',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                controller: _pagesController,
                placeholder: "Number of Pages",
                onTapOutside: (event) {
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                keyboardType: TextInputType.number,
                suffix: _pagesController.text.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () => _clearField(_pagesController),
                          child: Icon(CupertinoIcons.clear,
                              color: CupertinoColors.systemGrey),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Time',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    color: CupertinoColors.systemGrey5,
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatSessionTime(
                              _hoursController.text, _minutesController.text),
                          style: TextStyle(fontSize: 16, color: textColor),
                        ),
                        Icon(CupertinoIcons.chevron_down,
                            color: CupertinoColors.systemGrey)
                      ],
                    ),
                    onPressed: () => showCupertinoModalPopup(
                      context: context,
                      builder: (_) => Container(
                        height: 250,
                        color: CupertinoColors.secondarySystemBackground
                            .resolveFrom(context),
                        child: Column(
                          children: [
                            Expanded(
                              child: CupertinoTimerPicker(
                                itemExtent:
                                    40, // Adjust this for faster/slower scrolling
                                mode: CupertinoTimerPickerMode
                                    .hm, // Hours & Minutes only
                                initialTimerDuration: Duration(
                                  hours:
                                      int.tryParse(_hoursController.text) ?? 0,
                                  minutes:
                                      int.tryParse(_minutesController.text) ??
                                          0,
                                ),
                                onTimerDurationChanged: (Duration duration) {
                                  setState(() {
                                    _hoursController.text =
                                        duration.inHours.toString();
                                    _minutesController.text =
                                        (duration.inMinutes % 60).toString();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Date',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                color: CupertinoColors.systemGrey5,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM d, y').format(_sessionDate),
                      style: TextStyle(fontSize: 16, color: textColor),
                    ),
                    Icon(CupertinoIcons.chevron_down,
                        color: CupertinoColors.systemGrey)
                  ],
                ),
                onPressed: () => showCupertinoModalPopup(
                  context: context,
                  builder: (_) => Container(
                    height: 200,
                    color: CupertinoColors.secondarySystemBackground
                        .resolveFrom(context),
                    child: CupertinoDatePicker(
                      maximumDate: DateTime.now(),
                      initialDateTime: _sessionDate,
                      mode: CupertinoDatePickerMode.date,
                      onDateTimeChanged: (date) =>
                          setState(() => _sessionDate = date),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              CupertinoButton(
                onPressed: _saveSession,
                color: accentColor,
                child: const Text('Save',
                    style: TextStyle(color: CupertinoColors.white)),
              ),
              const SizedBox(height: 16),
              if (_statusMessage.isNotEmpty)
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _isSuccess
                        ? CupertinoColors.systemGreen
                        : CupertinoColors.systemRed,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
