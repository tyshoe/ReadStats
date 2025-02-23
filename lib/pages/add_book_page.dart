import 'package:flutter/cupertino.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class AddBookPage extends StatefulWidget {
  final Function(Map<String, dynamic>) addBook;

  const AddBookPage({super.key, required this.addBook});

  @override
  State<AddBookPage> createState() => _AddBookPageState();
}

class _AddBookPageState extends State<AddBookPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _wordCountController = TextEditingController();
  double _rating = 0;
  bool _isCompleted = false;
  String _statusMessage = '';
  bool _isSuccess = false;

  void _saveBook() {
    String title = _titleController.text;
    String author = _authorController.text;
    int wordCount = int.tryParse(_wordCountController.text) ?? 0;

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
      "rating": _rating,
      "is_completed": _isCompleted ? 1 : 0,
    });

    // Clear fields
    _titleController.clear();
    _authorController.clear();
    _wordCountController.clear();
    setState(() {
      _rating = 0;
      _isCompleted = false;
      _statusMessage = 'Book added successfully!';
      _isSuccess = true;
    });

    _clearStatusMessage();
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
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Add Book')),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                placeholder: "Enter Word Count",
                padding: const EdgeInsets.all(12),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const Text("Rating",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // Star Rating
              Center(
                child: RatingBar.builder(
                  initialRating: _rating,
                  minRating: 0,
                  maxRating: 5,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
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
              Center(child: Text("$_rating / 5")),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Completed",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  CupertinoSwitch(
                    value: _isCompleted,
                    onChanged: (value) {
                      setState(() {
                        _isCompleted = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: CupertinoButton.filled(
                  onPressed: _saveBook,
                  child: const Text("Save Book"),
                ),
              ),
              const SizedBox(height: 16),
              if (_statusMessage.isNotEmpty)
                Center(
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _isSuccess ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
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
