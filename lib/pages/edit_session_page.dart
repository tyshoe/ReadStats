import 'package:flutter/cupertino.dart';
import '../database_helper.dart';

class EditSessionPage extends StatefulWidget {
  final Map<String, dynamic> session;
  final Map<String, dynamic> book; // Pass the book directly
  final Function() refreshSessions;

  const EditSessionPage({
    super.key,
    required this.session,
    required this.book,
    required this.refreshSessions,
  });

  @override
  State<EditSessionPage> createState() => _EditSessionPageState();
}

class _EditSessionPageState extends State<EditSessionPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _pagesController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _minutesController = TextEditingController();
  late DateTime _sessionDate;

  @override
  void initState() {
    super.initState();
    // Pre-fill the form with the existing session data
    _pagesController.text = widget.session['pages_read'].toString();
    _hoursController.text = widget.session['hours'].toString();
    _minutesController.text = widget.session['minutes'].toString();
    _sessionDate = DateTime.parse(widget.session['date']);
  }

  void _updateSession() async {
    if (_pagesController.text.isEmpty ||
        _hoursController.text.isEmpty ||
        _minutesController.text.isEmpty) {
      _showErrorDialog('Please fill all fields.');
      return;
    }

    final session = {
      'id': widget.session['id'], // Include the session ID for updating
      'book_id': widget.book['id'], // Use the book ID from the passed book
      'pages_read': int.parse(_pagesController.text),
      'hours': int.parse(_hoursController.text),
      'minutes': int.parse(_minutesController.text),
      'date': _sessionDate.toIso8601String(),
    };

    await _dbHelper.updateSession(session);
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
        content: const Text('Session updated successfully!'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(context);
              // Clear form and go back
              widget.refreshSessions(); // Call to refresh sessions list on SessionsPage
              Navigator.pop(context); // Go back to the previous screen
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Edit Session')),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              const Text('Book',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                widget.book['title'], // Display the book title directly
                style: const TextStyle(fontSize: 16),
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
                child: const Text('Update Session'),
                onPressed: _updateSession,
              ),
            ],
          ),
        ),
      ),
    );
  }
}