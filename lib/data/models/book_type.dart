/// The `book_types` ids. Stable because the table is seeded in a fixed order.
/// How each one is shown lives in `ui/widgets/book_type.dart`.
abstract final class BookType {
  static const int paperback = 1;
  static const int hardback = 2;
  static const int ebook = 3;
  static const int audiobook = 4;

  static const Set<int> physical = {paperback, hardback};
}
