import 'package:flutter/cupertino.dart';
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
    _availableBooks = widget.books.where((book) => book['is_completed'] == 0).toList();

    // Pre-select book if initialBookId is provided
    if (widget.initialBookId != null) {
      _selectedBook = _availableBooks.firstWhere(
            (book) => book['id'] == widget.initialBookId,
        orElse: () => <String, dynamic>{}, // Return an empty map instead of null
      );

      // If an empty map was returned, set _selectedBook to null
      if (_selectedBook!.isEmpty) {
        _selectedBook = null;
      }
    }
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

    if (pagesRead == null || hours == null || minutes == null) {
      setState(() {
        _statusMessage = 'Invalid input. Enter valid numbers.';
        _isSuccess = false;
      });
      return;
    }

    // Create a session using the Session model
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
      _hoursController.clear();
      _minutesController.clear();
      _sessionDate = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Log Session')),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              const Text(
                'Select Book',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              CupertinoButton(
                child: Text(_selectedBook?['title'] ?? 'Tap to choose book'),
                onPressed: _availableBooks.isEmpty
                    ? null  // Disable if no available books
                    : () => showCupertinoModalPopup(
                  context: context,
                  builder: (_) => Container(
                    height: 200,
                    color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
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
              ),

              const SizedBox(height: 16),
              const Text('Pages Read'),
              CupertinoTextField(controller: _pagesController, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reading Time',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Hours'),
                            const SizedBox(height: 4),
                            CupertinoTextField(
                              controller: _hoursController,
                              placeholder: 'Hours',
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Minutes'),
                            const SizedBox(height: 4),
                            CupertinoTextField(
                              controller: _minutesController,
                              placeholder: 'Minutes',
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CupertinoButton(
                    child: Text(
                      '${_hoursController.text} hrs ${_minutesController.text} mins',
                      style: const TextStyle(fontSize: 16),
                    ),
                    onPressed: () => showCupertinoModalPopup(
                      context: context,
                      builder: (_) => Container(
                        height: 250,
                        color: CupertinoColors.systemBackground.resolveFrom(context),
                        child: Column(
                          children: [
                            Expanded(
                              child: CupertinoTimerPicker(
                                itemExtent: 40, // Adjust this for faster/slower scrolling
                                mode: CupertinoTimerPickerMode.hm, // Hours & Minutes only
                                initialTimerDuration: Duration(
                                  hours: int.tryParse(_hoursController.text) ?? 0,
                                  minutes: int.tryParse(_minutesController.text) ?? 0,
                                ),
                                onTimerDurationChanged: (Duration duration) {
                                  setState(() {
                                    _hoursController.text = duration.inHours.toString();
                                    _minutesController.text =
                                        (duration.inMinutes % 60).toString();
                                  });
                                },
                              ),
                            ),
                            CupertinoButton(
                              child: const Text('Done'),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Session Date',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  CupertinoButton(
                    child: Text(
                      '${_sessionDate.month}/${_sessionDate.day}/${_sessionDate.year}',
                    ),
                    onPressed: () => showCupertinoModalPopup(
                      context: context,
                      builder: (_) => Container(
                        height: 200,
                        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
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
                ],
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
