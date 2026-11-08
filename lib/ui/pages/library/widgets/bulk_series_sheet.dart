import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/data/database/database_helper.dart';
import '/data/repositories/series_repository.dart';
import '/data/utils/series_title.dart';

/// Puts the selected books into one series, numbered in the order they were
/// selected — drag to change it. For books whose titles don't say their
/// series, where "Find series in titles" can't help.
///
/// Returns how many books were added.
Future<int?> showBulkSeriesSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> books,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _BulkSeriesSheet(books: books),
  );
}

class _BulkSeriesSheet extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  const _BulkSeriesSheet({required this.books});

  @override
  State<_BulkSeriesSheet> createState() => _BulkSeriesSheetState();
}

class _BulkSeriesSheetState extends State<_BulkSeriesSheet> {
  final _repo = SeriesRepository(DatabaseHelper());
  final _nameController = TextEditingController();
  final _startController = TextEditingController(text: '1');
  late final List<Map<String, dynamic>> _order = [...widget.books];
  List<String> _existing = const [];
  bool _saving = false;

  // Bumped on each name change so a slow lookup can't overwrite a newer one.
  int _lookup = 0;

  @override
  void initState() {
    super.initState();
    _repo.names().then((names) {
      if (mounted) setState(() => _existing = names);
    });
    // Selected books that already share a series most likely belong to it.
    final current = {for (final b in widget.books) b['series_name'] as String?}
      ..remove(null);
    if (current.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setName(current.first!);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startController.dispose();
    super.dispose();
  }

  String get _name => _nameController.text.trim();

  int get _start => int.tryParse(_startController.text) ?? 1;

  /// Continues an existing series after its highest number.
  Future<void> _setName(String name) async {
    if (_nameController.text != name) {
      _nameController.text = name;
      _nameController.selection =
          TextSelection.collapsed(offset: name.length);
    }
    setState(() {});
    final ticket = ++_lookup;
    final max = name.trim().isEmpty
        ? null
        : await _repo.maxPosition(
            name,
            excludeBookIds: [for (final b in widget.books) b['id'] as int],
          );
    if (!mounted || ticket != _lookup) return;
    setState(() => _startController.text = '${max == null ? 1 : max.floor() + 1}');
  }

  Future<void> _save() async {
    if (_name.isEmpty) return;
    setState(() => _saving = true);
    final seriesId = await _repo.idFor(_name);
    await _repo.link([
      for (var i = 0; i < _order.length; i++)
        {
          'id': _order[i]['id'],
          'series_id': seriesId,
          'series_position': (_start + i).toDouble(),
        },
    ]);
    if (mounted) Navigator.pop(context, _order.length);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final count = widget.books.length;
    final suggestions = _existing
        .where((n) =>
            _name.isEmpty || n.toLowerCase().contains(_name.toLowerCase()))
        .take(8)
        .toList();

    InputDecoration field(String hint) => InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle bar ────────────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: muted.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add to Series', style: theme.textTheme.titleLarge),
                      Text(
                        '$count ${count == 1 ? 'book' : 'books'} selected',
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _saving || _name.isEmpty ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Series name and start ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: field('Series name'),
                    onChanged: _setName,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 76,
                  child: TextField(
                    controller: _startController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    // The first number; the rest count up from it.
                    decoration: field('1').copyWith(prefixText: '#'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          if (suggestions.isNotEmpty &&
              !suggestions.any((s) => s.toLowerCase() == _name.toLowerCase()))
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                children: [
                  for (final s in suggestions)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(s),
                        onPressed: () => _setName(s),
                        side: BorderSide.none,
                        backgroundColor:
                            theme.colorScheme.secondaryContainer,
                        shape: const StadiumBorder(),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.drag_indicator, size: 16, color: muted),
                const SizedBox(width: 6),
                Text(
                  'Numbered in this order — drag to change it',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Books, in order ───────────────────────────────────────────────
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.45,
            ),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _order.length,
              onReorder: (from, to) => setState(() {
                if (to > from) to -= 1;
                _order.insert(to, _order.removeAt(from));
              }),
              itemBuilder: (context, i) {
                final b = _order[i];
                final current = b['series_name'] as String?;
                final moving = current != null &&
                    _name.isNotEmpty &&
                    current.toLowerCase() != _name.toLowerCase();
                return ListTile(
                  key: ValueKey(b['id']),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: Text(
                      '#${SeriesTitle.formatPosition((_start + i).toDouble())}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  title: Text(
                    b['title'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    moving
                        ? 'Moves from $current'
                        : b['author'] as String? ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: moving ? theme.colorScheme.error : muted,
                    ),
                  ),
                  trailing: ReorderableDragStartListener(
                    index: i,
                    child: Icon(Icons.drag_handle, color: muted),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
        ],
      ),
    );
  }
}
