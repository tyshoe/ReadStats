import 'package:flutter/material.dart';
import '../../../../data/repositories/tag_repository.dart';
import '../../../../data/models/tag.dart';
import '/viewmodels/SettingsViewModel.dart';

/// Shows the tag selector as a modal bottom sheet, matching the bulk tag
/// sheet's design language. Returns the selected tag ids, or null if dismissed.
Future<List<int>?> showTagSelectorSheet({
  required BuildContext context,
  required Set<int> initialSelectedTagIds,
  required TagRepository tagRepository,
  required SettingsViewModel settingsViewModel,
}) {
  return showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => TagSelectorSheet(
      initialSelectedTagIds: initialSelectedTagIds,
      tagRepository: tagRepository,
      settingsViewModel: settingsViewModel,
    ),
  );
}

class TagSelectorSheet extends StatefulWidget {
  final Set<int> initialSelectedTagIds;
  final TagRepository tagRepository;
  final SettingsViewModel settingsViewModel;

  const TagSelectorSheet({
    super.key,
    required this.initialSelectedTagIds,
    required this.tagRepository,
    required this.settingsViewModel,
  });

  @override
  State<TagSelectorSheet> createState() => _TagSelectorSheetState();
}

class _TagSelectorSheetState extends State<TagSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _editTagController = TextEditingController();
  List<Tag> _allTags = [];
  late Set<int> _selectedTagIds;
  bool _isLoading = true;
  int? _editingTagId;
  String _searchQuery = '';
  String _viewFilter = 'all'; // 'all' | 'selected'
  String _sortMode = 'count'; // a key of _sortOptions

  @override
  void initState() {
    super.initState();
    _selectedTagIds = Set.from(widget.initialSelectedTagIds);
    _loadTags();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _editTagController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    setState(() => _isLoading = true);
    try {
      final tags = await widget.tagRepository.getAllTags();
      if (mounted) setState(() => _allTags = tags);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isDuplicateTag(String tagName) {
    final input = tagName.trim().toLowerCase();
    return _allTags.any((tag) => tag.name.toLowerCase() == input);
  }

  Future<void> _createNewTag() async {
    final name = _searchController.text.trim();
    if (name.isEmpty || _isDuplicateTag(name)) return;

    setState(() => _isLoading = true);
    try {
      final tag = Tag(name: name);
      final id = await widget.tagRepository.createTag(tag);
      _searchController.clear();
      await _loadTags();
      if (mounted) setState(() => _selectedTagIds.add(id));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _save() {
    Navigator.of(context).pop(_selectedTagIds.toList());
  }

  Future<void> _deleteTag(Tag tag) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag'),
        content: Text(
          'This will remove the "${tag.name}" tag from all books. '
          'Are you sure you want to delete it?',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (shouldDelete ?? false) {
      setState(() => _isLoading = true);
      try {
        await widget.tagRepository.deleteTag(tag.id!);
        _selectedTagIds.remove(tag.id);
        await _loadTags();
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _editTag(Tag tag) {
    _editTagController.text = tag.name;
    setState(() => _editingTagId = tag.id);
    FocusScope.of(context).unfocus();
    _editTagController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _editTagController.text.length,
    );
  }

  Future<void> _saveTagEdit(Tag tag) async {
    final newName = _editTagController.text.trim();
    if (newName.isEmpty || newName == tag.name) {
      setState(() => _editingTagId = null);
      return;
    }

    setState(() {
      _isLoading = true;
      _editingTagId = null;
    });

    try {
      await widget.tagRepository.updateTag(tag.copyWith(name: newName));
      await _loadTags();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleTagSelection(Tag tag) {
    if (_editingTagId != null) return;
    setState(() {
      if (_selectedTagIds.contains(tag.id)) {
        _selectedTagIds.remove(tag.id);
      } else {
        _selectedTagIds.add(tag.id!);
      }
    });
  }

  Widget _buildTagListRow(Tag tag, Color accentColor, ThemeData theme) {
    final isSelected = _selectedTagIds.contains(tag.id);
    final isEditing = _editingTagId == tag.id;
    final tagColor = tag.color != 0 ? Color(tag.color) : null;

    return InkWell(
      onTap: isEditing ? null : () => _toggleTagSelection(tag),
      child: Container(
        color: isEditing ? accentColor.withValues(alpha: 0.10) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 24,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
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
            Expanded(
              child: isEditing
                  ? TextField(
                      controller: _editTagController,
                      autofocus: true,
                      style: theme.textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _saveTagEdit(tag),
                    )
                  : Text(tag.name, style: theme.textTheme.bodyMedium),
            ),
            if (isEditing)
              IconButton(
                icon: Icon(Icons.check, color: accentColor),
                iconSize: 20,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
                onPressed: () => _saveTagEdit(tag),
              )
            else ...[
              Text(
                '${tag.bookCount}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              PopupMenuButton<String>(
                position: PopupMenuPosition.under,
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'edit') _editTag(tag);
                  if (value == 'delete') _deleteTag(tag);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 12),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Delete',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTagChip({
    required ThemeData theme,
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      labelStyle: theme.textTheme.bodySmall,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      selectedColor: theme.colorScheme.primaryContainer,
      elevation: 0,
      pressElevation: 0,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    final selectedCount = _selectedTagIds.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _buildTagChip(
            theme: theme,
            label: 'All',
            selected: _viewFilter == 'all',
            onSelected: () => setState(() => _viewFilter = 'all'),
          ),
          const SizedBox(width: 8),
          _buildTagChip(
            theme: theme,
            label: selectedCount > 0 ? 'Selected ($selectedCount)' : 'Selected',
            selected: _viewFilter == 'selected',
            onSelected: () => setState(() => _viewFilter = 'selected'),
          ),
          const Spacer(),
          _buildSortControl(theme),
        ],
      ),
    );
  }

  static const Map<String, ({IconData icon, String label})> _sortOptions = {
    'count': (icon: Icons.trending_up_rounded, label: 'Most used'),
    'count_asc': (icon: Icons.trending_down_rounded, label: 'Least used'),
    'name': (icon: Icons.sort_by_alpha_rounded, label: 'A–Z'),
    'recent': (icon: Icons.schedule_rounded, label: 'Recently added'),
  };

  Widget _buildSortControl(ThemeData theme) {
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;
    final label = _sortOptions[_sortMode]!.label;

    PopupMenuItem<String> item(String value) {
      final option = _sortOptions[value]!;
      final selected = _sortMode == value;
      return PopupMenuItem<String>(
        value: value,
        child: Row(
          children: [
            Icon(
              option.icon,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Text(option.label),
            if (selected) ...[
              const Spacer(),
              Icon(Icons.check, size: 18, color: accentColor),
            ],
          ],
        ),
      );
    }

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<String>(
        initialValue: _sortMode,
        position: PopupMenuPosition.under,
        onSelected: (value) => setState(() => _sortMode = value),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tooltip: 'Sort',
        itemBuilder: (context) =>
            _sortOptions.keys.map((value) => item(value)).toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sort_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(label, style: theme.textTheme.bodySmall),
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Tag> get _filteredTags {
    if (_searchQuery.isEmpty) return _allTags;
    return _allTags
        .where((tag) => tag.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  List<Tag> get _sortedTags {
    var filtered = _filteredTags;

    if (_viewFilter == 'selected') {
      filtered = filtered
          .where((tag) => _selectedTagIds.contains(tag.id))
          .toList();
    }

    final selected = filtered
        .where((tag) => _selectedTagIds.contains(tag.id))
        .toList();
    final unselected = filtered
        .where((tag) => !_selectedTagIds.contains(tag.id))
        .toList();

    int compare(Tag a, Tag b) {
      switch (_sortMode) {
        case 'name':
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'count_asc':
          return a.bookCount.compareTo(b.bookCount);
        case 'recent':
          // id is autoincrement, so higher id == more recently created.
          return (b.id ?? 0).compareTo(a.id ?? 0);
        case 'count':
        default:
          return b.bookCount.compareTo(a.bookCount);
      }
    }

    selected.sort(compare);
    unselected.sort(compare);

    return [...selected, ...unselected];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;
    final sortedTags = _sortedTags;
    final canCreateTag =
        _searchQuery.isNotEmpty && !_isDuplicateTag(_searchQuery);

    // Shrink the list when the keyboard is up (e.g. editing a tag inline) so
    // the sheet's fixed chrome + list never exceeds the visible area.
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final maxListHeight = (screenHeight - keyboardInset - 280).clamp(
      120.0,
      screenHeight * 0.5,
    );
    // Keep the sheet from collapsing to a stub when there are few tags.
    // Reduced by the keyboard inset so it never forces an overflow.
    final minSheetHeight = (screenHeight * 0.5 - keyboardInset).clamp(
      0.0,
      screenHeight,
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minSheetHeight),
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
                    child: Text('Tags', style: theme.textTheme.titleLarge),
                  ),
                  FilledButton(
                    onPressed: _isLoading ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: accentColor),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Search / create ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search or create tag…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (canCreateTag)
                        TextButton(
                          onPressed: _createNewTag,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            'Create',
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                    ],
                  ),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.toLowerCase());
                },
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty && canCreateTag) {
                    _createNewTag();
                  }
                },
              ),
            ),
            const SizedBox(height: 8),

            // ── Filter / sort bar ───────────────────────────────────────────
            if (_allTags.isNotEmpty) _buildFilterBar(theme),

            const Divider(height: 1),

            // ── Tag list ────────────────────────────────────────────────────
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              )
            else if (sortedTags.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 24,
                ),
                child: Column(
                  children: [
                    Icon(
                      _viewFilter == 'selected'
                          ? Icons.bookmark_border_rounded
                          : Icons.sell_outlined,
                      size: 56,
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _viewFilter == 'selected'
                          ? 'No tags selected'
                          : _searchQuery.isEmpty
                          ? 'No tags yet'
                          : 'No matching tags',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _viewFilter == 'selected'
                          ? 'Tap a tag to add it to this book'
                          : _searchQuery.isEmpty
                          ? 'Start typing to create your first tag'
                          : 'Type to create "$_searchQuery"',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxListHeight),
                child: Scrollbar(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: sortedTags.length,
                    itemBuilder: (context, index) =>
                        _buildTagListRow(sortedTags[index], accentColor, theme),
                  ),
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
