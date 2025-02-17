import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _sessions = [];

  Future<void> _loadSessions() async {
    final sessions = await _dbHelper.getSessionsWithBooks();
    setState(() => _sessions = sessions);
  }

  String _formatDuration(int hours, int minutes) {
    final hourText = hours > 0 ? '${hours}h ' : '';
    return '$hourText${minutes}m';
  }

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    return DateFormat('MMM dd, yyyy').format(date);
  }

  void _confirmDeleteSession(int sessionId) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Session'),
        content: const Text('Are you sure you want to delete this session? This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () async {
              await _dbHelper.deleteSession(sessionId);
              Navigator.pop(context);
              _loadSessions();
            },
          ),
        ],
      ),
    );
  }


  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Reading Sessions'),
      ),
      child: SafeArea(
        child: _sessions.isEmpty
            ? const Center(child: Text('No sessions logged yet'))
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _sessions.length,
          itemBuilder: (context, index) {
            final session = _sessions[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
              ),
              child: CupertinoListTile(
                title: Text(session['book_title']),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📖 ${session['pages_read']} pages', style: const TextStyle(fontSize: 14)),
                    Text('⏱️ ${_formatDuration(session['hours'], session['minutes'])}', style: const TextStyle(fontSize: 14)),
                    Text('📅 ${_formatDate(session['date'])}', style: const TextStyle(fontSize: 14)),
                  ],
                ),
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.delete, color: CupertinoColors.destructiveRed),
                  onPressed: () => _confirmDeleteSession(session['id']),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}