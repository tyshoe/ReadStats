import 'package:flutter/material.dart';
import '/data/models/tag.dart';
import '/data/repositories/tag_repository.dart';

/// How many of the selected books already carry a given tag.
enum _TagCoverage { all, some, none }

/// The action the user has chosen for a tag during this session.
enum _TagIntent { unchanged, addToAll, removeAll }

class _TagState {
  final Tag tag;
  final _TagCoverage initialCoverage;
  _TagIntent intent;

  _TagState({
    required this.tag,
    required this.initialCoverage,
    this.intent = _TagIntent.unchanged,
  });

  /// The visual checkbox value: true = add-to-all, false = remove-all,
  /// null = indeterminate (some books have it, untouched).
  bool? get checkValue {
    switch (intent) {
      case _TagIntent.addToAll:
        return true;
      case _TagIntent.removeAll:
        return false;
      case _TagIntent.unchanged:
        switch (initialCoverage) {
          case _TagCoverage.all:
            return true;
          case _TagCoverage.none:
            return false;
          case _TagCoverage.some:
            return null; // indeterminate
        }
    }
  }

  /// Coverage label shown next to the tag name.
  String? get coverageLabel {
    if (intent != _TagIntent.unchanged) return null; // hide once user acted
    switch (initialCoverage) {
      case _TagCoverage.all:
      case _TagCoverage.none:
        return null; // obvious from the checkbox
      case _TagCoverage.some:
        return 'Some';
    }
  }
}

/// Shows a modal bottom sheet that lets the user bulk-apply / remove tags
/// across multiple selected books, with clear "all / some / none" indicators.
///
/// Returns `true` if any changes were saved, `null` / `false` otherwise.
Future<int?> showBulkTagSheet({
  required BuildContext context,
  required List<int> selectedBookIds,
  required TagRepository tagRepository,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _BulkTagSheet(
      selectedBookIds: selectedBookIds,
      tagRepository: tagRepository,
    ),
  );
}

class _BulkTagSheet extends StatefulWidget {
  final List<int> selectedBookIds;
  final TagRepository tagRepository;

  const _BulkTagSheet({
    required this.selectedBookIds,
    required this.tagRepository,
  });

  @override
  State<_BulkTagSheet> createState() => _BulkTagSheetState();
}

class _BulkTagSheetState extends State<_BulkTagSheet> {
  bool _loading = true;
  List<_TagState> _tagStates = [];
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final allTags = await widget.tagRepository.getAllTags();

    final Map<int, Set<int>> bookTagIds = {};
    for (final bookId in widget.selectedBookIds) {
      final tags = await widget.tagRepository.getTagsForBook(bookId);
      bookTagIds[bookId] = tags.map((t) => t.id!).toSet();
    }

    final total = widget.selectedBookIds.length;

    final states = allTags.map((tag) {
      final count =
          bookTagIds.values.where((ids) => ids.contains(tag.id)).length;
      final coverage = count == total
          ? _TagCoverage.all
          : count == 0
          ? _TagCoverage.none
          : _TagCoverage.some;
      return _TagState(tag: tag, initialCoverage: coverage);
    }).toList();

    // Sort: some → all → none, then most-used first within each group.
    states.sort((a, b) {
      int coverageOrder(_TagCoverage c) {
        switch (c) {
          case _TagCoverage.some:
            return 0;
          case _TagCoverage.all:
            return 1;
          case _TagCoverage.none:
            return 2;
        }
      }

      final cmp =
      coverageOrder(a.initialCoverage).compareTo(coverageOrder(b.initialCoverage));
      if (cmp != 0) return cmp;
      // Within the same coverage group, most-used tags first.
      return b.tag.bookCount.compareTo(a.tag.bookCount);
    });

    setState(() {
      _tagStates = states;
      _loading = false;
    });
  }

  void _toggle(_TagState state) {
    setState(() {
      switch (state.intent) {
        case _TagIntent.unchanged:
        // Tags on no books skip removeAll — there's nothing to remove.
          state.intent = (state.initialCoverage == _TagCoverage.all)
              ? _TagIntent.removeAll
              : _TagIntent.addToAll;
          break;
        case _TagIntent.addToAll:
        // Tags that started on no books revert straight to unchanged
        // (removeAll would be a no-op).
          state.intent = (state.initialCoverage == _TagCoverage.none)
              ? _TagIntent.unchanged
              : _TagIntent.removeAll;
          break;
        case _TagIntent.removeAll:
          state.intent = _TagIntent.unchanged;
          break;
      }
    });
  }

  Future<void> _save() async {
    final changed =
    _tagStates.where((s) => s.intent != _TagIntent.unchanged).toList();
    if (changed.isEmpty) {
      Navigator.pop(context, 0);  // 0 instead of false
      return;
    }

    for (final state in changed) {
      for (final bookId in widget.selectedBookIds) {
        if (state.intent == _TagIntent.addToAll) {
          await widget.tagRepository.addTagToBook(bookId, state.tag.id!);
        } else if (state.intent == _TagIntent.removeAll) {
          await widget.tagRepository.removeTagFromBook(bookId, state.tag.id!);
        }
      }
    }

    if (mounted) Navigator.pop(context, widget.selectedBookIds.length);  // return count
  }

  List<_TagState> get _filtered {
    if (_query.isEmpty) return _tagStates;
    return _tagStates
        .where((s) => s.tag.name.toLowerCase().contains(_query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookCount = widget.selectedBookIds.length;
    final bookWord = bookCount == 1 ? 'book' : 'books';
    final pendingChanges =
        _tagStates.where((s) => s.intent != _TagIntent.unchanged).length;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle bar ──────────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Apply Tags',
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        '$bookCount $bookWord selected',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _loading ? null : _save,
                  child: Text(
                    pendingChanges == 0
                        ? 'Done'
                        : 'Apply ($pendingChanges)',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Legend ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _LegendItem(
                  icon: Icons.check_box,
                  color: theme.colorScheme.primary,
                  label: 'All books',
                ),
                const SizedBox(width: 16),
                _LegendItem(
                  icon: Icons.indeterminate_check_box,
                  color: theme.colorScheme.tertiary,
                  label: 'Some books',
                ),
                const SizedBox(width: 16),
                _LegendItem(
                  icon: Icons.check_box_outline_blank,
                  color: theme.colorScheme.onSurfaceVariant,
                  label: 'No books',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Search ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tags…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),

          const Divider(height: 1),

          // ── Tag list ────────────────────────────────────────────────────
          _loading
              ? const Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          )
              : _filtered.isEmpty
              ? Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'No tags found',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
              : ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: Scrollbar(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final state = _filtered[index];
                  return _TagRow(
                    state: state,
                    onTap: () => _toggle(state),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Tag row ────────────────────────────────────────────────────────────────

class _TagRow extends StatelessWidget {
  final _TagState state;
  final VoidCallback onTap;

  const _TagRow({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkVal = state.checkValue;
    final isSomeUnchanged = state.intent == _TagIntent.unchanged &&
        state.initialCoverage == _TagCoverage.some;

    // Determine checkbox icon and color based on state.
    final IconData checkIcon;
    final Color checkColor;

    if (state.intent == _TagIntent.addToAll) {
      checkIcon = Icons.check_box;
      checkColor = theme.colorScheme.primary;
    } else if (state.intent == _TagIntent.removeAll) {
      checkIcon = Icons.check_box_outline_blank;
      checkColor = theme.colorScheme.onSurfaceVariant;
    } else if (isSomeUnchanged) {
      // Indeterminate — some books have it, user hasn't acted yet.
      checkIcon = Icons.indeterminate_check_box;
      checkColor = theme.colorScheme.tertiary;
    } else if (checkVal == true) {
      checkIcon = Icons.check_box;
      checkColor = theme.colorScheme.primary;
    } else {
      checkIcon = Icons.check_box_outline_blank;
      checkColor = theme.colorScheme.onSurfaceVariant;
    }

    // Tag color dot (if the tag has a color set).
    final tagColor =
    state.tag.color != 0 ? Color(state.tag.color) : null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Checkbox icon.
            Icon(checkIcon, color: checkColor, size: 24),
            const SizedBox(width: 12),

            // Color dot.
            if (tagColor != null) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: tagColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Tag name.
            Expanded(
              child: Text(
                state.tag.name,
                style: theme.textTheme.bodyMedium,
              ),
            ),

            // Book count — always visible, muted.
            Text(
              '${state.tag.bookCount}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Legend item ────────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _LegendItem({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}