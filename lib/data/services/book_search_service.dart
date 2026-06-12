import 'dart:convert';
import 'package:http/http.dart' as http;

class BookSearchResult {
  final String title;
  final String author;
  final int? pageCount;
  final String? thumbnailUrl;
  final String? isbn;
  final int? firstPublishYear;
  final double? ratingsAverage;
  final int? ratingsCount;
  // e.g. "/works/OL12345W" — stable Open Library identifier
  final String? workKey;

  const BookSearchResult({
    required this.title,
    required this.author,
    this.pageCount,
    this.thumbnailUrl,
    this.isbn,
    this.firstPublishYear,
    this.ratingsAverage,
    this.ratingsCount,
    this.workKey,
  });
}

class BookSearchResponse {
  final int totalFound;
  final List<BookSearchResult> results;
  const BookSearchResponse({required this.totalFound, required this.results});
}

class BookSearchException implements Exception {
  final String message;
  const BookSearchException(this.message);
  @override
  String toString() => message;
}

enum BookSearchScope {
  all('q', 'All'),
  title('title', 'Title'),
  author('author', 'Author'),
  subject('subject', 'Subject'),
  isbn('isbn', 'ISBN');

  final String param;
  final String label;
  const BookSearchScope(this.param, this.label);
}

enum BookSortOption {
  relevance('', 'Relevance'),
  trending('trending', 'Trending'),
  rating('rating', 'Top Rated'),
  readinglog('readinglog', 'Reading Log'),
  old('old', 'First Published'),
  newest('new', 'Most Recent'),
  random('random', 'Random');

  final String apiValue;
  final String label;
  const BookSortOption(this.apiValue, this.label);
}

class BookSearchService {
  static const String _searchBase = 'https://openlibrary.org/search.json';
  static const String _coverBase = 'https://covers.openlibrary.org/b/id';
  static const String _coverOlidBase = 'https://covers.openlibrary.org/b/olid';
  static const String _isbnBase = 'https://openlibrary.org/api/books';

  static const String _fields =
      'key,title,author_name,number_of_pages_median,isbn,cover_i,'
      'first_publish_year,ratings_average,ratings_count';

  static const int _pageSize = 20;

  /// Throws [BookSearchException] on network or server errors.
  static Future<BookSearchResponse> search(
    String query, {
    BookSortOption sort = BookSortOption.relevance,
    BookSearchScope scope = BookSearchScope.all,
    int offset = 0,
  }) async {
    if (query.trim().isEmpty) {
      return const BookSearchResponse(totalFound: 0, results: []);
    }

    var url = '$_searchBase?${scope.param}=${Uri.encodeComponent(query)}&limit=$_pageSize&offset=$offset&fields=$_fields';
    if (sort.apiValue.isNotEmpty) url += '&sort=${sort.apiValue}';

    final http.Response response;
    try {
      response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw const BookSearchException('Check your connection and try again.');
    }
    if (response.statusCode != 200) {
      throw const BookSearchException('Something went wrong. Try again.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final totalFound = (json['numFound'] as int?) ?? 0;
    final docs = json['docs'] as List<dynamic>? ?? [];
    final results = docs.map(_parseDoc).whereType<BookSearchResult>().toList();

    return BookSearchResponse(totalFound: totalFound, results: results);
  }

  static Future<BookSearchResult?> lookupByIsbn(String isbn) async {
    final clean = isbn.replaceAll(RegExp(r'[^\dX]'), '');
    if (clean.isEmpty) return null;
    try {
      final uri = Uri.parse('$_isbnBase?bibkeys=ISBN:$clean&format=json&jscmd=data');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final entry = json['ISBN:$clean'] as Map<String, dynamic>?;
      if (entry == null) return null;

      final title = entry['title'] as String? ?? '';
      if (title.isEmpty) return null;

      final authors = (entry['authors'] as List<dynamic>?)
              ?.map((a) => (a as Map<String, dynamic>)['name'] as String? ?? '')
              .where((n) => n.isNotEmpty)
              .toList() ??
          [];

      final pageCount = entry['number_of_pages'] as int?;
      final coverUrl = (entry['cover'] as Map<String, dynamic>?)?['medium'] as String?;

      return BookSearchResult(
        title: title,
        author: authors.join(', '),
        pageCount: pageCount,
        thumbnailUrl: coverUrl,
        isbn: clean,
      );
    } catch (_) {
      return null;
    }
  }

  static BookSearchResult? _parseDoc(dynamic doc) {
    try {
      final map = doc as Map<String, dynamic>;
      final title = (map['title'] as String?) ?? '';
      if (title.isEmpty) return null;

      final authors = (map['author_name'] as List<dynamic>?)?.cast<String>() ?? [];
      final pageCount = map['number_of_pages_median'] as int?;
      final firstPublishYear = map['first_publish_year'] as int?;
      final ratingsAverage = (map['ratings_average'] as num?)?.toDouble();
      final ratingsCount = map['ratings_count'] as int?;
      final workKey = map['key'] as String?;

      final isbns = (map['isbn'] as List<dynamic>?)?.cast<String>() ?? [];
      final isbn = isbns.firstWhere(
        (i) => i.length == 13,
        orElse: () => isbns.isNotEmpty ? isbns.first : '',
      );

      final coverId = map['cover_i'];
      final thumbnailUrl = coverId != null ? '$_coverBase/$coverId-M.jpg' : null;

      return BookSearchResult(
        title: title,
        author: authors.join(', '),
        pageCount: pageCount,
        thumbnailUrl: thumbnailUrl,
        isbn: isbn.isNotEmpty ? isbn : null,
        firstPublishYear: firstPublishYear,
        ratingsAverage: ratingsAverage,
        ratingsCount: ratingsCount,
        workKey: workKey,
      );
    } catch (_) {
      return null;
    }
  }
}
