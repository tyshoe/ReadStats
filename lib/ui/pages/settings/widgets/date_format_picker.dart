import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/viewmodels/SettingsViewModel.dart';

void showDateFormatPicker(BuildContext context, SettingsViewModel settingsViewModel) {
  final theme = Theme.of(context);
  final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
  final currentDateFormat = settingsViewModel.defaultDateFormatNotifier.value;
  final accentColor = settingsViewModel.accentColorNotifier.value;
  final currentDate = DateTime.now();

  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date Format',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _DateFormatOption(
              format: 'MMM dd, yyyy',
              currentDateFormat: currentDateFormat,
              accentColor: accentColor,
              textColor: textColor,
              currentDate: currentDate,
              onSelect: () {
                settingsViewModel.setDefaultDateFormat('MMM dd, yyyy');
                Navigator.pop(context);
              },
            ),
            _DateFormatOption(
              format: 'MM/dd/yyyy',
              currentDateFormat: currentDateFormat,
              accentColor: accentColor,
              textColor: textColor,
              currentDate: currentDate,
              onSelect: () {
                settingsViewModel.setDefaultDateFormat('MM/dd/yyyy');
                Navigator.pop(context);
              },
            ),
            _DateFormatOption(
              format: 'dd/MM/yyyy',
              currentDateFormat: currentDateFormat,
              accentColor: accentColor,
              textColor: textColor,
              currentDate: currentDate,
              onSelect: () {
                settingsViewModel.setDefaultDateFormat('dd/MM/yyyy');
                Navigator.pop(context);
              },
            ),
            _DateFormatOption(
              format: 'yyyy/MM/dd',
              currentDateFormat: currentDateFormat,
              accentColor: accentColor,
              textColor: textColor,
              currentDate: currentDate,
              onSelect: () {
                settingsViewModel.setDefaultDateFormat('yyyy/MM/dd');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _DateFormatOption extends StatelessWidget {
  final String format;
  final String currentDateFormat;
  final Color accentColor;
  final Color textColor;
  final DateTime currentDate;
  final VoidCallback onSelect;

  const _DateFormatOption({
    required this.format,
    required this.currentDateFormat,
    required this.accentColor,
    required this.textColor,
    required this.currentDate,
    required this.onSelect,
  });

  String _getFormattedDate(DateTime date, String format) {
    return DateFormat(format).format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = currentDateFormat == format;

    return ListTile(
      onTap: onSelect,
      contentPadding: EdgeInsets.zero,
      leading: isSelected
          ? Icon(Icons.check, color: accentColor)
          : const SizedBox(width: 24),
      title: Text(
        _getFormattedDate(currentDate, format),
        style: TextStyle(
          fontSize: 16,
          color: isSelected ? accentColor : textColor,
        ),
      ),
    );
  }
}
