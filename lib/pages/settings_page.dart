import 'package:flutter/cupertino.dart';

class SettingsPage extends StatelessWidget {
  final Function(bool) onThemeSelected;
  final bool isDarkMode;

  const SettingsPage({
    super.key,
    required this.onThemeSelected,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = CupertinoColors.systemBackground.resolveFrom(context);
    final textColor = CupertinoColors.label.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Settings'),
      ),
      child: SafeArea(
        child: CupertinoFormSection.insetGrouped(
          header: const Text('Appearance'),
          children: [
            CupertinoFormRow(
              prefix: const Text('Dark Mode'),
              child: CupertinoSwitch(
                value: isDarkMode,
                onChanged: (bool value) {
                  onThemeSelected(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
