import 'package:flutter/cupertino.dart';

class LogSessionPage extends StatelessWidget {
  const LogSessionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('Log Session')),
      child: Center(child: Text('Log Session Page')),
    );
  }
}
