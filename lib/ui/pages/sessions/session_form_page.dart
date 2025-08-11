import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/data/models/session.dart';
import '/data/repositories/session_repository.dart';
import '/data/repositories/book_repository.dart';
import '/viewmodels/SettingsViewModel.dart';

class SessionFormPage extends StatefulWidget {
  final Map<String, dynamic>? session;
  final Map<String, dynamic>? book;
  final List<Map<String, dynamic>> availableBooks;
  final Function() refreshSessions;
  final SettingsViewModel settingsViewModel;
  final SessionRepository sessionRepository;
  final BookRepository bookRepository;
  final bool isEditing;

  const SessionFormPage({
    super.key,
    this.session,
    this.book,
    required this.availableBooks,
    required this.refreshSessions,
    required this.settingsViewModel,
    required this.sessionRepository,
    required this.bookRepository,
  }) : isEditing = session != null;

  @override
  State<SessionFormPage> createState() => _SessionFormPageState();
}

class _SessionFormPageState extends State<SessionFormPage> {
  final TextEditingController _pagesController = TextEditingController();
  final TextEditingController _startPageController = TextEditingController();
  final TextEditingController _finishPageController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _minutesController = TextEditingController();
  final TextEditingController _bookController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late DateTime _sessionDate;
  bool _isFirstSession = false;
  bool _isFinalSession = false;
  Map<String, dynamic>? _selectedBook;

  @override
  void initState() {
    super.initState();

    if (widget.isEditing) {
      // Editing existing session
      int durationMinutes = widget.session!['duration_minutes'] ?? 0;
      int hours = durationMinutes ~/ 60;
      int minutes = durationMinutes % 60;

      _pagesController.text = widget.session!['pages_read'].toString();
      _hoursController.text = hours.toString();
      _minutesController.text = minutes.toString();
      _sessionDate = DateTime.parse(widget.session!['date']);
      _selectedBook = widget.book;
    } else {
      // Adding new session
      _pagesController.text = '';
      _startPageController.text = '';
      _finishPageController.text = '';
      _hoursController.text = '0';
      _minutesController.text = '0';
      _sessionDate = DateTime.now();

      // Pre-select book if provided
      if (widget.book != null) {
        // Find the exact book object from availableBooks
        _selectedBook = widget.availableBooks.firstWhere(
              (book) => book['id'] == widget.book!['id'],
          orElse: () => widget.book!, // Fallback to the provided book if not found
        );
        _bookController.text = _selectedBook!['title'];

        if (_selectedBook != null) {
          _checkIfFirstSession();
        }
      }
    }
  }

  @override
  void dispose() {
    _pagesController.dispose();
    _startPageController.dispose();
    _finishPageController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _bookController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkIfFirstSession() async {
    if (_selectedBook == null) return;

    final sessions = await widget.sessionRepository
        .getSessionsByBookId(_selectedBook!['id']);
    setState(() => _isFirstSession = sessions.isEmpty);
  }

  void _saveSession() async {
    if (_selectedBook == null) {
      _showSnackBar('Please select a book.');
      return;
    }

    final int? pagesRead = int.tryParse(_pagesController.text);
    final int? hours = int.tryParse(_hoursController.text);
    final int? minutes = int.tryParse(_minutesController.text);

    if (pagesRead == null || hours == null || minutes == null) {
      final errorMessage = pagesRead == null
          ? 'Please enter pages read'
          : 'Please enter a duration';
      _showSnackBar(errorMessage);
      return;
    }

    final int durationMinutes = (hours * 60) + minutes;
    if (pagesRead <= 0 || durationMinutes <= 0) {
      final errorMessage = pagesRead <= 0
          ? 'Pages should be above 0'
          : 'Duration should be above 0 minutes';
      _showSnackBar(errorMessage);
      return;
    }

    try {
      // Create/update session
      final session = Session(
        id: widget.isEditing ? widget.session!['id'] : null,
        bookId: _selectedBook!['id'],
        pagesRead: pagesRead,
        durationMinutes: durationMinutes,
        date: _sessionDate.toIso8601String(),
      );

      if (widget.isEditing) {
        await widget.sessionRepository.updateSession(session);
      } else {
        await widget.sessionRepository.addSession(session);

        // Update book dates if needed for new sessions
        if (_isFirstSession || _isFinalSession) {
          await widget.bookRepository.updateBookDates(
            _selectedBook!['id'],
            isFirstSession: _isFirstSession,
            isFinalSession: _isFinalSession,
            sessionDate: _sessionDate,
          );
        }
      }

      widget.refreshSessions();
      _showSnackBar(widget.isEditing
          ? 'Session updated successfully!'
          : 'Session added successfully!');

      if (widget.isEditing && mounted) {
        Navigator.pop(context);
      } else {
        _resetInputs();
      }
    } catch (e) {
      _showSnackBar('Failed to save session. Please try again.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.only(left: 20, right: 20),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _resetInputs() {
    setState(() {
      _pagesController.clear();
      _startPageController.clear();
      _finishPageController.clear();
      _hoursController.text = '0';
      _minutesController.text = '0';
      _sessionDate = DateTime.now();
      _isFirstSession = false;
      _isFinalSession = false;
      _selectedBook = null;
    });
  }

  void _deleteSession() async {
    try {
      await widget.sessionRepository.deleteSession(widget.session!['id']);
      widget.refreshSessions();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Failed to delete session. Please try again.');
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

  String _formatSessionDuration(String hours, String minutes) {
    // if (hours == '0' && minutes == '0') {
    //   return 'Set duration';
    // }

    String hourText = hours != '0' ? '$hours hour${hours == "1" ? "" : "s"}' : '';
    String minuteText = minutes != '0' ? '$minutes minute${minutes == "1" ? "" : "s"}' : '';

    return [hourText, minuteText].where((e) => e.isNotEmpty).join(' ');
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
            colorScheme: ColorScheme.light(
              primary: widget.settingsViewModel.accentColorNotifier.value,
              onPrimary: Colors.white,
            ),
            dialogTheme: DialogThemeData(
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

  void _calculatePagesRead() {
    final startPage = int.tryParse(_startPageController.text) ?? 0;
    final finishPage = int.tryParse(_finishPageController.text) ?? 0;

    if (startPage > 0 && finishPage > 0 && finishPage >= startPage) {
      final pagesRead = finishPage - startPage + 1; // +1 because both start and end pages are inclusive
      _pagesController.text = pagesRead.toString();
    } else {
      _pagesController.clear();
    }
  }

  void _clearField(TextEditingController controller) {
    controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Session' : 'Add Session'),
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          TextButton(
            onPressed: _saveSession,
            child: Text(
              'Save',
              style: TextStyle(color: accentColor),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Selection
            if (!widget.isEditing) ...[
              Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return widget.availableBooks;
                  }
                  return widget.availableBooks.where((book) =>
                      book['title'].toLowerCase().contains(textEditingValue.text.toLowerCase())
                  );
                },
                displayStringForOption: (option) => option['title'],
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  // Sync controller with selected book when focus changes
                  focusNode.addListener(() {
                    if (!focusNode.hasFocus && _selectedBook != null) {
                      textEditingController.text = _selectedBook!['title'];
                    }
                  });

                  return TextFieldTapRegion(
                    child: TextFormField(
                      controller: _bookController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Book',
                        hintText: 'Select a book',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        suffixIcon: _selectedBook != null
                            ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            textEditingController.clear();
                            setState(() {
                              _selectedBook = null;
                              _isFirstSession = false;
                              _isFinalSession = false;
                            });
                            focusNode.requestFocus();
                          },
                        )
                            : const Icon(Icons.search),
                      ),
                      style: theme.textTheme.bodyLarge,
                      onChanged: (value) {
                        if (value.isEmpty) {
                          setState(() => _selectedBook = null);
                        }
                      },
                      onTap: () {
                        textEditingController.selection = TextSelection.fromPosition(
                            TextPosition(offset: textEditingController.text.length));
                      },
                      onTapOutside: (event) {
                        // Ensure selected book is shown when tapping outside
                        if (_selectedBook != null) {
                          textEditingController.text = _selectedBook!['title'];
                        }
                        focusNode.unfocus();
                      },
                    ),
                  );
                },
                onSelected: (option) {
                  setState(() {
                    _selectedBook = option;
                    _isFirstSession = false;
                    _isFinalSession = false;
                  });
                  _checkIfFirstSession();
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    option['title'],
                                    style: theme.textTheme.bodyLarge,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ] else ...[
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Book',
                  labelStyle: TextStyle(color: colors.onSurfaceVariant),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  suffixIcon: const Icon(Icons.lock, size: 20),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.onSurfaceVariant),
                  ),
                ),
                controller: TextEditingController(
                  text: widget.book!['title'],
                ),
              ),
              const SizedBox(height: 24),
            ],

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startPageController,
                    decoration: InputDecoration(
                      labelText: 'Start Page',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _startPageController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _clearField(_startPageController);
                        },
                      )
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _calculatePagesRead();
                      setState(() {});
                    },
                    onTapOutside: (event) {
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.arrow_forward, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _finishPageController,
                    decoration: InputDecoration(
                      labelText: 'Finish Page',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _finishPageController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _clearField(_finishPageController);
                        },
                      )
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _calculatePagesRead();
                      setState(() {});
                    },
                    onTapOutside: (event) {
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Divider(thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('OR', style: theme.textTheme.labelSmall),
                ),
                Expanded(child: Divider(thickness: 1)),
              ],
            ),
            const SizedBox(height: 8),

            // Pages Field
            TextField(
              controller: _pagesController,
              decoration: InputDecoration(
                labelText: 'Pages',
                hintText: 'Enter number of pages',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _pagesController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _clearField(_pagesController),
                )
                    : null,
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() {}), // Rebuild to update label
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
            const SizedBox(height: 24),
            // Duration Field
            TextFormField(
              readOnly: true,
              onTap: () => _showDurationPicker(context),
              controller: TextEditingController(
                text: _formatSessionDuration(_hoursController.text, _minutesController.text),
              ),
              decoration: InputDecoration(
                labelText: 'Duration',
                hintText: 'Set duration',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: (_hoursController.text != '0' || _minutesController.text != '0')
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _hoursController.text = '0';
                      _minutesController.text = '0';
                    });
                  },
                )
                    : const Icon(Icons.access_time),
              ),
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
            const SizedBox(height: 24),

            // Date Field
            TextFormField(
              readOnly: true,
              onTap: () => _showDatePicker(context),
              controller: TextEditingController(
                text: DateFormat('MMMM d, y').format(_sessionDate),
              ),
              decoration: InputDecoration(
                labelText: 'Date',
                hintText: 'Select date *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: Icon(
                    Icons.calendar_today
                ),
              ),
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
            const SizedBox(height: 16),

            // Session Type Checkboxes (only for new sessions)
            if (!widget.isEditing) ...[
              Text('Session Type', style: textTheme.bodyMedium),
              const SizedBox(height: 8),
              Column(
                children: [
                  CheckboxListTile(
                    title: const Text('First session'),
                    value: _isFirstSession,
                    onChanged: (value) {
                      setState(() => _isFirstSession = value ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    title: const Text('Final session (book finished)'),
                    value: _isFinalSession,
                    onChanged: (value) {
                      setState(() => _isFinalSession = value ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),

            // Action Buttons
            if (widget.isEditing) ...[
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
                      onPressed: _saveSession,
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
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saveSession,
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save Session'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}