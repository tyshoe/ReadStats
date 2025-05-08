import 'package:flutter/cupertino.dart';
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
  String _statusMessage = '';
  bool _isSuccess = false;
  int _selectedBookType = 0;
  DateTime? _dateStarted;
  DateTime? _dateFinished;
  late final bool _useStarRating;

  @override
  void initState() {
    super.initState();
    // Set the default book type based on the value in settingsViewModel
    _selectedBookType =
        widget.settingsViewModel.defaultBookTypeNotifier.value - 1;
    _useStarRating = widget.settingsViewModel.defaultRatingStyleNotifier.value == 0;
  }

  void _saveBook() {
    String title = _titleController.text;
    String author = _authorController.text;
    int wordCount = int.tryParse(_wordCountController.text) ?? 0;
    int pageCount = int.tryParse(_pageCountController.text) ?? 0;

    if (title.isEmpty || author.isEmpty) {
      setState(() {
        _statusMessage = 'Please fill all fields correctly.';
        _isSuccess = false;
      });
      _clearStatusMessage();
      return;
    }

    // Save the book
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

    // Clear fields
    _titleController.clear();
    _authorController.clear();
    _wordCountController.clear();
    _pageCountController.clear();
    setState(() {
      _rating = 0;
      _isCompleted = false;
      _isFavorite = false;
      _selectedBookType = 0;
      _statusMessage = 'Book added successfully!';
      _isSuccess = true;
      _dateStarted = null;
      _dateFinished = null;
    });

    _clearStatusMessage();
  }

  void _clearField(TextEditingController textEditController) {
    setState(() {
      textEditController.clear();
    });
  }

  void _clearStatusMessage() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _statusMessage = '';
          _isSuccess = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;
    final textColor = CupertinoColors.label.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: true,
        middle: Text('Add Book'),
        trailing: GestureDetector(
          onTap: _saveBook,
          child: Text(
            'Save',
            style: TextStyle(
              color: accentColor, // Use accent color here
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              const Text("Title",
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _titleController,
                placeholder: "Title",
                padding: const EdgeInsets.all(12),
                maxLines: null,
                suffix: _titleController.text.isNotEmpty
                    ? Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onTap: () => _clearField(_titleController),
                    child: Icon(CupertinoIcons.clear,
                        color: CupertinoColors.systemGrey),
                  ),
                )
                    : null,
              ),
              const SizedBox(height: 16),
              const Text("Author",
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _authorController,
                placeholder: "Author",
                padding: const EdgeInsets.all(12),
                maxLines: null,
                suffix: _authorController.text.isNotEmpty
                    ? Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onTap: () => _clearField(_authorController),
                    child: Icon(CupertinoIcons.clear,
                        color: CupertinoColors.systemGrey),
                  ),
                )
                    : null,
              ),
              const SizedBox(height: 16),
              const Text("Total Words",
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _wordCountController,
                onTapOutside: (event) {
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                placeholder: "Number of Words",
                padding: const EdgeInsets.all(12),
                keyboardType: TextInputType.number,
                suffix: _wordCountController.text.isNotEmpty
                    ? Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onTap: () => _clearField(_wordCountController),
                    child: Icon(CupertinoIcons.clear,
                        color: CupertinoColors.systemGrey),
                  ),
                )
                    : null,
              ),
              const SizedBox(height: 16),
              const Text("Total Pages",
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _pageCountController,
                onTapOutside: (event) {
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                placeholder: "Number of Pages",
                padding: const EdgeInsets.all(12),
                keyboardType: TextInputType.number,
                suffix: _pageCountController.text.isNotEmpty
                    ? Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onTap: () => _clearField(_pageCountController),
                    child: Icon(CupertinoIcons.clear,
                        color: CupertinoColors.systemGrey),
                  ),
                )
                    : null,
              ),
              const SizedBox(height: 16),
              const Text("Format",
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              CupertinoSlidingSegmentedControl<int>(
                groupValue: _selectedBookType,
                onValueChanged: (int? value) {
                  if (value != null) {
                    setState(() {
                      _selectedBookType = value;
                    });
                  }
                },
                children: const {
                  0: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        "Paperback",
                        style: TextStyle(fontSize: 12),
                      )),
                  1: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        "Hardback",
                        style: TextStyle(fontSize: 12),
                      )),
                  2: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        "eBook",
                        style: TextStyle(fontSize: 12),
                      )),
                  3: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        "Audiobook",
                        style: TextStyle(fontSize: 12),
                      )),
                },
              ),
              const SizedBox(height: 16),
              const Text("Status",
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              CupertinoSlidingSegmentedControl<int>(
                groupValue: _isCompleted ? 1 : 0,
                onValueChanged: (int? value) {
                  if (value != null) {
                    setState(() {
                      _isCompleted = value == 1;
                    });
                  }
                },
                children: const {
                  0: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text("Not Completed"),
                  ),
                  1: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text("Completed"),
                  ),
                },
              ),
              if (_isCompleted) ...[
                const SizedBox(height: 16),
                const Text(
                  "Rating",
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _useStarRating
                          ? RatingBar.builder(
                        initialRating: _rating,
                        minRating: 0,
                        maxRating: 5,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                        glow: false,
                        itemBuilder: (context, _) => const Icon(
                          CupertinoIcons.star_fill,
                          color: CupertinoColors.systemYellow,
                        ),
                        onRatingUpdate: (rating) {
                          setState(() {
                            _rating = rating;
                          });
                        },
                      )
                          : CupertinoTextField(
                        placeholder: "Rating (0 - 5)",
                        padding: const EdgeInsets.all(12),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          final parsed = double.tryParse(value);
                          if (parsed != null && parsed >= 0 && parsed <= 10) {
                            _rating = parsed;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isFavorite = !_isFavorite;
                        });
                      },
                      child: Icon(
                        _isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                        color: _isFavorite
                            ? CupertinoColors.systemRed
                            : CupertinoColors.systemGrey2.resolveFrom(context),
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              const Text(
                'Date',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Aligns the children to the left
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Start Date Column
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Start Date',
                              style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
                            ),
                            const SizedBox(height: 8),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              color: CupertinoColors.systemGrey5,
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _dateStarted == null
                                        ? 'Select Start Date'
                                        : DateFormat('MMMM d, y').format(_dateStarted!),
                                    style: TextStyle(fontSize: 16, color: textColor),
                                  ),
                                  Icon(CupertinoIcons.chevron_down, color: CupertinoColors.systemGrey),
                                ],
                              ),
                              onPressed: () {
                                DateTime tempDate = _dateStarted ?? _dateToday; // Store temp date
                                showCupertinoModalPopup(
                                  context: context,
                                  builder: (_) => Container(
                                    height: 250,
                                    color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                                    child: Column(
                                      children: [
                                        // Clear & Done buttons
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            CupertinoButton(
                                              padding: const EdgeInsets.symmetric(horizontal: 16),
                                              child: Text(
                                                'Clear',
                                                style: TextStyle(color: textColor),
                                              ),
                                              onPressed: () {
                                                setState(() => _dateStarted = null);
                                                Navigator.pop(context); // Close modal
                                              },
                                            ),
                                            CupertinoButton(
                                              padding: const EdgeInsets.symmetric(horizontal: 16),
                                              child: Text(
                                                'Done',
                                                style: TextStyle(color: accentColor),
                                              ),
                                              onPressed: () {
                                                setState(() => _dateStarted = tempDate); // Apply selected date
                                                Navigator.pop(context); // Close modal
                                              },
                                            ),
                                          ],
                                        ),
                                        Expanded(
                                          child: CupertinoDatePicker(
                                            maximumDate: _dateToday,
                                            initialDateTime: tempDate,
                                            mode: CupertinoDatePickerMode.date,
                                            onDateTimeChanged: (date) {
                                              tempDate = date;
                                              setState(() => _dateStarted = date);
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 32),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Finish Date Column
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Finish Date',
                              style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
                            ),
                            const SizedBox(height: 8),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              color: CupertinoColors.systemGrey5,
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _dateFinished == null
                                        ? 'Select Finish Date'
                                        : DateFormat('MMMM d, y').format(_dateFinished!),
                                    style: TextStyle(fontSize: 16, color: textColor),
                                  ),
                                  Icon(CupertinoIcons.chevron_down, color: CupertinoColors.systemGrey),
                                ],
                              ),
                              onPressed: () {
                                DateTime tempDate = _dateFinished ?? _dateToday; // Store temp date
                                showCupertinoModalPopup(
                                  context: context,
                                  builder: (_) => Container(
                                    height: 250,
                                    color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                                    child: Column(
                                      children: [
                                        // Clear & Done buttons
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            CupertinoButton(
                                              padding: const EdgeInsets.symmetric(horizontal: 16),
                                              child: Text(
                                                'Clear',
                                                style: TextStyle(color: textColor),
                                              ),
                                              onPressed: () {
                                                setState(() => _dateFinished = null);
                                                Navigator.pop(context); // Close modal
                                              },
                                            ),
                                            CupertinoButton(
                                              padding: const EdgeInsets.symmetric(horizontal: 16),
                                              child: Text(
                                                'Done',
                                                style: TextStyle(color: accentColor),
                                              ),
                                              onPressed: () {
                                                setState(() => _dateFinished = tempDate); // Apply selected date
                                                Navigator.pop(context); // Close modal
                                              },
                                            ),
                                          ],
                                        ),
                                        Expanded(
                                          child: CupertinoDatePicker(
                                            maximumDate: _dateToday,
                                            initialDateTime: tempDate,
                                            mode: CupertinoDatePickerMode.date,
                                            onDateTimeChanged: (date) {
                                              tempDate = date;
                                              setState(() => _dateFinished = date);
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 32),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, // Make the button full width
                child: CupertinoButton(
                  onPressed: _saveBook,
                  color: accentColor,
                  child: const Text("Save",
                      style: TextStyle(
                          fontSize: 16, color: CupertinoColors.white)),
                ),
              ),
              const SizedBox(height: 16),
              if (_statusMessage.isNotEmpty)
                Center(
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _isSuccess
                          ? CupertinoColors.systemGreen
                          : CupertinoColors.systemRed,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
