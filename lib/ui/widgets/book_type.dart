import 'package:flutter/material.dart';

/// How a book's `book_type_id` is shown to the reader — the ids are the ones
/// seeded into the `book_types` table, so they're stable.
///
/// It matters more than it looks: a reader can own the same title twice, a
/// paperback and an audiobook, and title and author alone can't tell the two
/// copies apart.
(IconData, String) bookTypeDetails(int? id) => switch (id) {
  1 => (Icons.book_outlined, 'Paperback'),
  2 => (Icons.book, 'Hardback'),
  3 => (Icons.computer, 'eBook'),
  4 => (Icons.headset, 'Audiobook'),
  _ => (Icons.book, 'Paperback'),
};
