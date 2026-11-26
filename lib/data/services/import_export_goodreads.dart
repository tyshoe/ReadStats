part of 'import_export_service.dart';

/// Reading a Goodreads library export into ReadStats books.
extension _GoodreadsImport on ImportExportService {
  List<List<dynamic>> _parseGoodreadsCSV(String csvString) {
    final raw = CsvToListConverter(
      eol: '\n',
      fieldDelimiter: ',',
      textDelimiter: '"',
      shouldParseNumbers: false,
    ).convert(csvString);

    return raw.map((row) => row.map((cell) {
      if (cell is String) {
        return cell.replaceAll(RegExp(r'^="|"$'), '').replaceAll('""', '"');
      }
      return cell;
    }).toList()).toList();
  }

  Future<int> _parseAndInsertGoodreadsBooks(List<List<dynamic>> rows) async {
    if (rows.isEmpty) return 0;

    final header = rows.first.map((e) {
      return e.toString()
          .replaceAll(RegExp(r'^="|"$'), '')
          .replaceAll('""', '"')
          .trim();
    }).toList();

    final colIndex = <String, int>{
      for (var i = 0; i < header.length; i++) header[i]: i,
    };

    String? getString(List<dynamic> row, String name) {
      if (!colIndex.containsKey(name) || colIndex[name]! >= row.length) return null;
      return row[colIndex[name]!]?.toString()
          .replaceAll(RegExp(r'^="|"$'), '')
          .replaceAll('""', '"');
    }

    DateTime? parseGoodreadsDate(String? s) {
      if (s == null || s.isEmpty) return null;
      try {
        final parts = s.split('/');
        if (parts.length == 3) {
          return DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      } catch (_) {}
      return null;
    }

    final books = <Book>[];
    for (final row in rows.skip(1)) {
      try {
        final r = row.map((cell) => cell is String
            ? cell.replaceAll(RegExp(r'^="|"$'), '').replaceAll('""', '"')
            : cell).toList();

        final isCompleted = getString(r, 'Date Read')?.isNotEmpty ?? false;
        final dateRead = parseGoodreadsDate(getString(r, 'Date Read'))
            ?.toIso8601String()
            .split('T')[0];

        // Goodreads puts the series in the title: "Legendary (Caraval #2)".
        final rawTitle = getString(r, 'Title') ?? 'Unknown';
        final series = SeriesTitle.parse(rawTitle);

        books.add(Book(
          id: null,
          title: series?.title ?? rawTitle,
          seriesName: series?.series,
          seriesPosition: series?.position,
          author: getString(r, 'Author') ?? 'Unknown',
          wordCount: 0,
          pageCount: int.tryParse(getString(r, 'Number of Pages') ?? '') ?? 0,
          // Goodreads rates 1 to 5 and writes 0 for a book you haven't
          // rated — which here is no rating, not a rating of 0 stars.
          rating: switch (double.tryParse(getString(r, 'My Rating') ?? '')) {
            final stars? when stars > 0 => stars,
            _ => null,
          },
          isFavorite: false,
          bookTypeId: _bookTypeIdFromBinding(getString(r, 'Binding') ?? ''),
          dateAdded: parseGoodreadsDate(getString(r, 'Date Added'))
              ?.toIso8601String()
              .split('T')[0] ??
              DateTime.now().toIso8601String().split('T')[0],
          dateStarted: isCompleted ? dateRead : null,
          dateFinished: isCompleted ? dateRead : null,
          isbn: getString(r, 'ISBN13'),
          userReview: getString(r, 'My Review'),
        ));
      } catch (e) {
        if (kDebugMode) print('Skipping Goodreads row: $e');
      }
    }

    await SeriesRepository().resolveNames(books);
    if (books.isNotEmpty) await bookRepository.addBooksBatch(books);
    return books.length;
  }

  int _bookTypeIdFromBinding(String binding) {
    final b = binding.toLowerCase();
    if (['audible audio', 'audio cassette', 'audio cd', 'audiobook'].contains(b)) return 4;
    if (['kindle edition', 'nook', 'ebook', 'digital', 'epub', 'pdf', 'mobi'].contains(b)) return 3;
    if (['hardcover', 'board book', 'library binding', 'leather bound', 'hardback'].contains(b)) return 2;
    return 1;
  }
}
