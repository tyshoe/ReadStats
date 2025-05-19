import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '/viewmodels/SettingsViewModel.dart';

class AddBookPage extends StatefulWidget {
  final Function(Map<String, dynamic>) addBook;
  final SettingsViewModel settingsViewModel;

  const AddBookPage({
    super.key,
    required this.addBook,
    required this.settingsViewModel,
  });

  @override
  State<AddBookPage> createState() => _AddBookPageState();
}

class _AddBookPageState extends State<AddBookPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _wordCountController = TextEditingController();
  final TextEditingController _pageCountController = TextEditingController();
  final DateTime _dateToday = DateTime.now();
  double _rating = 0;
  bool _isCompleted = false;
  bool _isFavorite = false;
  int _selectedBookType = 0;
  DateTime? _dateStarted;
  DateTime? _dateFinished;
  late final bool _useStarRating;

  @override
  void initState() {
    super.initState();
    _selectedBookType = widget.settingsViewModel.defaultBookTypeNotifier.value - 1;
    _useStarRating = widget.settingsViewModel.defaultRatingStyleNotifier.value == 0;
  }

  void _saveBook() {
    String title = _titleController.text;
    String author = _authorController.text;
    int wordCount = int.tryParse(_wordCountController.text) ?? 0;
    int pageCount = int.tryParse(_pageCountController.text) ?? 0;

    if (title.isEmpty || author.isEmpty) {
      final errorMessage = title.isEmpty
          ? 'Please enter a book title'
          : 'Please enter an author name';

      _showSnackBar(errorMessage);
      return;
    }

    widget.addBook({
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
    });

    _handleSaveSuccess();
  }

  void _handleSaveSuccess(){
    _showSnackBar('Book added successfully!');
    _clearFormInputs();
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
      _selectedBookType = 0;
      _dateStarted = null;
      _dateFinished = null;
    });
  }

  void _showSnackBar(String message){
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.only(
          left: 20,
          right: 20,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
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

  void _clearField(TextEditingController controller) {
    controller.clear();
    setState(() {});
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? _dateStarted ?? _dateToday
          : _dateFinished ?? _dateStarted ?? _dateToday,
      firstDate: isStartDate
          ? DateTime(1900)
          : _dateStarted ?? DateTime(1900), // Finish date can't be before start date
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
          // Reset finish date if it's now before the new start date
          if (_dateFinished != null && _dateFinished!.isBefore(picked)) {
            _dateFinished = null;
          }
        } else {
          _dateFinished = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Book'),
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
            Text('Title', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,

              decoration: InputDecoration(
                hintText: 'Title *',
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
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
            const SizedBox(height: 16),

            // Author Field
            Text('Author', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _authorController,
              decoration: InputDecoration(
                hintText: 'Author *',
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
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
            const SizedBox(height: 16),

            // Word Count
            Text('Total Words', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _wordCountController,
              decoration: InputDecoration(
                hintText: 'Number of Words',
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
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Page Count
            Text('Total Pages', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _pageCountController,
              decoration: InputDecoration(
                hintText: 'Number of Pages',
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
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
            const SizedBox(height: 16),

            // Book Type
            Text('Format', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedBookType,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
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

            // Completion Status
            Text('Status', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isCompleted = !_isCompleted;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _isCompleted,
                    onChanged: (bool? value) {
                      setState(() {
                        _isCompleted = value ?? false;
                      });
                    },
                  ),
                  Text(
                    _isCompleted ? 'Marked as Finished' : 'Mark as Finished',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Rating (only shown if completed)
            if (_isCompleted) ...[
              Text('Rating', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _useStarRating
                        ? RatingBar.builder(
                      initialRating: _rating,
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
                        hintText: 'Rating (0-5)',
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
                      color: _isFavorite ? Colors.red : colorScheme.onSurface.withOpacity(0.6),
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
            ],

            // Date Selection
            Text('Date', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Start Date', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 48, // Fixed height for consistency
                        child: OutlinedButton(
                          onPressed: () => _selectDate(context, true),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _dateStarted == null
                                      ? 'Select Start Date'
                                      : DateFormat('MMM d, y').format(_dateStarted!),
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),

                              ),
                              _dateStarted != null
                                  ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: _clearStartDate,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              )
                                  : const Icon(Icons.calendar_today, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Finish Date', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 48, // Fixed height for consistency
                        child: OutlinedButton(
                          onPressed: () => _selectDate(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _dateFinished == null
                                      ? 'Select Finish Date'
                                      : DateFormat('MMM d, y').format(_dateFinished!),
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              _dateFinished != null
                                  ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: _clearFinishDate,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              )
                                  : const Icon(Icons.calendar_today, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                child: const Text('Save Book'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}