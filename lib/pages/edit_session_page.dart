import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
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
          Navigator.pop(
              context); // Go back to the previous screen after 2 seconds
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage =
            'Failed to update session. Please try again.'; // Error message
        _isSuccess = false;
      });
    }
  }

  // Function to delete session
  void _deleteSession() async {
    try {
      await _dbHelper.deleteSession(widget.session['id']);
      widget.refreshSessions(); // Refresh the sessions list
      Navigator.pop(context); // Go back to the previous screen
    } catch (e) {
      setState(() {
        _statusMessage =
            'Failed to delete session. Please try again.'; // Error message
        _isSuccess = false;
      });
    }
  }

  // Function to confirm deletion
  void _confirmDelete() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Session'),
        content: const Text('Are you sure you want to delete this session?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context); // Close the dialog
              _deleteSession(); // Delete the session
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = CupertinoColors.systemBackground.resolveFrom(context);
    final textColor = CupertinoColors.label.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Edit Reading Session'),
        backgroundColor: bgColor,
      ),
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
                color: CupertinoColors.systemGrey5, // Grey background for button
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
              // Row to align buttons side by side
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: CupertinoButton.filled(
                      onPressed: _updateSession,
                      child: const Text('Update Session'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CupertinoButton(
                      onPressed: _confirmDelete,
                      color: CupertinoColors.destructiveRed,
                      child: const Text('Delete Session',
                          style: TextStyle(color: CupertinoColors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Display the status message
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
