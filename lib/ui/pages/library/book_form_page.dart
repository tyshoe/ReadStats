import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:read_stats/ui/pages/tag_selector_page.dart';
import '../../../data/database/database_helper.dart';
import '../../../data/models/tag.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../data/repositories/tag_repository.dart';
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
  final DateTime _dateToday = DateTime.now();
  double? _rating;
  bool _isCompleted = false;
  bool _isFavorite = false;
  int _selectedBookType = 0;
  DateTime? _dateStarted;
  DateTime? _dateFinished;
  late bool _useStarRating;

  @override
  void initState() {
    super.initState();
    _useStarRating = widget.settingsViewModel.defaultRatingStyleNotifier.value == 0;
    _selectedBookType = widget.settingsViewModel.defaultBookTypeNotifier.value - 1;

    if (widget.isEditing) {
      _titleController.text = widget.book!['title'];
      _authorController.text = widget.book!['author'];
      _wordCountController.text = widget.book!['word_count'].toString();
      _pageCountController.text = widget.book!['page_count'].toString();
      _rating = widget.book!['rating']?.toDouble();
      _isCompleted = widget.book!['is_completed'] == 1;
      _isFavorite = widget.book!['is_favorite'] == 1;
      _selectedBookType = widget.book!['book_type_id'] - 1;
      _dateStarted = widget.book!['date_started'] != null
          ? DateTime.parse(widget.book!['date_started'])
          : null;
      _dateFinished = widget.book!['date_finished'] != null
          ? DateTime.parse(widget.book!['date_finished'])
          : null;
    }
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

    // Check if book already exists
    final bookRepository = BookRepository(DatabaseHelper());
    final bookExists = await bookRepository.doesBookExist(
      title,
      author,
      excludeId: widget.isEditing ? widget.book!['id'] : null,
    );

    if (bookExists) {
      // Show confirmation dialog instead of blocking
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
        return; // User cancelled
      }
    }

    final bookData = {
      if (widget.isEditing) "id": widget.book!['id'],
      "title": title,
      "author": author,
      "word_count": wordCount,
      "page_count": pageCount,
      "rating": _rating,
      "is_completed": _isCompleted ? 1 : 0,
      "is_favorite": _isFavorite ? 1 : 0,
      "book_type_id": _selectedBookType + 1,
      "date_started": _dateStarted?.toIso8601String(),
      "date_finished": _dateFinished?.toIso8601String(),
    };

    widget.onSave(bookData);
    _handleSaveSuccess();

    if (widget.isEditing && mounted) {
      Navigator.pop(context);
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
    setState(() {
      _rating = 0;
      _isCompleted = false;
      _isFavorite = false;
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
      _isCompleted = false;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? _dateStarted ?? _dateToday
          : _dateFinished ?? _dateStarted ?? _dateToday,
      firstDate: isStartDate
          ? DateTime(1900)
          : _dateStarted ?? DateTime(1900),
      lastDate: _dateToday,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.settingsViewModel.accentColorNotifier.value,
              onPrimary: Colors.white,
            ),
          ),
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
        } else {
          _dateFinished = picked;
          _isCompleted = true;
        }
      });
    }
  }

  Future<List<Tag>> _getBookTags() async {
    if (!widget.isEditing) return [];
    return await TagRepository(DatabaseHelper()).getTagsForBook(widget.book!['id']);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Book' : 'Add Book'),
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          TextButton(
            onPressed: _saveBook,
            child: Text(
              'Save',
              style: TextStyle(color: accentColor),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Field
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: _titleController.text.isEmpty ? 'Title *' : 'Title',
                hintText: 'Enter book title',
                floatingLabelBehavior: FloatingLabelBehavior.auto,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _titleController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _clearField(_titleController),
                )
                    : null,
              ),
              onChanged: (value) => setState(() {}), // Rebuild to update label
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
            const SizedBox(height: 16),

            // Author Field
            TextField(
              controller: _authorController,
              decoration: InputDecoration(
                labelText: _authorController.text.isEmpty ? 'Author *' : 'Author',
                hintText: 'Enter author name',
                floatingLabelBehavior: FloatingLabelBehavior.auto,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _authorController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _clearField(_authorController),
                )
                    : null,
              ),
              onChanged: (value) => setState(() {}), // Rebuild to update label
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),

            const Divider(height: 32),

            // Book Type
            DropdownButtonFormField<int>(
              value: _selectedBookType,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                labelText: 'Format',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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

            // Page Count
            TextField(
              controller: _pageCountController,
              decoration: InputDecoration(
                labelText: 'Pages',
                hintText: 'Enter number of pages',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _pageCountController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _clearField(_pageCountController),
                )
                    : null,
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() {}), // Rebuild to update label
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
            const SizedBox(height: 16),

            // Word Count
            TextField(
              controller: _wordCountController,
              decoration: InputDecoration(
                labelText: 'Words',
                hintText: 'Enter number of words',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _wordCountController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _clearField(_wordCountController),
                )
                    : null,
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() {}), // Rebuild to update label
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),

            const Divider(height: 32),

            // Date Selection
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    onTap: () => _selectDate(context, true),
                    controller: TextEditingController(
                      text:
                      _dateStarted == null ? '' : DateFormat('MMM d, y').format(_dateStarted!),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Start Date',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
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

            // Rating (only shown if completed)
            if (_isCompleted) ...[
              const SizedBox(height: 16),
              if (_useStarRating) ...[
                Text('Rating', style: theme.textTheme.bodyMedium),
                // const SizedBox(height: 8),
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
                      decoration: InputDecoration(
                        labelText: 'Rating',
                        hintText: 'Enter rating (0-5)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        final parsed = double.tryParse(value);
                        if (parsed != null && parsed >= 0 && parsed <= 5) {
                          setState(() {
                            _rating = parsed;
                          });
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
                      color: _isFavorite
                          ? Colors.red
                          : theme.colorScheme.onSurface.withOpacity(0.6),
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
            ],
            const SizedBox(height: 16),

            // Tags Section (only shown in edit mode)
            if (widget.isEditing)
              FutureBuilder<List<Tag>>(
                future: _getBookTags(),
                builder: (context, snapshot) {
                  final tags = snapshot.data ?? [];
                  return InkWell(
                    onTap: () {
                      Navigator.of(context)
                          .push(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              TagSelectorSheet(
                                bookId: widget.book!['id'],
                                tagRepository: TagRepository(DatabaseHelper()),
                                settingsViewModel: widget.settingsViewModel,
                              ),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            const begin = Offset(1.0, 0.0);
                            const end = Offset.zero;
                            const curve = Curves.easeInOut;

                            var tween = Tween(begin: begin, end: end)
                                .chain(CurveTween(curve: curve));
                            var offsetAnimation = animation.drive(tween);

                            return SlideTransition(
                              position: offsetAnimation,
                              child: child,
                            );
                          },
                        ),
                      )
                          .then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.sell,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6)),
                              const SizedBox(width: 8),
                              Text(
                                'Tags',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          if (tags.isNotEmpty) const SizedBox(height: 8),
                          if (tags.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: tags
                                  .map((tag) => Chip(
                                label: Text(tag.name),
                                backgroundColor:
                                theme.colorScheme.surfaceVariant,
                              ))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saveBook,
                child: Text(widget.isEditing ? 'Save Changes' : 'Save Book'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}