import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '/viewmodels/SettingsViewModel.dart';

void showDateFormatPicker(BuildContext context, SettingsViewModel settingsViewModel) {
  final textColor = CupertinoColors.label.resolveFrom(context);
  final currentDateFormat = settingsViewModel.defaultDateFormatNotifier.value;
  final accentColor = settingsViewModel.accentColorNotifier.value;
  final DateTime currentDate = DateTime.now();

  showCupertinoModalPopup(
    context: context,
    builder: (context) => GestureDetector(
      onTap: () => Navigator.pop(context), // Dismiss when tapping outside
      child: Center(
        child: CupertinoPopupSurface(
          isSurfacePainted: true,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9, // Adjust width as needed
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, // Align left
              children: [
                const Text(
                  'Date Format',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                _DateFormatOption(
                  format: 'MMM dd, yyyy',
                  currentDateFormat: currentDateFormat,
                  accentColor: accentColor,
                  textColor: textColor,
                  currentDate: currentDate,
                  settingsViewModel: settingsViewModel,
                ),
                _DateFormatOption(
                  format: 'MM/dd/yyyy',
                  currentDateFormat: currentDateFormat,
                  accentColor: accentColor,
                  textColor: textColor,
                  currentDate: currentDate,
                  settingsViewModel: settingsViewModel,
                ),
                _DateFormatOption(
                  format: 'dd/MM/yyyy',
                  currentDateFormat: currentDateFormat,
                  accentColor: accentColor,
                  textColor: textColor,
                  currentDate: currentDate,
                  settingsViewModel: settingsViewModel,
                ),
                _DateFormatOption(
                  format: 'yyyy/MM/dd',
                  currentDateFormat: currentDateFormat,
                  accentColor: accentColor,
                  textColor: textColor,
                  currentDate: currentDate,
                  settingsViewModel: settingsViewModel,
                ),
              ],
            ),
          ),
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
  final SettingsViewModel settingsViewModel;

  const _DateFormatOption({
    required this.format,
    required this.currentDateFormat,
    required this.accentColor,
    required this.textColor,
    required this.currentDate,
    required this.settingsViewModel,
  });

  String _getFormattedDate(DateTime date, String format) {
    // Use DateFormat or custom formatting logic here
    return DateFormat(format).format(date);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      onPressed: () {
        settingsViewModel.setDefaultDateFormat(format);
        Navigator.pop(context);
      },
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          if (currentDateFormat == format)
            Icon(CupertinoIcons.check_mark, color: accentColor),
          const SizedBox(width: 8),
          Text(
            _getFormattedDate(currentDate, format),
            style: TextStyle(
              fontSize: 16,
              color: currentDateFormat == format ? accentColor : textColor,
            ),
          ),
        ],
      ),
    );
  }
}
