import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '/data/models/session.dart';
import '/data/repositories/session_repository.dart';
import '/viewmodels/SettingsViewModel.dart';

class EditSessionPage extends StatefulWidget {
  final Map<String, dynamic> session;
  final Map<String, dynamic> book;
  final Function() refreshSessions;
  final SettingsViewModel settingsViewModel;
  final SessionRepository sessionRepository;

  const EditSessionPage({
    super.key,
    required this.session,
    required this.book,
    required this.refreshSessions,
    required this.settingsViewModel,
    required this.sessionRepository,
  });

  @override
  State<EditSessionPage> createState() => _EditSessionPageState();
}

class _EditSessionPageState extends State<EditSessionPage> {
  final TextEditingController _pagesController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _minutesController = TextEditingController();
  late DateTime _sessionDate;
  String _statusMessage = '';
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();

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
        _statusMessage = 'Please fill all fields.';
        _isSuccess = false;
      });
      _clearStatusMessage();
      return;
    }

    final session = Session(
      id: widget.session['id'],
      bookId: widget.book['id'],
      pagesRead: int.parse(_pagesController.text),
      hours: int.parse(_hoursController.text),
      minutes: int.parse(_minutesController.text),
      date: _sessionDate.toIso8601String(),
    );

    try {
      await widget.sessionRepository.updateSession(session);
      setState(() {
        _statusMessage = 'Session updated successfully!';
        _isSuccess = true;
      });
      widget.refreshSessions();
      if (mounted) {
        Navigator.pop(context); // Go back to the previous screen immediately
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to update session. Please try again.';
        _isSuccess = false;
      });
      _clearStatusMessage();
    }
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

  void _deleteSession() async {
    try {
      await widget.sessionRepository.deleteSession(widget.session['id']);
      widget.refreshSessions();
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to delete session. Please try again.';
        _isSuccess = false;
      });
    }
  }

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
              Navigator.pop(context);
              _deleteSession();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
        middle: Text('Edit Reading Session'),
        trailing: GestureDetector(
          onTap: _updateSession,
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
              const Text('Book',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                widget.book['title'],
                style: const TextStyle(fontSize: 16),
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
                    child: Icon(CupertinoIcons.clear, color: CupertinoColors.systemGrey),
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
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    color: CupertinoColors.systemGrey5,
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatSessionTime(_hoursController.text, _minutesController.text),
                          style: TextStyle(fontSize: 16, color: textColor),
                        ),
                        Icon(CupertinoIcons.chevron_down, color: CupertinoColors.systemGrey),
                      ],
                    ),
                    onPressed: () => showCupertinoModalPopup(
                      context: context,
                      builder: (_) => Container(
                        height: 250,
                        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                        child: Column(
                          children: [
                            Expanded(
                              child: CupertinoTimerPicker(
                                itemExtent: 40, // Adjust this for faster/slower scrolling
                                mode: CupertinoTimerPickerMode.hm,
                                initialTimerDuration: Duration(
                                  hours: int.tryParse(_hoursController.text) ?? 0,
                                  minutes: int.tryParse(_minutesController.text) ?? 0,
                                ),
                                onTimerDurationChanged: (Duration duration) {
                                  setState(() {
                                    _hoursController.text = duration.inHours.toString();
                                    _minutesController.text = (duration.inMinutes % 60).toString();
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
                    Icon(CupertinoIcons.chevron_down, color: CupertinoColors.systemGrey),
                  ],
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
                      onDateTimeChanged: (date) => setState(() => _sessionDate = date),
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
                    flex: 1,
                    child: CupertinoButton(
                      onPressed: _confirmDelete,
                      color: CupertinoColors.destructiveRed,
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: CupertinoColors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: CupertinoButton(
                      onPressed: _updateSession,
                      color: accentColor,
                      child: const Text('Save',
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
