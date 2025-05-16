import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:read_stats/ui/pages/tag_selector_page.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/tag.dart';
import '../../data/repositories/tag_repository.dart';
import '/viewmodels/SettingsViewModel.dart';

class EditBookPage extends StatefulWidget {
  final Map<String, dynamic> book;
  final Function(Map<String, dynamic>) updateBook;
  final SettingsViewModel settingsViewModel;

  const EditBookPage({
    super.key,
    required this.book,
    required this.updateBook,
    required this.settingsViewModel,
  });

  @override
  State<EditBookPage> createState() => _EditBookPageState();
}

class _EditBookPageState extends State<EditBookPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _wordCountController = TextEditingController();
  final TextEditingController _pageCountController = TextEditingController();
  final DateTime _dateToday = DateTime.now();
  double _rating = 0;
  bool _isCompleted = false;
  bool _isFavorite = false;
  String _statusMessage = '';
  bool _isSuccess = false;
  int _selectedBookType = 0;
  DateTime? _dateStarted;
  DateTime? _dateFinished;
  late final bool _useStarRating;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.book['title'];
    _authorController.text = widget.book['author'];
    _wordCountController.text = widget.book['word_count'].toString();
    _pageCountController.text = widget.book['page_count'].toString();
    _rating = widget.book['rating'];
    _isCompleted = widget.book['is_completed'] == 1;
    _isFavorite = widget.book['is_favorite'] == 1;
    _selectedBookType = widget.book['book_type_id'] - 1;
    _dateStarted = widget.book['date_started'] != null
        ? DateTime.parse(widget.book['date_started'])
        : null;
    _dateFinished = widget.book['date_finished'] != null
        ? DateTime.parse(widget.book['date_finished'])
        : null;
    _useStarRating =
        widget.settingsViewModel.defaultRatingStyleNotifier.value == 0;
  }

  void _updateBook() {
    String title = _titleController.text;
    String author = _authorController.text;
    int wordCount = int.tryParse(_wordCountController.text) ?? 0;
    int pageCount = int.tryParse(_pageCountController.text) ?? 0;

    if (title.isEmpty || author.isEmpty) {
      setState(() {
        _statusMessage = 'Please fill all fields correctly.';
        _isSuccess = false;
      });
      return;
    }

    widget.updateBook({
      "id": widget.book['id'],
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

    setState(() {
      _statusMessage = 'Book updated successfully!';
      _isSuccess = true;
    });

    if (mounted) {
      Navigator.pop(context);
    }
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
          : _dateStarted ??
              DateTime(1900), // Finish date can't be before start date
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

  Future<List<Tag>> _getBookTags() async {
    return await TagRepository(DatabaseHelper())
        .getTagsForBook(widget.book['id']);
  }

  Widget _buildDateField({
    required BuildContext context,
    required String label,
    required DateTime? date,
    required VoidCallback onPressed,
    required VoidCallback onClear,
    required ThemeData theme,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      date == null
                          ? 'Select $label'
                          : DateFormat('MMM d, y').format(date),
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  date == null
                      ? Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        )
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: onClear,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                ],
              ),
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
        title: const Text('Edit Book'),
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          TextButton(
            onPressed: _updateBook,
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
              keyboardType: TextInputType.number,
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
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
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Not Completed'),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Completed'),
                ),
              ],
              selected: {_isCompleted ? 1 : 0},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _isCompleted = newSelection.first == 1;
                });
              },
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
                            itemPadding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            itemBuilder: (context, _) => const Icon(
                              Icons.star,
                              color: Colors.amber,
                            ),
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
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            onChanged: (value) {
                              final parsed = double.tryParse(value);
                              if (parsed != null &&
                                  parsed >= 0 &&
                                  parsed <= 5) {
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
              const SizedBox(height: 16),
            ],

            // Date Selection
            Text('Date', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildDateField(
                  context: context,
                  label: 'Start Date',
                  date: _dateStarted,
                  onPressed: () => _selectDate(context, true),
                  onClear: _clearStartDate,
                  theme: theme,
                ),
                const SizedBox(width: 16),
                _buildDateField(
                  context: context,
                  label: 'Finish Date',
                  date: _dateFinished,
                  onPressed: () => _selectDate(context, false),
                  onClear: _clearFinishDate,
                  theme: theme,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tags Section
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
                          bookId: widget.book['id'],
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
                            Icon(Icons.tag,
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
            const SizedBox(height: 24),

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
                onPressed: _updateBook,
                child: const Text('Save Changes'),
              ),
            ),
            const SizedBox(height: 16),

            // Status Message
            if (_statusMessage.isNotEmpty)
              Center(
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _isSuccess ? Colors.green : Colors.red,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
