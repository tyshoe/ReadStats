import 'package:flutter/material.dart';
import 'package:read_stats/data/models/shelf.dart';
import 'package:read_stats/ui/widgets/book_picker_sheet.dart';

// Currently Reading first, then To Read, Unfinished, and — though it never
// reaches the list — Finished last.
const Map<int, int> _shelfOrder = {
  Shelf.currentlyReading: 0,
  Shelf.wantToRead: 1,
  Shelf.unfinished: 2,
  Shelf.finished: 3,
};

/// The books on offer when logging a session, in the order every session
/// picker shows them: shelf first, then title.
///
/// Finished books are closed to new sessions, so they're dropped. Every entry
/// point into the picker runs its list through here — the timer and the
/// session form open the same sheet, and it should hold the same books
/// whichever one opened it.
List<Map<String, dynamic>> sessionBookOptions(
  List<Map<String, dynamic>> books,
) {
  final options = books
      .where((b) => Shelf.acceptsSessions(b['shelf_id'] as int?))
      .toList();
  options.sort((a, b) {
    final shelfA = _shelfOrder[a['shelf_id'] as int? ?? 0] ?? 99;
    final shelfB = _shelfOrder[b['shelf_id'] as int? ?? 0] ?? 99;
    if (shelfA != shelfB) return shelfA.compareTo(shelfB);
    // Custom shelves all sort after the system ones; keep each together so
    // it gets one heading in the picker.
    final nameA = (a['shelf_name'] as String? ?? '').toLowerCase();
    final nameB = (b['shelf_name'] as String? ?? '').toLowerCase();
    if (nameA != nameB) return nameA.compareTo(nameB);
    final titleA = (a['title'] as String? ?? '').toLowerCase();
    final titleB = (b['title'] as String? ?? '').toLowerCase();
    return titleA.compareTo(titleB);
  });
  return options;
}

/// The heading a book sits under in the session pickers: its shelf, with the
/// same icon the "Move to shelf" control uses for it.
BookGroup? sessionBookGroup(Map<String, dynamic> book) {
  final name = book['shelf_name'] as String?;
  if (name == null) return null;
  final icon = switch (book['shelf_id'] as int?) {
    Shelf.currentlyReading => Icons.menu_book_rounded,
    Shelf.wantToRead => Icons.bookmark,
    Shelf.unfinished => Icons.do_not_disturb_on,
    _ => Icons.label,
  };
  return (label: name, icon: icon);
}
