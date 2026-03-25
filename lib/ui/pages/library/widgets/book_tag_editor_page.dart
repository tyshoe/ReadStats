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
      setState(() {
        _allTags = tags;
      });
    } finally {
      setState(() => _isLoading = false);
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
      setState(() => _selectedTagIds.add(id));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      Navigator.of(context).pop(_selectedTagIds.toList());
    } finally {
      if (!widget.isCreationMode) {
        setState(() => _isLoading = false);
      }
    }
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
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editTag(Tag tag) async {
    _editTagController.text = tag.name;
    setState(() => _editingTagId = tag.id);

    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    FocusScope.of(context).requestFocus(FocusNode());

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
      setState(() => _isLoading = false);
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

  void _showTagOptions(Tag tag) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Tag'),
            onTap: () {
              Navigator.pop(context);
              _editTag(tag);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
            title: Text(
              'Delete Tag',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () {
              Navigator.pop(context);
              _deleteTag(tag);
            },
          ),
          const SizedBox(height: 8),
          SafeArea(
            child: TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditTagInput(Tag tag, Color accentColor) {
    return InputChip(
      label: SizedBox(
        width: 100,
        child: TextField(
          controller: _editTagController,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
          ),
          autofocus: true,
          style: const TextStyle(fontSize: 16),
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

    // Split into selected and unselected
    final selected = filtered.where((tag) => _selectedTagIds.contains(tag.id)).toList();
    final unselected = filtered.where((tag) => !_selectedTagIds.contains(tag.id)).toList();

    // Sort each group by book count (highest to lowest)
    selected.sort((a, b) => b.bookCount.compareTo(a.bookCount));
    unselected.sort((a, b) => b.bookCount.compareTo(a.bookCount));

    // Return selected first, then unselected
    return [...selected, ...unselected];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;
    final sortedTags = _sortedTags;
    final canCreateTag = _searchQuery.isNotEmpty &&
        !_isDuplicateTag(_searchQuery) &&
        !_allTags.any((tag) => tag.name.toLowerCase() == _searchQuery);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Tags'),
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: Text(
              'Save',
              style: TextStyle(color: accentColor),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Combined search and create field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search or create tag...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
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

          // Tags list
          Expanded(
            child: sortedTags.isEmpty && _searchQuery.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sell_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
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
                    onLongPress: () => _showTagOptions(tag),
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
                              color: isSelected
                                  ? theme.colorScheme.onPrimaryContainer.withOpacity(0.7)
                                  : theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
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
    );
  }
}