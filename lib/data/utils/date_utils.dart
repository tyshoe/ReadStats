import 'package:intl/intl.dart';

class DateUtils {
  static String parseAndFormatDate(String dateString) {
    if (dateString.trim().isEmpty) return DateTime.now().toIso8601String();
    return (_tryParseFlexible(dateString) ?? DateTime.now()).toIso8601String();
  }

  static String? parseAndFormatOptionalDate(String? dateString) {
    if (dateString == null || dateString.trim().isEmpty) return null;
    return _tryParseFlexible(dateString)?.toIso8601String();
  }

  static DateTime? _tryParseFlexible(String input) {
    final dateString = input.trim();

    DateTime? parsed = DateTime.tryParse(dateString);
    if (parsed != null) return parsed;

    if (dateString.contains(' ')) {
      parsed = DateTime.tryParse(dateString.replaceFirst(' ', 'T'));
      if (parsed != null) return parsed;
    }

    for (final f in [
      DateFormat("M/d/yyyy H:m:s"),
      DateFormat("M/d/yyyy HH:mm:ss"),
      DateFormat("M/d/yyyy"),
    ]) {
      try {
        return f.parseStrict(dateString);
      } catch (_) {}
    }

    return null;
  }
}