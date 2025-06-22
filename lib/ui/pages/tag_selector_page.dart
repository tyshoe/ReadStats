import 'package:flutter/material.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/models/tag.dart';
import '/viewmodels/SettingsViewModel.dart';

class TagSelectorSheet extends StatefulWidget {
  final Set<int> initialSelectedTagIds;
  final TagRepository tagRepository;
  final SettingsViewModel settingsViewModel;
  final bool isCreationMode;

  const TagSelectorSheet({
    Key? key,
    required this.initialSelectedTagIds,
    required this.tagRepository,
    required this.settingsViewModel,
    this.isCreationMode = false,
  }) : super(key: key);

  @override
  State<TagSelectorSheet> createState() => _TagSelectorSheetState();
}

class _TagSelectorSheetState extends State<TagSelectorSheet> {
  List<Tag> _allTags = [];
  late Set<int> _selectedTagIds;
  final TextEditingController _newTagController = TextEditingController();
  bool _isLoading = true;
  int? _editingTagId;
  final TextEditingController _editTagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedTagIds = Set.from(widget.initialSelectedTagIds);
    _loadTags();
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

  Future<void> _createNewTag() async {
    final name = _newTagController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final tag = Tag(name: name);
      final id = await widget.tagRepository.createTag(tag);
      _newTagController.clear();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Tags'),
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isLoading ? null : _save,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // New tag input
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _newTagController,
              decoration: InputDecoration(
                labelText: 'Create new tag',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _createNewTag,
                ),
              ),
              onSubmitted: (_) => _createNewTag(),
            ),
          ),

          // Tags list
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // "All" chip
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_selectedTagIds.length == _allTags.length) {
                          _selectedTagIds.clear();
                        } else {
                          _selectedTagIds = _allTags.map((t) => t.id!).toSet();
                        }
                      });
                    },
                    child: Chip(
                      label: const Text('All'),
                      avatar: _selectedTagIds.length == _allTags.length
                          ? const Icon(Icons.check, size: 18)
                          : null,
                      backgroundColor: _selectedTagIds.length == _allTags.length
                          ? accentColor.withOpacity(0.3)
                          : theme.colorScheme.surfaceVariant,
                    ),
                  ),
                  // Tag chips
                  ..._allTags.map((tag) {
                    final isSelected = _selectedTagIds.contains(tag.id);
                    final isEditing = _editingTagId == tag.id;

                    if (isEditing) {
                      return _buildEditTagInput(tag, accentColor);
                    }

                    return GestureDetector(
                      onTap: () => _toggleTagSelection(tag),
                      onLongPress: () => _showTagOptions(tag),
                      child: Chip(
                        label: Text(tag.name),
                        avatar: isSelected
                            ? const Icon(Icons.check, size: 18)
                            : null,
                        backgroundColor: isSelected
                            ? accentColor.withOpacity(0.3)
                            : theme.colorScheme.surfaceVariant,
                      ),
                    );
                  }),
                ],
              ),
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
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      side: BorderSide(color: accentColor),
    );
  }

  @override
  void dispose() {
    _newTagController.dispose();
    _editTagController.dispose();
    super.dispose();
  }
}