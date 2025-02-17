import 'package:flutter/cupertino.dart';
import '../database_helper.dart';

class LogSessionPage extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final Function() refreshSessions;

  const LogSessionPage({super.key, required this.books, required this.refreshSessions});

  @override
  State<LogSessionPage> createState() => _LogSessionPageState();
}

class _LogSessionPageState extends State<LogSessionPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, dynamic>? _selectedBook;
  final TextEditingController _pagesController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _minutesController = TextEditingController();
  DateTime _sessionDate = DateTime.now();

  void _saveSession() async {
    if (_selectedBook == null ||
        _pagesController.text.isEmpty ||
        _hoursController.text.isEmpty ||
        _minutesController.text.isEmpty) {
      _showErrorDialog('Please fill all fields and select a book.');
      return;
    }

    final session = {
      'book_id': _selectedBook!['id'],
      'pages_read': int.parse(_pagesController.text),
      'hours': int.parse(_hoursController.text),
      'minutes': int.parse(_minutesController.text),
      'date': _sessionDate.toIso8601String(),
    };

    await _dbHelper.insertSession(session);
    widget.refreshSessions(); // Call to refresh sessions list on SessionsPage
    _showSuccessDialog();
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Success'),
        content: const Text('Session logged successfully!'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(context);
              // Clear form
              widget.refreshSessions(); // Call to refresh sessions list on SessionsPage
              setState(() {
                _selectedBook = null;
                _pagesController.clear();
                _hoursController.clear();
                _minutesController.clear();
                _sessionDate = DateTime.now();
              });
            },
          ),
        ],
      ),
    );
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
              const Text('Select Book',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          CupertinoButton(
            child: Text(_selectedBook?['title'] ?? 'Tap to choose book'),
            onPressed: () => showCupertinoModalPopup(
              context: context,
              builder: (_) => Container(
                height: 200,
                color: CupertinoColors.systemBackground,
                child: CupertinoPicker(
                  itemExtent: 32,
                  onSelectedItemChanged: (index) {
                    setState(() {
                      _selectedBook = widget.books[index];
                    });
                  },
                  children: widget.books
                      .map((book) => Text(book['title']))
                      .toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          CupertinoTextField(
            controller: _pagesController,
            placeholder: 'Pages Read',
            keyboardType: TextInputType.number,
            prefix: const Text('Pages: '),
          ),
          const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: _hoursController,
                        placeholder: 'Hours',
                        keyboardType: TextInputType.number,
                        prefix: const Text('Hrs: '),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CupertinoTextField(
                        controller: _minutesController,
                        placeholder: 'Minutes',
                        keyboardType: TextInputType.number,
                        prefix: const Text('Mins: '),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Session Date',
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  CupertinoButton(
                    child: Text(
                        '${_sessionDate.month}/${_sessionDate.day}/${_sessionDate.year}'),
                    onPressed: () => showCupertinoModalPopup(
                      context: context,
                      builder: (_) => Container(
                        height: 200,
                        color: CupertinoColors.systemBackground,
                        child: CupertinoDatePicker(
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
                child: const Text('Log Session'),
                onPressed: _saveSession,
              ),
            ],
          ),
        ),
      ),
    );
  }
}