import 'package:flutter/cupertino.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
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
  double _rating = 0;
  bool _isCompleted = false;
  String _statusMessage = '';
  bool _isSuccess = false;
  int _selectedBookType = 0;

  @override
  void initState() {
    super.initState();
    // Pre-fill the form with the existing book data
    _titleController.text = widget.book['title'];
    _authorController.text = widget.book['author'];
    _wordCountController.text = widget.book['word_count'].toString();
    _rating = widget.book['rating'];
    _isCompleted = widget.book['is_completed'] == 1;
    _selectedBookType = widget.book['book_type_id'] - 1;
  }

  void _updateBook() {
    String title = _titleController.text;
    String author = _authorController.text;
    int wordCount = int.tryParse(_wordCountController.text) ?? 0;

    if (title.isEmpty || author.isEmpty) {
      setState(() {
        _statusMessage = 'Please fill all fields correctly.';
        _isSuccess = false;
      });
      return;
    }

    // Update the book
    widget.updateBook({
      "id": widget.book['id'],
      "title": title,
      "author": author,
      "word_count": wordCount,
      "rating": _rating,
      "is_completed": _isCompleted ? 1 : 0,
      "book_type_id": _selectedBookType + 1,
    });

    print({
      "id": widget.book['id'],
      "title": title,
      "author": author,
      "word_count": wordCount,
      "rating": _rating,
      "is_completed": _isCompleted ? 1 : 0,
      "book_type_id": _selectedBookType + 1,
    });

    setState(() {
      _statusMessage = 'Book updated successfully!';
      _isSuccess = true;
    });

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Edit Book'),
        trailing: GestureDetector(
          onTap: _updateBook,
          child: Text(
            'Save',
            style: TextStyle(
              color: accentColor,
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _titleController,
                placeholder: "Enter Book Title",
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 16),
              const Text("Author",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _authorController,
                placeholder: "Enter Author Name",
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 16),
              const Text("Total Word Count",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _wordCountController,
                onTapOutside: (event) {
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                placeholder: "Enter Word Count",
                padding: const EdgeInsets.all(12),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Star Rating
              Center(
                child: RatingBar.builder(
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
                ),
              ),

              const SizedBox(height: 16),
              const Text("Status",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              CupertinoSlidingSegmentedControl<int>(
                // padding: const EdgeInsets.all(12),
                groupValue:
                    _isCompleted ? 1 : 0, // Map boolean to segment index
                onValueChanged: (int? value) {
                  if (value != null) {
                    setState(() {
                      _isCompleted = value == 1; // Map index back to boolean
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
              const SizedBox(height: 16),
              const Text("Book Type",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                        "Ebook",
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, // Make the button full width
                child: CupertinoButton(
                  onPressed: _updateBook,
                  color: accentColor,
                  child: const Text("Save",
                      style: TextStyle(
                          fontSize: 16, color: CupertinoColors.white)),
                ),
              ),
              const SizedBox(height: 16),
              // Display the status message
              if (_statusMessage.isNotEmpty)
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _isSuccess
                        ? CupertinoColors.systemGreen
                        : CupertinoColors.systemRed,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
