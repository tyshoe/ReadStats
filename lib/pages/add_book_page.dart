import 'package:flutter/cupertino.dart';

class AddBookPage extends StatelessWidget {
  const AddBookPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('Add Book')),
      child: Center(child: Text('Add Book Page')),
    );
  }
}
