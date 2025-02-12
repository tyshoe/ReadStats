import 'package:flutter/cupertino.dart';

class HomePage extends StatelessWidget {
  final List<Map<String, dynamic>> books;

  const HomePage({super.key, required this.books});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Library')),
      child: SafeArea(
        child: books.isEmpty
            ? const Center(child: Text("No books added yet."))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  return CupertinoListTile(
                    title: Text(book['title']),
                    subtitle: Text(
                        "Words: ${book['wordCount']}, Rating: ${book['rating']}"),
                    trailing: book['isCompleted']
                        ? const Icon(CupertinoIcons.check_mark_circled,
                            color: CupertinoColors.systemGreen)
                        : const Icon(CupertinoIcons.clock,
                            color: CupertinoColors.systemGrey),
                  );
                },
              ),
      ),
    );
  }
}
