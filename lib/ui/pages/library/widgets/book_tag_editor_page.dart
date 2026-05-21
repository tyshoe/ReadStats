import 'package:flutter/material.dart';
import '../../../../data/repositories/tag_repository.dart';
import '../../../../data/models/tag.dart';
import '/viewmodels/SettingsViewModel.dart';

class TagSelectorSheet extends StatefulWidget {
  final Set<int> initialSelectedTagIds;
  final TagRepository tagRepository;
  final SettingsViewModel settingsViewModel;
  final bool isCreationMode;

  const TagSelectorSheet({
    super.key,
    required this.initialSelectedTagIds,
    required this.tagRepository,
    required this.settingsViewModel,
    this.isCreationMode = false,
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

  // #4: removed spurious loading state — just pop
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

  // #6 & #7: removed Future.delayed hack and leaking FocusNode
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

  void _showTagOptions(Tag tag, Offset tapPosition) {
    final theme = Theme.of(context);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy,
        tapPosition.dx,
        tapPosition.dy,
      ),
      items: [
        const PopupMenuItem(value: 'edit', child: Row(
          children: [
            Icon(Icons.edit, size: 18),
            SizedBox(width: 12),
            Text('Edit'),
          ],
        )),
        PopupMenuItem(value: 'delete', child: Row(
          children: [
            Icon(Icons.delete, size: 18, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
          ],
        )),
      ],
    ).then((value) {
      if (value == 'edit') _editTag(tag);
      if (value == 'delete') _deleteTag(tag);
    });
  }

  Widget _buildEditTagInput(Tag tag, Color accentColor) {
    return InputChip(
      label: IntrinsicWidth(
        child: TextField(
          controller: _editTagController,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
          ),
          autofocus: true,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      deleteIcon: const Icon(Icons.check, size: 18),
      onDeleted: () => _saveTagEdit(tag),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      side: BorderSide(color: accentColor),
    );
  }

  List<Tag> get _filteredTags {
    if (_searchQuery.isEmpty) return _allTags;
    return _allTags.where((tag) =>
        tag.name.toLowerCase().contains(_searchQuery)
    ).toList();
  }

  List<Tag> get _sortedTags {
    final filtered = _filteredTags;

    final selected = filtered.where((tag) => _selectedTagIds.contains(tag.id)).toList();
    final unselected = filtered.where((tag) => !_selectedTagIds.contains(tag.id)).toList();

    selected.sort((a, b) => b.bookCount.compareTo(a.bookCount));
    unselected.sort((a, b) => b.bookCount.compareTo(a.bookCount));

    return [...selected, ...unselected];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;
    final sortedTags = _sortedTags;
    // #5: removed redundant third condition — _isDuplicateTag already covers it
    final canCreateTag = _searchQuery.isNotEmpty && !_isDuplicateTag(_searchQuery);

    return Scaffold(
      // #2: removed save TextButton from AppBar
      appBar: AppBar(
        title: const Text('Edit Tags'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // #1: matches book form field style
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: TextField(
                          controller: _searchController,
                          autofocus: false,
                          decoration: InputDecoration(
                            hintText: 'Search or create tag...',
                            prefixIcon: const Icon(Icons.search, size: 20),
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                            setState(() {
                              _searchQuery = value.toLowerCase();
                            });
                          },
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty && canCreateTag) {
                              _createNewTag();
                            }
                          },
                        ),
                      ),

                      Expanded(
                        child: sortedTags.isEmpty && _searchQuery.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.sell_outlined,
                                      size: 64,
                                      // #3: withOpacity → withAlpha
                                      color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No tags yet',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Start typing to create your first tag',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 0,
                                  children: sortedTags.map((tag) {
                                    final isSelected = _selectedTagIds.contains(tag.id);
                                    final isEditing = _editingTagId == tag.id;

                                    if (isEditing) {
                                      return _buildEditTagInput(tag, accentColor);
                                    }

                                    return GestureDetector(
                                      onLongPressStart: (details) => _showTagOptions(tag, details.globalPosition),
                                      child: FilterChip(
                                        label: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(tag.name),
                                            const SizedBox(width: 4),
                                            Text(
                                              '(${tag.bookCount})',
                                              style: TextStyle(
                                                fontSize: 11,
                                                // #3: withOpacity → withAlpha
                                                color: isSelected
                                                    ? theme.colorScheme.onPrimaryContainer.withAlpha(179)
                                                    : theme.colorScheme.onSurfaceVariant.withAlpha(179),
                                              ),
                                            ),
                                          ],
                                        ),
                                        selected: isSelected,
                                        onSelected: (_) => _toggleTagSelection(tag),
                                        selectedColor: theme.colorScheme.primaryContainer,
                                        checkmarkColor: accentColor,
                                        showCheckmark: true,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          side: BorderSide(
                                            color: isSelected
                                                ? Colors.transparent
                                                : theme.colorScheme.outline,
                                          ),
                                        ),
                                        labelStyle: theme.textTheme.bodyMedium,
                                        clipBehavior: Clip.none,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                    ],
                  ),
          ),
          // #2: FilledButton at bottom, matching book form pattern
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                onPressed: _isLoading ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Save'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
