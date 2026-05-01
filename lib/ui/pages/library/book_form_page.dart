import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:read_stats/ui/pages/library/widgets/book_tag_editor_page.dart';
import 'package:read_stats/ui/pages/library/widgets/barcode_scanner_page.dart';
import '../../../data/database/database_helper.dart';
import '../../../data/models/book.dart';
import '../../../data/models/tag.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../data/repositories/tag_repository.dart';
import '../../../data/services/cover_service.dart';
import '/viewmodels/SettingsViewModel.dart';

class BookFormPage extends StatefulWidget {
  final Map<String, dynamic>? book;
  final Function(Map<String, dynamic>) onSave;
  final SettingsViewModel settingsViewModel;
  final bool isEditing;

  const BookFormPage({
    super.key,
    this.book,
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
  final DateTime _dateToday = DateTime.now();
  double? _rating;
  bool _isFavorite = false;
  int _shelfId = DatabaseHelper.shelfWantToRead;
  List<Map<String, dynamic>> _shelves = [];
  int _selectedBookType = 0;
  int _durationMinutes = 0;
  DateTime? _dateStarted;
  DateTime? _dateFinished;
  late bool _useStarRating;
  Set<int> _selectedTagIds = {};
  bool _titleTitleCaseEnabled = true;
  bool _authorTitleCaseEnabled = true;
  File? _coverFile;
  bool _coverChanged = false;
  bool _isPickingCover = false;

  @override
  void initState() {
    super.initState();
    _useStarRating = widget.settingsViewModel.defaultRatingStyleNotifier.value == 0;
    _selectedBookType = widget.settingsViewModel.defaultBookTypeNotifier.value - 1;
    _loadShelves();

    if (widget.isEditing) {
      _titleController.text = widget.book!['title'];
      _authorController.text = widget.book!['author'];
      _wordCountController.text = widget.book!['word_count'].toString();
      _pageCountController.text = widget.book!['page_count'].toString();
      _rating = widget.book!['rating']?.toDouble();
      _ratingController.text = _rating?.toStringAsFixed(2) ?? '';
      _shelfId = (widget.book!['shelf_id'] as int?) ?? 1;
      _isFavorite = widget.book!['is_favorite'] == 1;
      _selectedBookType = widget.book!['book_type_id'] - 1;
      _durationMinutes = (widget.book!['duration_minutes'] as int?) ?? 0;
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
        if (_shelves.isNotEmpty &&
            !_shelves.any((s) => s['id'] == _shelfId)) {
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
    super.dispose();
  }

  String _formatDuration(int totalMinutes) {
    if (totalMinutes == 0) return '';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final hourText = hours > 0 ? '$hours hour${hours == 1 ? '' : 's'}' : '';
    final minuteText = minutes > 0 ? '$minutes minute${minutes == 1 ? '' : 's'}' : '';
    return [hourText, minuteText].where((e) => e.isNotEmpty).join(' ');
  }

  Future<void> _showDurationPicker(BuildContext context) async {
    final hoursController = TextEditingController(text: (_durationMinutes ~/ 60).toString());
    final minutesController = TextEditingController(text: (_durationMinutes % 60).toString());
    int hours = _durationMinutes ~/ 60;
    int minutes = _durationMinutes % 60;

    await showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth * 0.8;

        return AlertDialog(
          title: Text('Set Duration', style: Theme.of(context).textTheme.bodyMedium),
          content: SizedBox(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: hoursController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          fillColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                          filled: true,
                        ),
                        onTap: () => hoursController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: hoursController.text.length,
                        ),
                        onChanged: (value) {
                          hours = int.tryParse(value) ?? 0;
                          if (hours < 0) hours = 0;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ':',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: minutesController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          fillColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                          filled: true,
                        ),
                        onTap: () => minutesController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: minutesController.text.length,
                        ),
                        onChanged: (value) {
                          minutes = int.tryParse(value) ?? 0;
                          if (minutes > 59) minutes = 59;
                          if (minutes < 0) minutes = 0;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text('Hours',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Text('Minutes',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _durationMinutes = (hours * 60) + minutes;
                });
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _saveBook() async {
    String title = _titleController.text.trim();
    String author = _authorController.text.trim();
    int wordCount = int.tryParse(_wordCountController.text) ?? 0;
    int pageCount = int.tryParse(_pageCountController.text) ?? 0;

    if (title.isEmpty || author.isEmpty) {
      final errorMessage =
      title.isEmpty ? 'Please enter a book title' : 'Please enter an author name';
      _showSnackBar(errorMessage);
      return;
    }

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
              child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
      if (widget.isEditing && widget.book!['id'] != null) "id": widget.book!['id'],
      "title": title,
      "author": author,
      "word_count": wordCount,
      "page_count": pageCount,
      "rating": _rating?.toDouble(),
      "is_completed": _shelfId == finishedShelfId ? 1 : 0,
      "is_favorite": _isFavorite ? 1 : 0,
      "shelf_id": _shelfId,
      "book_type_id": _selectedBookType + 1,
      "date_started": _dateStarted?.toIso8601String(),
      "date_finished": _dateFinished?.toIso8601String(),
      "date_added":
      widget.isEditing ? widget.book!['date_added'] : DateTime.now().toIso8601String(),
      "isbn": _isbnController.text.trim().isEmpty
          ? null
          : _isbnController.text.replaceAll(RegExp(r'[\s-]'), ''),
      "duration_minutes": _durationMinutes,
      "user_review":
      _userReviewController.text.trim().isEmpty ? null : _userReviewController.text.trim(),
      "cover_path": widget.isEditing ? widget.book!['cover_path'] as String? : null,
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
            await CoverService.deleteByPath(widget.book!['cover_path'] as String?);
            await bookRepository.updateCoverPath(bookId, null);
          } else {
            final newPath = await CoverService.saveFromPath(bookId, _coverFile!.path);
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
          final newPath = await CoverService.saveFromPath(newBookId, _coverFile!.path);
          await bookRepository.updateCoverPath(newBookId, newPath);
        }
      }

      widget.onSave(bookData);
      _handleSaveSuccess();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error saving book: ${e.toString()}');
      }
    }
  }

  Future<void> _loadExistingTags() async {
    try {
      if (widget.book!['id'] != null) {
        final tags = await TagRepository(DatabaseHelper()).getTagsForBook(widget.book!['id']);
        setState(() {
          _selectedTagIds = tags.map((tag) => tag.id!).toSet();
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading tags: ${e.toString()}');
      }
    }
  }

  void _handleSaveSuccess() {
    _showSnackBar(widget.isEditing ? 'Book updated successfully!' : 'Book added successfully!');
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
      _durationMinutes = 0;
      _selectedBookType = widget.settingsViewModel.defaultBookTypeNotifier.value - 1;
      _dateStarted = null;
      _dateFinished = null;
    });
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

  void _clearField(TextEditingController controller) {
    controller.clear();
    setState(() {});
  }

  void _clearStartDate() {
    setState(() {
      _dateStarted = null;
    });
  }

  void _clearFinishDate() {
    setState(() {
      _dateFinished = null;
      // _isCompleted = false;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
      isStartDate ? _dateStarted ?? _dateToday : _dateFinished ?? _dateStarted ?? _dateToday,
      firstDate: isStartDate ? DateTime(1900) : _dateStarted ?? DateTime(1900),
      lastDate: _dateToday,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context),
          child: child!,
        );
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
      'a', 'an', 'the', 'and', 'but', 'or',
      'nor', 'as', 'at', 'by', 'for', 'from', 'in',
      'into', 'near', 'of', 'on', 'onto', 'to', 'with'
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
    final double areaH = _coverFile != null ? 300.0 : 90.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: areaH,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background — blurred cover or plain surface
            if (_coverFile != null)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: Image.file(_coverFile!, fit: BoxFit.cover),
                ),
              )
            else
              Positioned.fill(
                child: Container(color: theme.colorScheme.surfaceContainerHighest),
              ),

            // Dim overlay so cover pops
            if (_coverFile != null)
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
                  child: _coverFile != null
                      ? Image.file(
                          _coverFile!,
                          width: coverW,
                          height: coverH,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _coverPlaceholder(theme, coverW, coverH),
                        )
                      : _emptyPlaceholder(theme),
                ),
              ],
            ),

            // Remove button — top-right corner
            if (_coverFile != null)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _coverFile = null;
                      _coverChanged = true;
                    });
                  },
                  icon: const Icon(Icons.delete, size: 22),
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.error.withValues(alpha: 0.85),
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
        Icon(Icons.add_photo_alternate_outlined,
            size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          'Add cover image',
          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
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
          Icon(Icons.add_photo_alternate_outlined,
              size: 32, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 6),
          Text(
            'Add cover',
            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
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
              suffixIcon: _titleController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _clearField(_titleController);
                  setState(() {});
                },
              )
                  : null,
            ),
            onChanged: (value) {
              if (_titleTitleCaseEnabled && value.isNotEmpty) {
                final formattedValue = _toTitleCase(value);
                if (value != formattedValue) {
                  _titleController.value = _titleController.value.copyWith(
                    text: formattedValue,
                    selection: TextSelection.collapsed(offset: formattedValue.length),
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
              return BookRepository(DatabaseHelper()).getAuthorSuggestions(textEditingValue.text);
            },
            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
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
                  suffixIcon: _authorController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _clearField(_authorController);
                      setState(() {});
                    },
                  )
                      : null,
                ),
                onChanged: (value) {
                  if (_authorTitleCaseEnabled && value.isNotEmpty) {
                    final formattedValue = _toTitleCase(value);
                    if (value != formattedValue) {
                      _authorController.value = _authorController.value.copyWith(
                        text: formattedValue,
                        selection: TextSelection.collapsed(offset: formattedValue.length),
                      );
                    }
                  }
                  setState(() {});
                },
              );
            },
            onSelected: (selection) {
              final formatted =
              _authorTitleCaseEnabled ? _toTitleCase(selection) : selection;
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
        Expanded(child: NotificationListener<UserScrollNotification>(
        onNotification: (n) {
          if (n.direction != ScrollDirection.idle) FocusScope.of(context).unfocus();
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
                contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
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
                  contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  suffixIcon: _pageCountController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _clearField(_pageCountController),
                  )
                      : null,
                ),
                keyboardType: TextInputType.number,
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
                  contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  suffixIcon: _wordCountController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _clearField(_wordCountController),
                  )
                      : null,
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
              TextFormField(
                readOnly: true,
                onTap: () => _showDurationPicker(context),
                controller: TextEditingController(text: _formatDuration(_durationMinutes)),
                decoration: InputDecoration(
                  labelText: 'Duration',
                  hintText: 'Set audiobook duration',
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
                  suffixIcon: _durationMinutes > 0
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _durationMinutes = 0),
                  )
                      : const Icon(Icons.access_time),
                ),
                onTapOutside: (event) {
                  FocusManager.instance.primaryFocus?.unfocus();
                },
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
                        suffixIcon: _isbnController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => _clearField(_isbnController),
                              )
                            : null,
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
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final result = await Navigator.of(context).push<String>(
                              MaterialPageRoute(
                                builder: (_) => const BarcodeScannerPage(),
                              ),
                            );
                            if (result != null) {
                              setState(() {
                                _isbnController.text = result;
                              });
                            }
                          },
                          child: const Center(
                            child: Icon(FluentIcons.barcode_scanner_24_regular),
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
                  contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
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
                          : DateFormat('MMM d, y').format(_dateStarted!),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Start Date',
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
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    onTap: () => _selectDate(context, false),
                    controller: TextEditingController(
                      text: _dateFinished == null
                          ? ''
                          : DateFormat('MMM d, y').format(_dateFinished!),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Finish Date',
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
                    itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                    itemBuilder: (context, _) => const Icon(
                      Icons.star,
                      color: Colors.amber,
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
                      suffixIcon: _ratingController.text.isNotEmpty
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d{0,1}(\.\d{0,2})?$')),
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
                            _ratingController.selection = TextSelection.fromPosition(
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
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : theme.colorScheme.onSurface.withAlpha(153),
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
                contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                alignLabelWithHint: true,
              ),
              minLines: 2,
              maxLines: null,
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
            const SizedBox(height: 16),

            // Tags Section
            InkWell(
              onTap: () async {
                final result = await Navigator.of(context).push<List<int>>(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => TagSelectorSheet(
                      initialSelectedTagIds: _selectedTagIds,
                      tagRepository: TagRepository(DatabaseHelper()),
                      settingsViewModel: widget.settingsViewModel,
                      isCreationMode: !widget.isEditing,
                    ),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      const begin = Offset(1.0, 0.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOut;

                      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                      var offsetAnimation = animation.drive(tween);

                      return SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      );
                    },
                  ),
                );

                if (result != null && mounted) {
                  setState(() {
                    _selectedTagIds = result.toSet();
                  });
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        Icon(Icons.sell, size: 18, color: theme.colorScheme.onSurface.withAlpha(153)),
                        const SizedBox(width: 8),
                        Text('Tags', style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                      ],
                    ),
                    if (_selectedTagIds.isNotEmpty)
                      FutureBuilder<List<Tag>>(
                        future: _getTagsByIds(_selectedTagIds.toList()),
                        builder: (context, snapshot) {
                          final tags = snapshot.data ?? [];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: tags.map((tag) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.sell, size: 12,
                                        color: theme.colorScheme.onSecondaryContainer),
                                    const SizedBox(width: 4),
                                    Text(
                                      tag.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      )),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
      ],
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