import 'package:flutter/cupertino.dart';

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
  double _rating = 5;
  bool _isCompleted = false;

  void _saveBook() {
    String title = _titleController.text;
    String author = _authorController.text;
    int? wordCount = int.tryParse(_wordCountController.text);

    if (title.isEmpty || author.isEmpty || wordCount == null) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text("Error"),
          content: const Text("Please fill all fields correctly."),
          actions: [
            CupertinoDialogAction(
              child: const Text("OK"),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
      );
      return;
    }

    // Save the book
    widget.addBook({
      "title": title,
      "author": author,
      "wordCount": wordCount,
      "rating": _rating,
      "isCompleted": _isCompleted,
    });

    // Clear fields
    _titleController.clear();
    _authorController.clear();
    _wordCountController.clear();
    setState(() {
      _rating = 5;
      _isCompleted = false;
    });

    // Show confirmation
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text("Success"),
        content: const Text("Book added successfully!"),
        actions: [
          CupertinoDialogAction(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("0"),
                  Expanded(
                    child: CupertinoSlider(
                      value: _rating,
                      min: 0,
                      max: 10,
                      divisions: 10,
                      onChanged: (value) {
                        setState(() {
                          _rating = value;
                        });
                      },
                    ),
                  ),
                  const Text("10"),
                  const SizedBox(width: 8),
                  Text(_rating.toStringAsFixed(1)),
                ],
              ),
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
            ],
          ),
        ),
      ),
    );
  }
}