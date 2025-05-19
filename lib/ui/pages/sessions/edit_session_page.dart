import 'package:flutter/material.dart';
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
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    int durationMinutes = widget.session['duration_minutes'] ?? 0;
    int hours = durationMinutes ~/ 60;
    int minutes = durationMinutes % 60;

    _pagesController.text = widget.session['pages_read'].toString();
    _hoursController.text = hours.toString();
    _minutesController.text = minutes.toString();
    _sessionDate = DateTime.parse(widget.session['date']);
  }

  void _updateSession() async {
    final int? pagesRead = int.tryParse(_pagesController.text);
    final int? hours = int.tryParse(_hoursController.text);
    final int? minutes = int.tryParse(_minutesController.text);

    if (pagesRead == null || hours == null || minutes == null) {
      final errorMessage = pagesRead == null
          ? 'Please enter pages read'
          : 'Please enter a duration';
      showSnackBar(errorMessage);
      return;
    }

    final int durationMinutes = (hours * 60) + minutes;
    if (pagesRead <= 0 || durationMinutes <= 0) {
      final errorMessage = pagesRead <= 0
          ? 'Pages should be above 0'
          : 'Duration should be above 0 minutes';
      showSnackBar(errorMessage);
      return;
    }

    final session = Session(
      id: widget.session['id'],
      bookId: widget.book['id'],
      pagesRead: pagesRead,
      durationMinutes: durationMinutes,
      date: _sessionDate.toIso8601String(),
    );

    try {
      await widget.sessionRepository.updateSession(session);
      showSnackBar('Session added successfully!');
      widget.refreshSessions();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      showSnackBar('Failed to add session. Please try again.');
    }
  }

  void showSnackBar(String message){
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.only(
          left: 20,
          right: 20,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteSession() async {
    try {
      await widget.sessionRepository.deleteSession(widget.session['id']);
      widget.refreshSessions();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      showSnackBar('Failed to delete session. Please try again.');
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

  String formatSessionDuration(String hours, String minutes) {
    if (hours == '0' && minutes == '0') return 'Select duration *';

    String hourText = hours != '0' ? '$hours hour${hours == "1" ? "" : "s"}' : '';
    String minuteText = minutes != '0' ? '$minutes minute${minutes == "1" ? "" : "s"}' : '';

    return [hourText, minuteText].where((e) => e.isNotEmpty).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Reading Session'),
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          TextButton(
            onPressed: _updateSession,
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
            Text('Book', style: textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              widget.book['title'],
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text('Pages', style: textTheme.bodyMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _pagesController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'Number of Pages *',
                suffixIcon: _pagesController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _pagesController.clear(),
                )
                    : null,
              ),
              keyboardType: TextInputType.number,
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
            const SizedBox(height: 24),
            Text('Duration', style: textTheme.bodyMedium),
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
                      formatSessionDuration(_hoursController.text, _minutesController.text),
                      style: textTheme.bodyLarge,
                    ),
                    Icon(Icons.arrow_drop_down, color: colors.onSurface),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Date', style: textTheme.bodyMedium),
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
            const SizedBox(height: 32),
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
                    onPressed: _updateSession,
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
        title: const Text('Set Duration'),
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