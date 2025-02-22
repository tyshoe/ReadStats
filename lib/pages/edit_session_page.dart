import 'package:flutter/cupertino.dart';
import '../database/database_helper.dart';

class EditSessionPage extends StatefulWidget {
  final Map<String, dynamic> session;
  final Map<String, dynamic> book;
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
  String _statusMessage = ''; // To display success/error messages
  bool _isSuccess = false; // To track if the operation was successful

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
      setState(() {
        _statusMessage = 'Please fill all fields.'; // Error message
        _isSuccess = false;
      });
      return;
    }

    final session = {
      'id': widget.session['id'],
      'book_id': widget.book['id'],
      'pages_read': int.parse(_pagesController.text),
      'hours': int.parse(_hoursController.text),
      'minutes': int.parse(_minutesController.text),
      'date': _sessionDate.toIso8601String(),
    };

    try {
      await _dbHelper.updateSession(session);
      setState(() {
        _statusMessage = 'Session updated successfully!'; // Success message
        _isSuccess = true;
      });
      widget.refreshSessions(); // Refresh the sessions list
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context); // Go back to the previous screen after 2 seconds
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to update session. Please try again.'; // Error message
        _isSuccess = false;
      });
    }
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
                widget.book['title'],
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
                        color:CupertinoColors.secondarySystemBackground.resolveFrom(context),
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
                child: const Text('Update Session'),
                onPressed: _updateSession,
              ),
              const SizedBox(height: 16),
              // Display the status message
              if (_statusMessage.isNotEmpty)
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _isSuccess ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
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