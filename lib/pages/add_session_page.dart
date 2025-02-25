import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';
import '../repositories/session_repository.dart';

class LogSessionPage extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final Function() refreshSessions;
  final int? initialBookId;

  const LogSessionPage({
    super.key,
    required this.books,
    required this.refreshSessions,
    this.initialBookId,
  });

  @override
  State<LogSessionPage> createState() => _LogSessionPageState();
}

class _LogSessionPageState extends State<LogSessionPage> {
  final SessionRepository _sessionRepo = SessionRepository();
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
    if (_selectedBook == null ||
        _pagesController.text.isEmpty ||
        _hoursController.text.isEmpty ||
        _minutesController.text.isEmpty) {
      setState(() {
        _statusMessage = 'Please fill all fields.';
        _isSuccess = false;
      });
      return;
    }

    final int? pagesRead = int.tryParse(_pagesController.text);
    final int? hours = int.tryParse(_hoursController.text);
    final int? minutes = int.tryParse(_minutesController.text);

    if (pagesRead == null ||
        hours == null ||
        minutes == null ||
        (hours == 0 && minutes == 0)) {
      setState(() {
        _statusMessage = 'Invalid input. Enter valid numbers.';
        _isSuccess = false;
      });
      return;
    }

    final session = Session(
      bookId: _selectedBook!['id'],
      pagesRead: pagesRead,
      hours: hours,
      minutes: minutes,
      date: _sessionDate.toIso8601String(),
    );

    try {
      await _sessionRepo.addSession(session);
      widget.refreshSessions();

      setState(() {
        _statusMessage = 'Session logged successfully!';
        _isSuccess = true;
      });

      _resetInputs();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _statusMessage = '';
            _isSuccess = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to log session. Please try again.';
        _isSuccess = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final bgColor = CupertinoColors.systemBackground.resolveFrom(context);
    final textColor = CupertinoColors.label.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Add Reading Session'),
        backgroundColor: bgColor,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              const Text(
                'Book',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Center(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  color:
                      CupertinoColors.systemGrey5,
                  borderRadius: BorderRadius.circular(8),
                  onPressed: _availableBooks.isEmpty
                      ? null // Disable if no available books
                      : () => showCupertinoModalPopup(
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
                          ),
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
                'Pages Read',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              CupertinoTextField(
                  controller: _pagesController,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reading Time',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16),
                    color: CupertinoColors
                        .systemGrey5,
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_hoursController.text} hours ${_minutesController.text} minutes',
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
                'Session Date',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(
                  height: 8),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                color: CupertinoColors.systemGrey5,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM d, y').format(_sessionDate),
                      style: TextStyle(fontSize: 16, color: textColor),
                    ),
                    Icon(CupertinoIcons.chevron_down, color: CupertinoColors.systemGrey)
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
              CupertinoButton.filled(
                onPressed: _saveSession,
                child: const Text('Log Session'),
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
