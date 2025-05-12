import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/models/tag.dart';
import '/viewmodels/SettingsViewModel.dart';

class TagSelectorSheet extends StatefulWidget {
  final int bookId;
  final TagRepository tagRepository;
  final SettingsViewModel settingsViewModel;

  const TagSelectorSheet({
    Key? key,
    required this.bookId,
    required this.tagRepository,
    required this.settingsViewModel,
  }) : super(key: key);

  @override
  State<TagSelectorSheet> createState() => _TagSelectorSheetState();
}

class _TagSelectorSheetState extends State<TagSelectorSheet> {
  List<Tag> _allTags = [];
  Set<int> _selectedTagIds = {};
  final TextEditingController _newTagController = TextEditingController();
  bool _isLoading = true;
  int? _editingTagId;
  final TextEditingController _editTagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    setState(() => _isLoading = true);
    try {
      final tags = await widget.tagRepository.getAllTags();
      final existing = await widget.tagRepository.getTagsForBook(widget.bookId);
      setState(() {
        _allTags = tags;
        _selectedTagIds = existing.map((tag) => tag.id!).toSet();
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
      for (final tag in _allTags) {
        if (_selectedTagIds.contains(tag.id)) {
          await widget.tagRepository.addTagToBook(widget.bookId, tag.id!);
        } else {
          await widget.tagRepository.removeTagFromBook(widget.bookId, tag.id!);
        }
      }
      Navigator.of(context).pop();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTag(Tag tag) async {
    final shouldDelete = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Tag'),
        content: Text(
          'This will remove the "${tag.name}" tag from all books. '
          'Are you sure you want to delete it?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
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
        await _loadTags();
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editTag(Tag tag) async {
    _editTagController.text = tag.name;
    setState(() => _editingTagId = tag.id);

    // Optional: Auto-focus and select all text
    await Future.delayed(Duration(milliseconds: 100));
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

  void _cancelEdit() {
    setState(() => _editingTagId = null);
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

  Color _getIconColorBasedOnAccentColor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
  }

  void _showTagOptions(Tag tag) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _editTag(tag);
            },
            child: const Text('Edit Tag'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _deleteTag(tag);
            },
            child: const Text('Delete Tag'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;
    final textColor = CupertinoColors.label.resolveFrom(context);
    final fieldBackColor =
        CupertinoColors.systemGrey5.resolveFrom(context).withOpacity(0.8);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Select Tags'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _save,
          child: const Icon(CupertinoIcons.check_mark),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : Column(
                children: [
                  // New tag input
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            fieldBackColor, // Change this to your desired color
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: CupertinoTextField(
                        controller: _newTagController,
                        placeholder: 'Create new tag',
                        decoration: null,
                        suffix: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _createNewTag,
                          child: const Icon(CupertinoIcons.add_circled),
                        ),
                        onSubmitted: (_) => _createNewTag(),
                      ),
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
                                  _selectedTagIds =
                                      _allTags.map((t) => t.id!).toSet();
                                }
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedTagIds.length == _allTags.length
                                    ? accentColor.withOpacity(0.3)
                                    : fieldBackColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_selectedTagIds.length ==
                                      _allTags.length) ...[
                                    Icon(
                                      CupertinoIcons.check_mark,
                                      size: 18,
                                      color: _getIconColorBasedOnAccentColor(
                                          accentColor.withOpacity(0.3)),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    'All',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _selectedTagIds.length ==
                                              _allTags.length
                                          ? _getIconColorBasedOnAccentColor(
                                              accentColor.withOpacity(0.3))
                                          : textColor,
                                    ),
                                  ),
                                ],
                              ),
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
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? accentColor.withOpacity(0.3)
                                      : fieldBackColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSelected)
                                      Icon(
                                        CupertinoIcons.check_mark,
                                        size: 18,
                                        color: _getIconColorBasedOnAccentColor(
                                            accentColor.withOpacity(0.3)),
                                      ),
                                    if (isSelected) const SizedBox(width: 6),
                                    Text(
                                      tag.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: isSelected
                                            ? _getIconColorBasedOnAccentColor(
                                                accentColor.withOpacity(0.3))
                                            : textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEditTagInput(Tag tag, Color accentColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 100,
            child: CupertinoTextField(
              controller: _editTagController,
              placeholder: tag.name,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: null,
              autofocus: true,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            minSize: 20,
            onPressed: () => _saveTagEdit(tag),
            child: const Icon(CupertinoIcons.check_mark, size: 18),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            minSize: 20,
            onPressed: _cancelEdit,
            child: const Icon(CupertinoIcons.clear, size: 18),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _newTagController.dispose();
    _editTagController.dispose();
    super.dispose();
  }
}
