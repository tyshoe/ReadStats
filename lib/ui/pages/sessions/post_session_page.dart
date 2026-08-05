import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '/data/database/database_helper.dart';
import '/data/models/session.dart';
import '/data/repositories/session_repository.dart';
import '/data/repositories/book_repository.dart';
import '/data/services/reading_timer_service.dart';
import '/viewmodels/SettingsViewModel.dart';
import '/ui/widgets/book_cover.dart';

class PostSessionPage extends StatefulWidget {
  final Map<String, dynamic> book;
  final ReadingTimerService timerService;
  final SessionRepository sessionRepository;
  final BookRepository bookRepository;
  final SettingsViewModel settingsViewModel;
  final VoidCallback onSaved;

  const PostSessionPage({
    super.key,
    required this.book,
    required this.timerService,
    required this.sessionRepository,
    required this.bookRepository,
    required this.settingsViewModel,
    required this.onSaved,
  });

  @override
  State<PostSessionPage> createState() => _PostSessionPageState();
}

class _PostSessionPageState extends State<PostSessionPage> {
  final _pagesController = TextEditingController();
  final _startPageController = TextEditingController();
  final _endPageController = TextEditingController();
  final _notesController = TextEditingController();
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();
  late int? _targetShelfId;
  bool _isSaving = false;
  bool _isEditingDuration = false;

  @override
  void initState() {
    super.initState();
    _targetShelfId = widget.book['shelf_id'] as int?;
    _fillDurationFields(_timerMinutes);
  }

  @override
  void dispose() {
    _pagesController.dispose();
    _startPageController.dispose();
    _endPageController.dispose();
    _notesController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  /// What the timer recorded, in the whole minutes a session is stored in.
  int get _timerMinutes {
    final elapsed = widget.timerService.elapsed;
    return elapsed.inSeconds > 0 ? (elapsed.inSeconds / 60).round() : 0;
  }

  /// What the fields currently say — this is what gets saved, whether or not
  /// the user touched it.
  int get _enteredMinutes {
    final h = int.tryParse(_hoursController.text) ?? 0;
    final m = int.tryParse(_minutesController.text) ?? 0;
    return h * 60 + m;
  }

  void _fillDurationFields(int minutes) {
    _hoursController.text = minutes >= 60 ? '${minutes ~/ 60}' : '';
    _minutesController.text = '${minutes % 60}';
  }

  void _resetDuration() {
    setState(() => _fillDurationFields(_timerMinutes));
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _toggleDurationEditor() {
    if (_isEditingDuration) {
      FocusManager.instance.primaryFocus?.unfocus();
      // An empty field reads as zero everywhere else; put the number back so
      // the collapsed row can't imply a value the fields don't hold.
      _fillDurationFields(_enteredMinutes);
      setState(() => _isEditingDuration = false);
      return;
    }

    // Minutes is the field that gets corrected; open on it with the value
    // selected so typing replaces it.
    _minutesController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _minutesController.text.length,
    );
    setState(() => _isEditingDuration = true);
  }

  // Mirrors the duration that will actually be saved (rounded to the
  // nearest minute) and the format used to display it elsewhere in the app.
  String _formatElapsed(Duration d) {
    final minutes = d.inSeconds > 0 ? (d.inSeconds / 60).round() : 0;
    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainingMinutes}m';
  }

  Widget _durationField({
    required TextEditingController controller,
    required String label,
    required ThemeData theme,
    int? clampTo,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      onChanged: (value) {
        if (clampTo != null && (int.tryParse(value) ?? 0) > clampTo) {
          controller.text = '$clampTo';
        }
        setState(() {});
      },
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        border: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      ),
    );
  }

  void _calculatePages() {
    final start = int.tryParse(_startPageController.text) ?? 0;
    final end = int.tryParse(_endPageController.text) ?? 0;
    if (start > 0 && end > 0 && end >= start) {
      setState(() => _pagesController.text = (end - start + 1).toString());
    } else {
      setState(() => _pagesController.clear());
    }
  }

  void _goBack() {
    Navigator.pop(context);
  }

  Future<bool> _confirmDiscard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard session?'),
        content: const Text('Your reading progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Discard',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    return confirm == true;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      // Read the fields before stopping — they hold the timer's own figure
      // unless the user corrected it.
      final durationMinutes = _enteredMinutes > 0 ? _enteredMinutes : null;
      widget.timerService.stop();

      final session = Session(
        bookId: widget.book['id'],
        pagesRead: int.tryParse(_pagesController.text),
        durationMinutes: durationMinutes,
        date: DateTime.now().toIso8601String(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      await widget.sessionRepository.addSession(session);

      final originalShelfId = widget.book['shelf_id'] as int?;
      final isFirstSession = _targetShelfId == DatabaseHelper.shelfCurrentlyReading &&
          originalShelfId == DatabaseHelper.shelfWantToRead;
      final isFinalSession = _targetShelfId == DatabaseHelper.shelfFinished;

      if (isFirstSession || isFinalSession) {
        await widget.bookRepository.updateBookDates(
          widget.book['id'],
          isFirstSession: isFirstSession,
          isFinalSession: isFinalSession,
          sessionDate: DateTime.now(),
        );
      }

      if (_targetShelfId != null && _targetShelfId != originalShelfId) {
        await widget.bookRepository.updateBookShelf(widget.book['id'], _targetShelfId!);
      }

      widget.onSaved();
      if (mounted) Navigator.pop(context, isFinalSession ? widget.book : null);
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.settingsViewModel.accentColorNotifier.value;
    final isAudiobook = widget.book['book_type_id'] == 4;
    final elapsed = widget.timerService.elapsed;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Save Session'),
          backgroundColor: theme.colorScheme.surfaceContainer,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: NotificationListener<UserScrollNotification>(
                onNotification: (n) {
                  if (n.direction != ScrollDirection.idle) {
                    FocusScope.of(context).unfocus();
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if ((widget.book['cover_path'] as String?) != null) ...[
                            BookCover(
                              path: widget.book['cover_path'] as String,
                              shape: widget.book['cover_shape'] as int?,
                              width: 72,
                            ),
                            const SizedBox(width: 14),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.book['title'] ?? '',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if ((widget.book['author'] as String?)?.isNotEmpty == true)
                                  Text(
                                    widget.book['author'] as String,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withAlpha(140),
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Tracks the duration fields, so the
                                    // headline always reads as what gets saved.
                                    Text(
                                      _formatElapsed(
                                          Duration(minutes: _enteredMinutes)),
                                      style:
                                          theme.textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: _isSaving
                                          ? null
                                          : _toggleDurationEditor,
                                      borderRadius: BorderRadius.circular(20),
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Icon(
                                          _isEditingDuration
                                              ? Icons.check
                                              : Icons.edit_outlined,
                                          size: 16,
                                          color: _isEditingDuration
                                              ? accent
                                              : theme
                                                  .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // With the fields hidden, this is the only
                                // sign the saved length isn't the timer's.
                                if (!_isEditingDuration &&
                                    _enteredMinutes != _timerMinutes)
                                  Text(
                                    'Edited · timer ran ${_formatElapsed(elapsed)}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),

                      if (_isEditingDuration) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text('Duration',
                                  style: theme.textTheme.bodyMedium),
                            ),
                            // Only offered once the fields differ from what the
                            // timer recorded — nothing to reset to before that.
                            if (_enteredMinutes != _timerMinutes)
                              TextButton(
                                onPressed: _resetDuration,
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Reset to ${_formatElapsed(elapsed)}',
                                  style: theme.textTheme.labelMedium,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _durationField(
                                controller: _hoursController,
                                label: 'Hours',
                                theme: theme,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _durationField(
                                controller: _minutesController,
                                label: 'Minutes',
                                theme: theme,
                                // Overflow belongs in the hours field.
                                clampTo: 59,
                                autofocus: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      if (!isAudiobook) ...[
                        TextField(
                          controller: _pagesController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (_) => setState(() {}),
                          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                          decoration: InputDecoration(
                            labelText: 'Pages read',
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest,
                            border: UnderlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withAlpha(120),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'calculate pages — not saved',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _startPageController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      onChanged: (_) => _calculatePages(),
                                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                                      decoration: InputDecoration(
                                        labelText: 'Start page',
                                        filled: true,
                                        fillColor: theme.colorScheme.surfaceContainer,
                                        border: UnderlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: UnderlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: UnderlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.arrow_forward, color: theme.colorScheme.onSurface.withAlpha(100)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _endPageController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      onChanged: (_) => _calculatePages(),
                                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                                      decoration: InputDecoration(
                                        labelText: 'End page',
                                        filled: true,
                                        fillColor: theme.colorScheme.surfaceContainer,
                                        border: UnderlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: UnderlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: UnderlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      TextField(
                        controller: _notesController,
                        minLines: 3,
                        maxLines: null,
                        onChanged: (_) => setState(() {}),
                        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                        decoration: InputDecoration(
                          labelText: 'Notes',
                          hintText: 'Reflect on your reading session...',
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                          border: UnderlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                          alignLabelWithHint: true,
                          suffixIcon: _notesController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(() => _notesController.clear()),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text('Move to shelf', style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            for (final shelf in [
                              (id: DatabaseHelper.shelfWantToRead, label: 'To Read', icon: Icons.bookmark),
                              (id: DatabaseHelper.shelfCurrentlyReading, label: 'Reading', icon: Icons.menu_book_rounded),
                              (id: DatabaseHelper.shelfFinished, label: 'Finished', icon: Icons.check),
                              (id: DatabaseHelper.shelfUnfinished, label: 'Unfinished', icon: Icons.do_not_disturb_on),
                            ])
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _targetShelfId = shelf.id),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _targetShelfId == shelf.id
                                          ? theme.colorScheme.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          shelf.icon,
                                          size: 18,
                                          color: _targetShelfId == shelf.id
                                              ? theme.colorScheme.onPrimary
                                              : theme.colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          shelf.label,
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: _targetShelfId == shelf.id
                                                ? theme.colorScheme.onPrimary
                                                : theme.colorScheme.onSurfaceVariant,
                                            fontWeight: _targetShelfId == shelf.id
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : () async {
                          if (await _confirmDiscard()) {
                            widget.timerService.stop();
                            if (mounted) Navigator.pop(context);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error.withAlpha(120)),
                        ),
                        child: const Text('Discard'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : const Text('Save Session'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
