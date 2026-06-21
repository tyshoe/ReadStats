import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../widgets/app_snackbar.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:read_stats/ui/pages/library/widgets/book_tag_editor_page.dart';
import 'package:read_stats/ui/pages/library/widgets/barcode_scanner_page.dart';
import 'package:read_stats/data/services/book_search_service.dart';
import '../../../data/database/database_helper.dart';
import '../../../data/models/book.dart';
import '../../../data/models/tag.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../data/repositories/tag_repository.dart';
import '../../../data/services/cover_service.dart';
import '/viewmodels/SettingsViewModel.dart';

class BookFormPage extends StatefulWidget {
  final Map<String, dynamic>? book;
  final BookSearchResult? searchResult;
  final Function(Map<String, dynamic>) onSave;
  final SettingsViewModel settingsViewModel;
  final bool isEditing;

  const BookFormPage({
    super.key,
    this.book,
    this.searchResult,
    required this.onSave,
    required this.settingsViewModel,
  }) : isEditing = book != null;

  @override
  State<BookFormPage> createState() => _BookFormPageState();
}

class _BookFormPageState extends State<BookFormPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _wordCountController = TextEditingController();
  final TextEditingController _pageCountController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();
  final TextEditingController _isbnController = TextEditingController();
  final TextEditingController _userReviewController = TextEditingController();
  final TextEditingController _durationHoursController =
      TextEditingController();
  final TextEditingController _durationMinutesController =
      TextEditingController();
  final DateTime _dateToday = DateTime.now();
  double? _rating;
  bool _isFavorite = false;
  int _shelfId = DatabaseHelper.shelfWantToRead;
  List<Map<String, dynamic>> _shelves = [];
  int _selectedBookType = 0;
  DateTime? _dateStarted;
  DateTime? _dateFinished;
  late bool _useStarRating;
  Set<int> _selectedTagIds = {};
  bool _titleTitleCaseEnabled = true;
  bool _authorTitleCaseEnabled = true;
  File? _coverFile;
  String? _coverUrl;
  bool _coverChanged = false;
  bool _isPickingCover = false;

  @override
  void initState() {
    super.initState();
    _useStarRating =
        widget.settingsViewModel.defaultRatingStyleNotifier.value == 0;
    _selectedBookType =
        widget.settingsViewModel.defaultBookTypeNotifier.value - 1;
    _loadShelves();

    if (widget.searchResult != null) {
      _prefillFromSearchResult(widget.searchResult!);
    }

    if (widget.isEditing) {
      _titleController.text = widget.book!['title'];
      _authorController.text = widget.book!['author'];
      final editWordCount = widget.book!['word_count'] as int?;
      final editPageCount = widget.book!['page_count'] as int?;
      if (editWordCount != null && editWordCount > 0)
        _wordCountController.text = editWordCount.toString();
      if (editPageCount != null && editPageCount > 0)
        _pageCountController.text = editPageCount.toString();
      _rating = widget.book!['rating']?.toDouble();
      _ratingController.text = _rating?.toStringAsFixed(2) ?? '';
      _shelfId = (widget.book!['shelf_id'] as int?) ?? 1;
      _isFavorite = widget.book!['is_favorite'] == 1;
      _selectedBookType = widget.book!['book_type_id'] - 1;
      final editDuration = widget.book!['duration_minutes'] as int?;
      if (editDuration != null && editDuration > 0) {
        _durationHoursController.text = (editDuration ~/ 60).toString();
        _durationMinutesController.text = (editDuration % 60).toString();
      }
      _isbnController.text = widget.book!['isbn'] ?? '';
      _userReviewController.text = widget.book!['user_review'] ?? '';
      _dateStarted = widget.book!['date_started'] != null
          ? DateTime.parse(widget.book!['date_started'])
          : null;
      _dateFinished = widget.book!['date_finished'] != null
          ? DateTime.parse(widget.book!['date_finished'])
          : null;
      _loadExistingTags();
      if (widget.book!['cover_path'] != null) {
        _coverFile = File(widget.book!['cover_path'] as String);
      }
    }
  }

  Future<void> _loadShelves() async {
    final shelves = await DatabaseHelper().getShelves();
    if (mounted) {
      setState(() {
        _shelves = shelves;
        // Guard: if current shelfId isn't in the loaded list, fall back to first
        if (_shelves.isNotEmpty && !_shelves.any((s) => s['id'] == _shelfId)) {
          _shelfId = DatabaseHelper.shelfWantToRead;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _wordCountController.dispose();
    _pageCountController.dispose();
    _ratingController.dispose();
    _isbnController.dispose();
    _userReviewController.dispose();
    _durationHoursController.dispose();
    _durationMinutesController.dispose();
    super.dispose();
  }

  void _saveBook() async {
    String title = _titleController.text.trim();
    String author = _authorController.text.trim();
    final bool savingAsAudiobook = _selectedBookType == 3;
    final int? wordCount = savingAsAudiobook
        ? null
        : int.tryParse(_wordCountController.text);
    final int? pageCount = savingAsAudiobook
        ? null
        : int.tryParse(_pageCountController.text);

    if (title.isEmpty || author.isEmpty) return;

    final bookRepository = BookRepository(DatabaseHelper());
    final bookExists = await bookRepository.doesBookExist(
      title,
      author,
      excludeId: widget.isEditing ? widget.book!['id'] : null,
    );

    if (bookExists && !widget.isEditing) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Duplicate Book'),
          content: const Text(
            'A book with this title and author already exists. '
            'Are you sure you want to add it anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add Anyway'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) {
        return;
      }
    }

    const finishedShelfId = DatabaseHelper.shelfFinished;

    final bookData = {
      if (widget.isEditing && widget.book!['id'] != null)
        "id": widget.book!['id'],
      "title": title,
      "author": author,
      "word_count": wordCount,
      "page_count": pageCount,
      "rating": _rating?.toDouble(),
      "is_favorite": _isFavorite ? 1 : 0,
      "shelf_id": _shelfId,
      "book_type_id": _selectedBookType + 1,
      "date_started": _dateStarted?.toIso8601String(),
      "date_finished": _shelfId == finishedShelfId
          ? (_dateFinished ?? DateTime.now()).toIso8601String()
          : _dateFinished?.toIso8601String(),
      "date_added": widget.isEditing
          ? widget.book!['date_added']
          : DateTime.now().toIso8601String(),
      "isbn": _isbnController.text.trim().isEmpty
          ? null
          : _isbnController.text.replaceAll(RegExp(r'[\s-]'), ''),
      "duration_minutes": () {
        if (!savingAsAudiobook) return null;
        final h = int.tryParse(_durationHoursController.text) ?? 0;
        final m = int.tryParse(_durationMinutesController.text) ?? 0;
        final total = h * 60 + m;
        return total > 0 ? total : null;
      }(),
      "user_review": _userReviewController.text.trim().isEmpty
          ? null
          : _userReviewController.text.trim(),
      "cover_path": widget.isEditing
          ? widget.book!['cover_path'] as String?
          : null,
      "open_library_key": widget.isEditing
          ? widget.book!['open_library_key'] as String?
          : widget.searchResult?.workKey,
    };

    try {
      if (widget.isEditing && widget.book!['id'] != null) {
        final bookId = widget.book!['id'] as int;
        await bookRepository.updateBook(Book.fromMap(bookData));

        final tagRepo = TagRepository(DatabaseHelper());
        final currentTags = await tagRepo.getTagsForBook(bookId);
        final currentTagIds = currentTags.map((t) => t.id!).toSet();

        for (final tagId in _selectedTagIds) {
          if (!currentTagIds.contains(tagId)) {
            await tagRepo.addTagToBook(bookId, tagId);
          }
        }

        for (final tagId in currentTagIds) {
          if (!_selectedTagIds.contains(tagId)) {
            await tagRepo.removeTagFromBook(bookId, tagId);
          }
        }

        if (_coverChanged) {
          if (_coverFile == null) {
            await CoverService.deleteByPath(
              widget.book!['cover_path'] as String?,
            );
            await bookRepository.updateCoverPath(bookId, null);
          } else {
            final newPath = await CoverService.saveFromPath(
              bookId,
              _coverFile!.path,
            );
            await bookRepository.updateCoverPath(bookId, newPath);
          }
        }
      } else {
        final newBookId = await bookRepository.addBook(Book.fromMap(bookData));

        if (_selectedTagIds.isNotEmpty) {
          final tagRepo = TagRepository(DatabaseHelper());
          for (final tagId in _selectedTagIds) {
            await tagRepo.addTagToBook(newBookId, tagId);
          }
        }

        if (_coverFile != null) {
          final newPath = await CoverService.saveFromPath(
            newBookId,
            _coverFile!.path,
          );
          await bookRepository.updateCoverPath(newBookId, newPath);
        }
      }

      widget.onSave(bookData);
      _handleSaveSuccess();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving book: $e');
    }
  }

  Future<void> _loadExistingTags() async {
    try {
      if (widget.book!['id'] != null) {
        final tags = await TagRepository(
          DatabaseHelper(),
        ).getTagsForBook(widget.book!['id']);
        setState(() {
          _selectedTagIds = tags.map((tag) => tag.id!).toSet();
        });
      }
    } catch (e) {
      debugPrint('Error loading tags: $e');
    }
  }

  void _handleSaveSuccess() {
    AppSnackbar.show(
      widget.isEditing
          ? 'Book updated successfully!'
          : 'Book added successfully!',
    );
    if (!widget.isEditing) {
      _clearFormInputs();
    }
  }

  void _clearFormInputs() {
    _titleController.clear();
    _authorController.clear();
    _wordCountController.clear();
    _pageCountController.clear();
    _isbnController.clear();
    _userReviewController.clear();
    setState(() {
      _rating = 0;
      _isFavorite = false;
      _shelfId = DatabaseHelper.shelfWantToRead;
      _durationHoursController.clear();
      _durationMinutesController.clear();
      _selectedBookType =
          widget.settingsViewModel.defaultBookTypeNotifier.value - 1;
      _dateStarted = null;
      _dateFinished = null;
    });
  }

  void _prefillFromSearchResult(BookSearchResult result) {
    _titleController.text = result.title;
    _authorController.text = result.author;
    if (result.pageCount != null)
      _pageCountController.text = result.pageCount.toString();
    if (result.isbn != null) _isbnController.text = result.isbn!;
    if (result.thumbnailUrl != null) {
      _coverUrl = result.thumbnailUrl;
      CoverService.downloadFromUrl(result.thumbnailUrl!).then((file) {
        if (file != null && mounted) {
          setState(() => _coverFile = file);
        }
      });
    }
  }

  Future<void> _lookupByIsbn(String isbn) async {
    final result = await BookSearchService.lookupByIsbn(isbn);
    if (result == null || !mounted) return;
    if (_titleController.text.isEmpty) {
      _titleController.text = result.title;
    }
    if (_authorController.text.isEmpty) {
      _authorController.text = result.author;
    }
    if (_pageCountController.text.isEmpty && result.pageCount != null) {
      _pageCountController.text = result.pageCount.toString();
    }
    setState(() {});
    if (_coverFile == null && result.thumbnailUrl != null) {
      final file = await CoverService.downloadFromUrl(result.thumbnailUrl!);
      if (file != null && mounted) {
        setState(() {
          _coverFile = file;
          _coverChanged = true;
        });
      }
    }
  }

  void _clearStartDate() {
    setState(() {
      _dateStarted = null;
    });
  }

  void _clearFinishDate() {
    setState(() {
      _dateFinished = null;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? _dateStarted ?? _dateToday
          : _dateFinished ?? _dateStarted ?? _dateToday,
      firstDate: isStartDate ? DateTime(1900) : _dateStarted ?? DateTime(1900),
      lastDate: _dateToday,
      builder: (BuildContext context, Widget? child) {
        return Theme(data: Theme.of(context), child: child!);
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _dateStarted = picked;
          if (_dateFinished != null && _dateFinished!.isBefore(picked)) {
            _dateFinished = null;
          }
          // Auto-advance to Currently Reading only if currently on Want to Read
          if (_shelfId == DatabaseHelper.shelfWantToRead) {
            _shelfId = DatabaseHelper.shelfCurrentlyReading;
          }
        } else {
          _dateFinished = picked;
          _shelfId = DatabaseHelper.shelfFinished;
        }
      });
    }
  }

  Future<List<Tag>> _getTagsByIds(List<int> tagIds) async {
    if (tagIds.isEmpty) return [];
    final allTags = await TagRepository(DatabaseHelper()).getAllTags();
    return allTags.where((tag) => tagIds.contains(tag.id)).toList();
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;

    final wordsToLowercase = {
      'a',
      'an',
      'the',
      'and',
      'but',
      'or',
      'nor',
      'as',
      'at',
      'by',
      'for',
      'from',
      'in',
      'into',
      'near',
      'of',
      'on',
      'onto',
      'to',
      'with',
    };

    final words = text.split(' ');
    final result = StringBuffer();

    for (int i = 0; i < words.length; i++) {
      if (words[i].isNotEmpty) {
        final currentWord = words[i].toLowerCase();

        if (i == 0 || !wordsToLowercase.contains(currentWord)) {
          result.write(words[i][0].toUpperCase());
          if (words[i].length > 1) {
            result.write(words[i].substring(1).toLowerCase());
          }
        } else {
          result.write(currentWord);
        }

        if (i < words.length - 1) {
          result.write(' ');
        }
      }
    }

    return result.toString();
  }

  Widget _buildCoverPicker() {
    final theme = Theme.of(context);
    const double coverW = 150;
    const double coverH = 230;
    final bool hasCover = _coverFile != null || _coverUrl != null;
    final double areaH = hasCover ? 300.0 : 90.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: areaH,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background — blurred cover or plain surface
            if (_coverUrl != null)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: Image.network(_coverUrl!, fit: BoxFit.cover),
                ),
              )
            else if (_coverFile != null)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: Image.file(_coverFile!, fit: BoxFit.cover),
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
              ),

            // Dim overlay so cover pops
            if (hasCover)
              Positioned.fill(
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),

            // Ripple layer — above backgrounds so the ink is visible
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () async {
                    if (_isPickingCover) return;
                    setState(() => _isPickingCover = true);
                    try {
                      final file = await CoverService.pickImage();
                      if (file != null && mounted) {
                        setState(() {
                          _coverFile = file;
                          _coverUrl = null;
                          _coverChanged = true;
                        });
                      }
                    } finally {
                      if (mounted) setState(() => _isPickingCover = false);
                    }
                  },
                ),
              ),
            ),

            // Cover image
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _coverUrl != null
                      ? Image.network(
                          _coverUrl!,
                          width: coverW,
                          height: coverH,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return _CoverLoadingPlaceholder(
                              width: coverW,
                              height: coverH,
                              theme: theme,
                              progress: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                  : null,
                            );
                          },
                          errorBuilder: (_, __, ___) =>
                              _coverPlaceholder(theme, coverW, coverH),
                        )
                      : _coverFile != null
                      ? Image.file(
                          _coverFile!,
                          width: coverW,
                          height: coverH,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _coverPlaceholder(theme, coverW, coverH),
                        )
                      : _emptyPlaceholder(theme),
                ),
              ],
            ),

            // Remove button — top-right corner
            if (hasCover)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _coverFile = null;
                      _coverUrl = null;
                      _coverChanged = true;
                    });
                  },
                  icon: const Icon(Icons.delete, size: 22),
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.error.withValues(
                      alpha: 0.85,
                    ),
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyPlaceholder(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          'Add cover image',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _coverPlaceholder(ThemeData theme, double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Text(
            'Add cover',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outline;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Title',
              hintText: 'Enter book title',
              floatingLabelBehavior: FloatingLabelBehavior.auto,
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
            onChanged: (value) {
              if (_titleTitleCaseEnabled && value.isNotEmpty) {
                final formattedValue = _toTitleCase(value);
                if (value != formattedValue) {
                  final cursorPos = _titleController.selection.baseOffset;
                  _titleController.value = _titleController.value.copyWith(
                    text: formattedValue,
                    selection: TextSelection.collapsed(offset: cursorPos),
                  );
                }
              }
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          height: 56,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _titleTitleCaseEnabled = !_titleTitleCaseEnabled;
                if (_titleController.text.isNotEmpty) {
                  _titleController.text = _titleTitleCaseEnabled
                      ? _toTitleCase(_titleController.text)
                      : _titleController.text.toLowerCase();
                }
              });
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _titleTitleCaseEnabled
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.text_fields,
                color: _titleTitleCaseEnabled
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthorField() {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outline;

    return Row(
      children: [
        Expanded(
          child: Autocomplete<String>(
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<String>.empty();
              }
              return BookRepository(
                DatabaseHelper(),
              ).getAuthorSuggestions(textEditingValue.text);
            },
            fieldViewBuilder:
                (context, textEditingController, focusNode, onFieldSubmitted) {
                  textEditingController.text = _authorController.text;
                  _authorController.addListener(() {
                    if (textEditingController.text != _authorController.text) {
                      textEditingController.text = _authorController.text;
                    }
                  });

                  return TextField(
                    controller: _authorController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Author',
                      hintText: 'Enter author',
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
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
                    onChanged: (value) {
                      if (_authorTitleCaseEnabled && value.isNotEmpty) {
                        final formattedValue = _toTitleCase(value);
                        if (value != formattedValue) {
                          final cursorPos =
                              _authorController.selection.baseOffset;
                          _authorController.value = _authorController.value
                              .copyWith(
                                text: formattedValue,
                                selection: TextSelection.collapsed(
                                  offset: cursorPos,
                                ),
                              );
                        }
                      }
                      setState(() {});
                    },
                  );
                },
            onSelected: (selection) {
              final formatted = _authorTitleCaseEnabled
                  ? _toTitleCase(selection)
                  : selection;
              _authorController.text = formatted;
              _authorController.selection = TextSelection.fromPosition(
                TextPosition(offset: formatted.length),
              );
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          height: 56,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _authorTitleCaseEnabled = !_authorTitleCaseEnabled;
                if (_authorController.text.isNotEmpty) {
                  _authorController.text = _authorTitleCaseEnabled
                      ? _toTitleCase(_authorController.text)
                      : _authorController.text.toLowerCase();
                }
              });
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _authorTitleCaseEnabled
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.text_fields,
                color: _authorTitleCaseEnabled
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;
    final bool isAudiobook = _selectedBookType == 3;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Book' : 'Add Book'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: NotificationListener<UserScrollNotification>(
              onNotification: (n) {
                if (n.direction != ScrollDirection.idle)
                  FocusScope.of(context).unfocus();
                return false;
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCoverPicker(),
                    const SizedBox(height: 16),
                    _buildTitleField(),
                    const SizedBox(height: 16),
                    _buildAuthorField(),

                    const Divider(height: 32),

                    // Book Type
                    DropdownButtonFormField<int>(
                      value: _selectedBookType,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Format',
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
                        contentPadding: const EdgeInsets.fromLTRB(
                          12,
                          10,
                          12,
                          6,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Paperback')),
                        DropdownMenuItem(value: 1, child: Text('Hardback')),
                        DropdownMenuItem(value: 2, child: Text('eBook')),
                        DropdownMenuItem(value: 3, child: Text('Audiobook')),
                      ],
                      onChanged: (int? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedBookType = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Pages and Words — hidden for audiobooks
                    if (!isAudiobook) ...[
                      TextField(
                        controller: _pageCountController,
                        decoration: InputDecoration(
                          labelText: 'Pages',
                          hintText: 'Enter number of pages',
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
                          contentPadding: const EdgeInsets.fromLTRB(
                            12,
                            10,
                            12,
                            6,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) => setState(() {}),
                        onTapOutside: (event) {
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _wordCountController,
                        decoration: InputDecoration(
                          labelText: 'Words',
                          hintText: 'Enter number of words',
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
                          contentPadding: const EdgeInsets.fromLTRB(
                            12,
                            10,
                            12,
                            6,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => setState(() {}),
                        onTapOutside: (event) {
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Duration — shown only for audiobooks
                    if (isAudiobook) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _durationHoursController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (_) => setState(() {}),
                              onTapOutside: (_) =>
                                  FocusManager.instance.primaryFocus?.unfocus(),
                              decoration: InputDecoration(
                                labelText: 'Hours',
                                filled: true,
                                fillColor:
                                    theme.colorScheme.surfaceContainerHighest,
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
                                contentPadding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  6,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _durationMinutesController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (v) {
                                final val = int.tryParse(v);
                                if (val != null && val > 59)
                                  _durationMinutesController.text = '59';
                                setState(() {});
                              },
                              onTapOutside: (_) =>
                                  FocusManager.instance.primaryFocus?.unfocus(),
                              decoration: InputDecoration(
                                labelText: 'Minutes',
                                filled: true,
                                fillColor:
                                    theme.colorScheme.surfaceContainerHighest,
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
                                contentPadding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ISBN
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _isbnController,
                              decoration: InputDecoration(
                                labelText: 'ISBN',
                                hintText: '978-X-XX-XXXXXX-X',
                                filled: true,
                                fillColor:
                                    theme.colorScheme.surfaceContainerHighest,
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
                                contentPadding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  6,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [IsbnInputFormatter()],
                              onChanged: (value) => setState(() {}),
                              onTapOutside: (event) {
                                FocusManager.instance.primaryFocus?.unfocus();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          AspectRatio(
                            aspectRatio: 1,
                            child: Tooltip(
                              message: 'Scan barcode',
                              child: Material(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    final result = await Navigator.of(context)
                                        .push<String>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const BarcodeScannerPage(),
                                          ),
                                        );
                                    if (result != null) {
                                      setState(() {
                                        _isbnController.text = result;
                                      });
                                      _lookupByIsbn(result);
                                    }
                                  },
                                  child: const Center(
                                    child: Icon(
                                      FluentIcons.barcode_scanner_24_regular,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 32),

                    // Shelf selector
                    if (_shelves.isNotEmpty) ...[
                      DropdownButtonFormField<int>(
                        value: _shelfId,
                        style: theme.textTheme.bodyLarge,
                        decoration: InputDecoration(
                          labelText: 'Shelf',
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
                          contentPadding: const EdgeInsets.fromLTRB(
                            12,
                            10,
                            12,
                            6,
                          ),
                        ),
                        items: _shelves.map((shelf) {
                          return DropdownMenuItem<int>(
                            value: shelf['id'] as int,
                            child: Text(shelf['name'] as String),
                          );
                        }).toList(),
                        onChanged: (int? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _shelfId = newValue;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Date Selection
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            onTap: () => _selectDate(context, true),
                            controller: TextEditingController(
                              text: _dateStarted == null
                                  ? ''
                                  : DateFormat(
                                      'MMM d, y',
                                    ).format(_dateStarted!),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Start Date',
                              filled: true,
                              fillColor:
                                  theme.colorScheme.surfaceContainerHighest,
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
                              contentPadding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                6,
                              ),
                              suffixIcon: _dateStarted != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: _clearStartDate,
                                    )
                                  : const Icon(Icons.calendar_today),
                            ),
                            onTapOutside: (event) {
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            onTap: () => _selectDate(context, false),
                            controller: TextEditingController(
                              text: _dateFinished == null
                                  ? ''
                                  : DateFormat(
                                      'MMM d, y',
                                    ).format(_dateFinished!),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Finish Date',
                              filled: true,
                              fillColor:
                                  theme.colorScheme.surfaceContainerHighest,
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
                              contentPadding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                6,
                              ),
                              suffixIcon: _dateFinished != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: _clearFinishDate,
                                    )
                                  : const Icon(Icons.calendar_today),
                            ),
                            onTapOutside: (event) {
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                          ),
                        ),
                      ],
                    ),

                    // Rating
                    const SizedBox(height: 16),
                    if (_useStarRating) ...[
                      Text('Rating', style: theme.textTheme.bodyMedium),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _useStarRating
                              ? RatingBar.builder(
                                  initialRating: _rating ?? 0,
                                  minRating: 0,
                                  direction: Axis.horizontal,
                                  allowHalfRating: true,
                                  itemCount: 5,
                                  itemSize: 32,
                                  itemPadding: const EdgeInsets.symmetric(
                                    horizontal: 4.0,
                                  ),
                                  itemBuilder: (context, _) => const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFBCB04),
                                  ),
                                  glow: false,
                                  onRatingUpdate: (rating) {
                                    setState(() {
                                      _rating = rating;
                                    });
                                  },
                                )
                              : TextField(
                                  controller: _ratingController,
                                  decoration: InputDecoration(
                                    labelText: 'Rating',
                                    hintText: 'Enter rating (0–5)',
                                    filled: true,
                                    fillColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
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
                                    contentPadding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      6,
                                    ),
                                    suffixIcon:
                                        _ratingController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              setState(() {
                                                _rating = null;
                                                _ratingController.clear();
                                              });
                                            },
                                          )
                                        : null,
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d{0,1}(\.\d{0,2})?$'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value.isEmpty) {
                                      setState(() {
                                        _rating = null;
                                      });
                                    } else {
                                      final parsed = double.tryParse(value);
                                      if (parsed != null) {
                                        if (parsed > 5.0) {
                                          _rating = 5.0;
                                          _ratingController.text = '5.00';
                                          _ratingController.selection =
                                              TextSelection.fromPosition(
                                                const TextPosition(offset: 4),
                                              );
                                        } else {
                                          _rating = parsed;
                                        }
                                        setState(() {});
                                      }
                                    }
                                  },
                                  onTapOutside: (event) {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                  },
                                ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: Icon(
                            _isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _isFavorite
                                ? Colors.red
                                : theme.colorScheme.onSurface.withAlpha(153),
                            size: 32,
                          ),
                          onPressed: () {
                            setState(() {
                              _isFavorite = !_isFavorite;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // User Review
                    TextField(
                      controller: _userReviewController,
                      decoration: InputDecoration(
                        labelText: 'Review',
                        hintText: 'Write your thoughts on this book...',
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
                        contentPadding: const EdgeInsets.fromLTRB(
                          12,
                          10,
                          12,
                          6,
                        ),
                        alignLabelWithHint: true,
                        suffixIcon: _userReviewController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(
                                  () => _userReviewController.clear(),
                                ),
                              )
                            : null,
                      ),
                      minLines: 2,
                      maxLines: null,
                      onChanged: (_) => setState(() {}),
                      onTapOutside: (event) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                    ),
                    const SizedBox(height: 16),

                    // Tags Section
                    InkWell(
                      onTap: () async {
                        final result = await showTagSelectorSheet(
                          context: context,
                          initialSelectedTagIds: _selectedTagIds,
                          tagRepository: TagRepository(DatabaseHelper()),
                          settingsViewModel: widget.settingsViewModel,
                        );

                        if (result != null && mounted) {
                          setState(() {
                            _selectedTagIds = result.toSet();
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        constraints: const BoxConstraints(minHeight: 48),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.sell,
                                  size: 18,
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    153,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Tags',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedTagIds.isNotEmpty)
                              FutureBuilder<List<Tag>>(
                                future: _getTagsByIds(_selectedTagIds.toList()),
                                builder: (context, snapshot) {
                                  final tags = snapshot.data ?? [];
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: tags.isEmpty
                                        ? const SizedBox.shrink()
                                        : Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: tags
                                                .map(
                                                  (tag) => Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 5,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: theme
                                                          .colorScheme
                                                          .secondaryContainer,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      tag.name,
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: theme
                                                                .colorScheme
                                                                .onSecondaryContainer,
                                                          ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.isEditing) _buildAddedDate(theme),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Opacity(
                opacity:
                    _titleController.text.trim().isEmpty ||
                        _authorController.text.trim().isEmpty
                    ? 0.4
                    : 1.0,
                child: FilledButton(
                  onPressed: _saveBook,
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(widget.isEditing ? 'Update Book' : 'Save Book'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Small "Added <date>" line shown at the bottom when editing an existing
  // book. date_added is stored by the DB on insert.
  Widget _buildAddedDate(ThemeData theme) {
    final raw = widget.book?['date_added']?.toString();
    final added = (raw == null || raw.isEmpty) ? null : DateTime.tryParse(raw);
    if (added == null) return const SizedBox.shrink();

    final format = widget.settingsViewModel.defaultDateFormatNotifier.value;
    String formatted;
    try {
      formatted = DateFormat(format).format(added);
    } catch (_) {
      formatted = DateFormat('MMM d, yyyy').format(added);
    }
    final time = DateFormat('h:mm a').format(added);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Added $formatted at $time',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CoverLoadingPlaceholder extends StatefulWidget {
  final double width;
  final double height;
  final ThemeData theme;
  final double? progress;

  const _CoverLoadingPlaceholder({
    required this.width,
    required this.height,
    required this.theme,
    this.progress,
  });

  @override
  State<_CoverLoadingPlaceholder> createState() =>
      _CoverLoadingPlaceholderState();
}

class _CoverLoadingPlaceholderState extends State<_CoverLoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.theme.colorScheme.surfaceContainerHighest;
    final highlight = widget.theme.colorScheme.surfaceContainerHigh;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(base, highlight, _anim.value),
          borderRadius: BorderRadius.circular(8),
        ),
        child: widget.progress != null
            ? Align(
                alignment: Alignment.bottomCenter,
                child: LinearProgressIndicator(
                  value: widget.progress,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: widget.theme.colorScheme.primary.withValues(
                    alpha: 0.5,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class IsbnInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    final capped = digits.length > 13 ? digits.substring(0, 13) : digits;

    final buffer = StringBuffer();
    for (int i = 0; i < capped.length; i++) {
      if (i == 3 || i == 4 || i == 6) buffer.write('-');
      buffer.write(capped[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
