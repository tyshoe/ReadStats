import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:read_stats/data/utils/series_title.dart';

/// One published edition of a book, as Open Library records it. A work (the
/// book as written) has many: each printing, format and translation is its
/// own edition with its own cover, ISBN and page count.
class BookEdition {
  /// e.g. "/books/OL7353617M".
  final String key;
  final String title;
  final String? publisher;

  /// As entered on Open Library, which takes anything: "2003",
  /// "September 30, 2018", "xxxx".
  final String? publishDate;

  /// As entered: "Paperback", "Mass Market Paperback", "Audio CD"…
  final String? format;
  final int? pageCount;

  /// An audiobook's running time, where Open Library has it — see
  /// [durationFromNotes].
  final int? durationMinutes;

  /// Who reads an audiobook, comma-separated when there are several — see
  /// [narratorFrom].
  final String? narrator;
  final List<String> isbns;
  final int? coverId;

  /// Three-letter MARC code, e.g. "eng".
  final String? language;

  /// The series this edition names and its number in it, read from Open
  /// Library's free-text series line — see [SeriesTitle.parseListing].
  final String? seriesName;
  final double? seriesPosition;

  const BookEdition({
    required this.key,
    required this.title,
    this.publisher,
    this.publishDate,
    this.format,
    this.pageCount,
    this.durationMinutes,
    this.narrator,
    this.isbns = const [],
    this.coverId,
    this.language,
    this.seriesName,
    this.seriesPosition,
  });

  /// This edition with [other]'s details wherever this one has none.
  BookEdition filledFrom(BookEdition other) => BookEdition(
        key: key,
        title: title.isEmpty ? other.title : title,
        publisher: publisher ?? other.publisher,
        publishDate: publishDate ?? other.publishDate,
        format: format ?? other.format,
        pageCount: pageCount ?? other.pageCount,
        durationMinutes: durationMinutes ?? other.durationMinutes,
        narrator: narrator ?? other.narrator,
        isbns: isbns.isEmpty ? other.isbns : isbns,
        coverId: coverId ?? other.coverId,
        language: language ?? other.language,
        // Name and number go together: one series' number never goes on
        // another's name.
        seriesName: seriesName ?? other.seriesName,
        seriesPosition:
            seriesName == null ? other.seriesPosition : seriesPosition,
      );

  /// The series line that says the most: one with a number over one
  /// without. Null when the edition lists none.
  static ({String name, double? position})? seriesFrom(dynamic listed) {
    ({String name, double? position})? best;
    for (final line in _texts(listed)) {
      final parsed = SeriesTitle.parseListing(line);
      if (parsed == null) continue;
      if (parsed.position != null) return parsed;
      best ??= parsed;
    }
    return best;
  }

  /// "16h 12m", for an edition with a running time.
  String? get durationLabel {
    final minutes = durationMinutes;
    if (minutes == null) return null;
    final hours = minutes ~/ 60;
    return hours > 0 ? '${hours}h ${minutes % 60}m' : '${minutes}m';
  }

  /// An audiobook's running time in minutes, from an edition's notes. Open
  /// Library has no field for it: editions imported from audiobook sellers
  /// carry it in their free-text notes, in seconds, as "Duration: 58,341
  /// seconds". Null without that line, which is most audiobooks there.
  static int? durationFromNotes(dynamic notes) {
    // Notes come as text or as {type, value}.
    final text = notes is Map ? notes['value'] : notes;
    if (text is! String) return null;
    final match = RegExp(
      r'duration\s*:?\s*([\d,]+)\s*seconds?',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    final seconds = int.tryParse(match.group(1)!.replaceAll(',', ''));
    if (seconds == null || seconds <= 0) return null;
    return (seconds / 60).round();
  }

  /// An audiobook's narrators from an edition record, which names them one
  /// of two ways: among `contributors`, as {role: "Narrator/Reader", name},
  /// or among `contributions`, as "Rob Inglis (Narrator)". Null when it
  /// names none.
  static String? narratorFrom(Map<String, dynamic> map) {
    final role = RegExp(r'narrat|reader', caseSensitive: false);
    final names = <String>{};
    final contributors = map['contributors'];
    for (final entry in contributors is List ? contributors : const []) {
      if (entry is! Map) continue;
      final name = _text(entry['name']);
      if (name != null && role.hasMatch(_text(entry['role']) ?? '')) {
        names.add(name);
      }
    }
    final credit = RegExp(r'^(.+?)\s*\(([^)]*)\)$');
    for (final entry in _texts(map['contributions'])) {
      final match = credit.firstMatch(entry);
      if (match != null && role.hasMatch(match.group(2)!)) {
        names.add(match.group(1)!.trim());
      }
    }
    return names.isEmpty ? null : names.join(', ');
  }

  /// The 13-digit ISBN when there is one, as that is what barcodes carry.
  String? get isbn {
    if (isbns.isEmpty) return null;
    return isbns.firstWhere((i) => i.length == 13, orElse: () => isbns.first);
  }

  bool hasIsbn(String isbn) => isbns.contains(isbn);

  /// Small cover for lists.
  String? get thumbnailUrl =>
      coverId == null ? null : BookSearchService.coverUrl(coverId!, 'M');

  /// Full-size cover, the one to save.
  String? get coverUrl =>
      coverId == null ? null : BookSearchService.coverUrl(coverId!, 'L');

  int? get year {
    final match = RegExp(r'\b(1[4-9]|20)\d\d\b').firstMatch(publishDate ?? '');
    return match == null ? null : int.parse(match.group(0)!);
  }

  /// The app's format for this edition (1 paperback, 2 hardback, 3 ebook,
  /// 4 audiobook), or null when Open Library's free text doesn't say.
  int? get bookTypeId {
    final f = (format ?? '').toLowerCase();
    if (f.isEmpty) return null;
    if (f.contains('audio') ||
        f.contains('mp3') ||
        f.contains('cassette') ||
        RegExp(r'\bcd\b').hasMatch(f)) {
      return 4;
    }
    if (f.contains('ebook') ||
        f.contains('e-book') ||
        f.contains('kindle') ||
        f.contains('epub') ||
        f.contains('electronic') ||
        f.contains('digital')) {
      return 3;
    }
    if (f.contains('hard') ||
        f.contains('cloth') ||
        f.contains('library binding') ||
        f.contains('gebunden')) {
      return 2;
    }
    if (f.contains('paper') ||
        f.contains('soft') ||
        f.contains('mass market') ||
        f.contains('pocket') ||
        f.contains('taschenbuch')) {
      return 1;
    }
    return null;
  }

  /// The format in the app's words where it maps to one, else as entered.
  String? get formatLabel {
    final id = bookTypeId;
    if (id != null) return bookTypeLabels[id - 1];
    final f = format?.trim() ?? '';
    return f.isEmpty ? null : f;
  }

  static const bookTypeLabels = ['Paperback', 'Hardback', 'eBook', 'Audiobook'];

  String? get languageName =>
      language == null ? null : languageNameOf(language!);

  /// The name of a language code, or the code itself where it isn't one of
  /// the common ones.
  static String languageNameOf(String code) =>
      _languageNames[code] ?? code.toUpperCase();

  /// "Penguin Books · 2003 · Paperback" — whichever of those are known.
  String get summary => [
        ?publisher,
        if (year != null) '$year',
        ?formatLabel,
      ].join(' · ');

  /// From an entry of `/works/…/editions.json` or `/isbn/….json`.
  static BookEdition? fromJson(Map<String, dynamic> map) {
    final key = map['key'];
    if (key is! String || key.isEmpty) return null;
    final languages = map['languages'];
    String? language;
    if (languages is List && languages.isNotEmpty) {
      final first = languages.first;
      final languageKey = first is Map ? first['key'] : null;
      if (languageKey is String) language = languageKey.split('/').last;
    }
    final pages = map['number_of_pages'];
    final series = seriesFrom(map['series']);
    return BookEdition(
      key: key,
      title: _text(map['title']) ?? '',
      publisher: _firstText(map['publishers']),
      publishDate: _text(map['publish_date']),
      format: _text(map['physical_format']),
      pageCount: pages is int && pages > 0 ? pages : null,
      durationMinutes: durationFromNotes(map['notes']),
      narrator: narratorFrom(map),
      // 13-digit first: see [isbn].
      isbns: [..._texts(map['isbn_13']), ..._texts(map['isbn_10'])],
      coverId: _firstCover(map['covers']),
      language: language,
      seriesName: series?.name,
      seriesPosition: series?.position,
    );
  }

  /// From an `editions.docs` entry of a search result, whose fields are
  /// named and shaped differently (and carry no page count).
  static BookEdition? fromSearchDoc(Map<String, dynamic> map) {
    final key = map['key'];
    if (key is! String || key.isEmpty) return null;
    final cover = map['cover_i'];
    return BookEdition(
      key: key,
      title: _text(map['title']) ?? '',
      publisher: _firstText(map['publisher']),
      publishDate: _firstText(map['publish_date']),
      format: _firstText(map['format']),
      isbns: _texts(map['isbn']),
      coverId: cover is int && cover > 0 ? cover : null,
      language: _firstText(map['language']),
    );
  }

  static String? _text(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static List<String> _texts(dynamic value) => value is List
      ? value.map(_text).whereType<String>().toList()
      : const [];

  static String? _firstText(dynamic value) {
    final all = _texts(value);
    return all.isEmpty ? null : all.first;
  }

  /// Cover lists hold placeholders (-1, null) beside real ids.
  static int? _firstCover(dynamic value) {
    if (value is! List) return null;
    for (final id in value) {
      if (id is int && id > 0) return id;
    }
    return null;
  }

  static const _languageNames = {
    'eng': 'English',
    'fre': 'French',
    'fra': 'French',
    'ger': 'German',
    'deu': 'German',
    'spa': 'Spanish',
    'ita': 'Italian',
    'por': 'Portuguese',
    'dut': 'Dutch',
    'nld': 'Dutch',
    'rus': 'Russian',
    'jpn': 'Japanese',
    'chi': 'Chinese',
    'zho': 'Chinese',
    'kor': 'Korean',
    'pol': 'Polish',
    'swe': 'Swedish',
    'dan': 'Danish',
    'nor': 'Norwegian',
    'fin': 'Finnish',
    'tur': 'Turkish',
    'ara': 'Arabic',
    'heb': 'Hebrew',
    'hin': 'Hindi',
    'gre': 'Greek',
    'ell': 'Greek',
    'cze': 'Czech',
    'ces': 'Czech',
    'hun': 'Hungarian',
    'rum': 'Romanian',
    'ron': 'Romanian',
    'ukr': 'Ukrainian',
    'cat': 'Catalan',
    'lat': 'Latin',
    'ind': 'Indonesian',
    'vie': 'Vietnamese',
    'tha': 'Thai',
  };
}

/// One page of a work's editions. [fetched] is how many entries the page
/// held, which can be more than [editions] if some couldn't be read.
class BookEditionsResponse {
  final int total;
  final int fetched;
  final List<BookEdition> editions;
  const BookEditionsResponse({
    required this.total,
    required this.fetched,
    required this.editions,
  });
}

class BookSearchResult {
  final String title;
  final String author;
  final int? pageCount;

  /// Small cover for lists, and [coverUrl] the same image full-size, which
  /// is the one to save.
  final String? thumbnailUrl;
  final String? coverUrl;

  /// Set only when the result is one known [edition]. A plain search finds
  /// works, and a work has no ISBN of its own.
  final String? isbn;

  /// The edition this result is, when it was found by its ISBN. Its cover,
  /// ISBN and page count then belong together. Null for a work, whose cover
  /// is Open Library's pick among all its editions.
  final BookEdition? edition;
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
    this.coverUrl,
    this.isbn,
    this.edition,
    this.firstPublishYear,
    this.ratingsAverage,
    this.ratingsCount,
    this.workKey,
  });

  /// This book as one [edition] of it: that edition's cover, ISBN, page
  /// count and title, which then all describe the same copy. Anything the
  /// edition doesn't record stays as the work has it.
  BookSearchResult withEdition(BookEdition edition, {String? workKey}) =>
      BookSearchResult(
        title: edition.title.isEmpty ? title : edition.title,
        author: author,
        pageCount: edition.pageCount ?? pageCount,
        thumbnailUrl: edition.thumbnailUrl ?? thumbnailUrl,
        coverUrl: edition.coverUrl ?? coverUrl,
        isbn: edition.isbn ?? isbn,
        edition: edition,
        firstPublishYear: firstPublishYear,
        ratingsAverage: ratingsAverage,
        ratingsCount: ratingsCount,
        workKey: workKey ?? this.workKey,
      );
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
  static const String _isbnBase = 'https://openlibrary.org/api/books';

  static const String _worksBase = 'https://openlibrary.org/works';
  static const String _editionByIsbnBase = 'https://openlibrary.org/isbn';

  static const String _fields =
      'key,title,author_name,number_of_pages_median,cover_i,'
      'first_publish_year,ratings_average,ratings_count';

  /// Asked for only when searching by ISBN: the edition that ISBN is.
  static const String _editionFields =
      ',editions,editions.key,editions.title,editions.cover_i,editions.isbn,'
      'editions.language,editions.publisher,editions.publish_date,'
      'editions.format';

  static const int _pageSize = 20;
  static const int _editionsPageSize = 100;

  /// [size] is S, M or L. `default=false` makes a missing cover a 404; without
  /// it Open Library answers with a blank 1×1 image that would be saved as
  /// the cover.
  static String coverUrl(int coverId, String size) =>
      '$_coverBase/$coverId-$size.jpg?default=false';

  /// [text] as a bare ISBN (digits, or nine digits and an X), or null if it
  /// isn't one. Takes spaces and hyphens.
  static String? asIsbn(String text) {
    final clean = text.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    return RegExp(r'^(\d{9}[\dX]|\d{13})$').hasMatch(clean) ? clean : null;
  }

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

    // A search by ISBN is a search for one edition, so ask which.
    final isbn = scope == BookSearchScope.isbn || scope == BookSearchScope.all
        ? asIsbn(query)
        : null;
    var url = '$_searchBase?${scope.param}=${Uri.encodeComponent(query)}&limit=$_pageSize&offset=$offset&fields=$_fields';
    if (isbn != null) url += _editionFields;
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
    final results = docs
        .map((doc) => _parseDoc(doc, isbn: isbn))
        .whereType<BookSearchResult>()
        .toList();

    // An ISBN finds one book or a couple, so the extra request each is cheap.
    if (isbn != null && offset == 0) {
      for (var i = 0; i < results.length && i < 3; i++) {
        results[i] = await _withEditionDetails(results[i]);
      }
    }

    return BookSearchResponse(totalFound: totalFound, results: results);
  }

  /// A search knows an edition's cover and ISBN but not its page count; all
  /// it has is the median across the work. This reads the edition's own
  /// record so the pages are that edition's too. On any failure the result
  /// is returned as it was.
  static Future<BookSearchResult> _withEditionDetails(
    BookSearchResult result,
  ) async {
    final edition = result.edition;
    if (edition == null || !RegExp(r'^/books/OL\d+M$').hasMatch(edition.key)) {
      return result;
    }
    final BookEdition? record;
    try {
      final json = await _getJson('https://openlibrary.org${edition.key}.json');
      record = json == null ? null : BookEdition.fromJson(json);
    } on BookSearchException {
      return result;
    }
    if (record == null) return result;
    return result.withEdition(edition.filledFrom(record));
  }

  /// A page of the editions of [workKey] ("/works/OL66554W"), from [offset].
  /// Open Library returns them in no useful order and can't filter or sort
  /// them, so narrowing down is the caller's job.
  ///
  /// Throws [BookSearchException] on network or server errors.
  static Future<BookEditionsResponse> editions(
    String workKey, {
    int offset = 0,
  }) async {
    final id = RegExp(r'OL\d+W').firstMatch(workKey)?.group(0);
    if (id == null) {
      return const BookEditionsResponse(total: 0, fetched: 0, editions: []);
    }
    final json = await _getJson(
      '$_worksBase/$id/editions.json?limit=$_editionsPageSize&offset=$offset',
    );
    final entries = json?['entries'];
    if (entries is! List) {
      return const BookEditionsResponse(total: 0, fetched: 0, editions: []);
    }
    final size = json?['size'];
    return BookEditionsResponse(
      total: size is int ? size : offset + entries.length,
      fetched: entries.length,
      editions: entries
          .whereType<Map<String, dynamic>>()
          .map(BookEdition.fromJson)
          .whereType<BookEdition>()
          .toList(),
    );
  }

  /// The edition with this [isbn] and the work it belongs to, or null if
  /// Open Library doesn't know the ISBN.
  ///
  /// Throws [BookSearchException] on network or server errors.
  static Future<({BookEdition edition, String? workKey})?> editionByIsbn(
    String isbn,
  ) async {
    final clean = asIsbn(isbn);
    if (clean == null) return null;
    final json = await _getJson('$_editionByIsbnBase/$clean.json');
    if (json == null) return null;
    final edition = BookEdition.fromJson(json);
    if (edition == null) return null;
    final works = json['works'];
    final work = works is List && works.isNotEmpty ? works.first : null;
    final workKey = work is Map ? work['key'] : null;
    return (
      // Open Library files some editions without the ISBN they were found by.
      edition: edition.hasIsbn(clean)
          ? edition
          : BookEdition(
              key: edition.key,
              title: edition.title,
              isbns: [clean, ...edition.isbns],
            ).filledFrom(edition),
      workKey: workKey is String ? workKey : null,
    );
  }

  /// The series a book is in and its number, as far as Open Library knows:
  /// the [edition]'s own series line first, then the work's series record
  /// (which gives a number), then a "series:" subject (which doesn't). Null
  /// when none says, or on any failure — a nicety, never an error.
  static Future<({String name, double? position})?> seriesFor({
    BookEdition? edition,
    String? workKey,
  }) async {
    var name = edition?.seriesName;
    var position = edition?.seriesPosition;
    final id =
        workKey == null ? null : RegExp(r'OL\d+W').firstMatch(workKey)?.group(0);
    if ((name == null || position == null) && id != null) {
      try {
        final work = await _getJson('$_worksBase/$id.json');
        final listed = work?['series'];
        for (final entry in listed is List ? listed : const []) {
          if (entry is! Map) continue;
          final series = entry['series'];
          final key = series is Map ? series['key'] : null;
          if (key is! String || !RegExp(r'^/series/OL\d+L$').hasMatch(key)) {
            continue;
          }
          final record = await _getJson('https://openlibrary.org$key.json');
          final recordName = BookEdition._text(record?['name']);
          if (recordName == null) continue;
          // The work's number only counts for the series the edition names.
          if (name != null &&
              SeriesTitle.matchKey(name) != SeriesTitle.matchKey(recordName)) {
            continue;
          }
          name ??= recordName;
          final listedPosition = entry['position'];
          position ??= listedPosition == null
              ? null
              : SeriesTitle.parseNumber(listedPosition.toString());
          break;
        }
        if (name == null) {
          final subjects = BookEdition._texts(work?['subjects']);
          for (final subject in subjects) {
            if (subject.toLowerCase().startsWith('series:')) {
              name = SeriesTitle.parseListing(subject.substring(7))?.name;
              if (name != null) break;
            }
          }
        }
      } catch (_) {
        // Keep whatever the edition said.
      }
    }
    return name == null ? null : (name: name, position: position);
  }

  /// The JSON object at [url], or null if there is nothing there (404).
  static Future<Map<String, dynamic>?> _getJson(String url) async {
    final http.Response response;
    try {
      response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw const BookSearchException('Check your connection and try again.');
    }
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw const BookSearchException('Something went wrong. Try again.');
    }
    try {
      final json = jsonDecode(response.body);
      return json is Map<String, dynamic> ? json : null;
    } catch (_) {
      throw const BookSearchException('Something went wrong. Try again.');
    }
  }

  /// Search Open Library for cover images matching [query], returning distinct
  /// large cover URLs (one per edition that has a cover). Used by the cover
  /// picker so the user can browse and attach a cover independent of the book's
  /// other metadata.
  ///
  /// Throws [BookSearchException] on network or server errors.
  static Future<List<String>> searchCovers(String query, {int offset = 0}) async {
    if (query.trim().isEmpty) return [];

    final url = '$_searchBase?q=${Uri.encodeComponent(query.trim())}'
        '&limit=$_pageSize&offset=$offset&fields=cover_i';

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
    final docs = json['docs'] as List<dynamic>? ?? [];

    // Preserve order but drop duplicates and editions without a cover.
    final ids = <int>{};
    for (final doc in docs) {
      final id = (doc as Map<String, dynamic>)['cover_i'];
      if (id is int) ids.add(id);
    }
    return ids.map((id) => coverUrl(id, 'L')).toList();
  }

  static Future<BookSearchResult?> lookupByIsbn(String isbn) async {
    final clean = isbn.replaceAll(RegExp(r'[^\dX]'), '');
    if (clean.isEmpty) return null;
    try {
      // Asked for alongside: the edition's own record has what this lookup
      // leaves out — its format, its work, an audiobook's length and reader. The
      // lookup stands without it if it fails.
      final record = editionByIsbn(clean).then<
          ({BookEdition edition, String? workKey})?>(
        (found) => found,
        onError: (_) => null,
      );
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
      final cover = entry['cover'] as Map<String, dynamic>?;
      final large = cover?['large'] as String?;
      final publishers = entry['publishers'];
      final publisher = publishers is List && publishers.isNotEmpty
          ? (publishers.first as Map<String, dynamic>)['name'] as String?
          : null;

      final listed = BookEdition(
        key: entry['key'] as String? ?? '',
        title: title,
        publisher: publisher,
        publishDate: entry['publish_date'] as String?,
        pageCount: pageCount,
        durationMinutes: BookEdition.durationFromNotes(entry['notes']),
        isbns: [clean],
      );
      final found = await record;

      return BookSearchResult(
        title: title,
        author: authors.join(', '),
        pageCount: pageCount,
        thumbnailUrl: cover?['medium'] as String?,
        coverUrl: large == null ? null : '$large?default=false',
        isbn: clean,
        edition: found == null ? listed : listed.filledFrom(found.edition),
        workKey: found?.workKey,
      );
    } catch (_) {
      return null;
    }
  }

  /// [isbn] is the ISBN searched for, if the search was for one: the result
  /// is then that edition, with its own cover and title, not the work's.
  static BookSearchResult? _parseDoc(dynamic doc, {String? isbn}) {
    try {
      final map = doc as Map<String, dynamic>;
      BookEdition? edition;
      if (isbn != null) {
        final found = (map['editions'] as Map<String, dynamic>?)?['docs'];
        for (final entry in found is List ? found : const []) {
          final candidate = entry is Map<String, dynamic>
              ? BookEdition.fromSearchDoc(entry)
              : null;
          if (candidate != null && candidate.hasIsbn(isbn)) {
            edition = candidate;
            break;
          }
        }
      }
      final workTitle = (map['title'] as String?) ?? '';
      final title =
          edition != null && edition.title.isNotEmpty ? edition.title : workTitle;
      if (title.isEmpty) return null;

      final authors = (map['author_name'] as List<dynamic>?)?.cast<String>() ?? [];
      final pageCount = map['number_of_pages_median'] as int?;
      final firstPublishYear = map['first_publish_year'] as int?;
      final ratingsAverage = (map['ratings_average'] as num?)?.toDouble();
      final ratingsCount = map['ratings_count'] as int?;
      final workKey = map['key'] as String?;

      // The edition's cover where it has one. A work's own cover is one Open
      // Library picked from its editions, so it is no particular edition's —
      // and neither is any one ISBN, which is why a work carries none.
      final coverId = edition?.coverId ?? map['cover_i'];

      return BookSearchResult(
        title: title,
        author: authors.join(', '),
        pageCount: pageCount,
        thumbnailUrl: coverId is int ? coverUrl(coverId, 'M') : null,
        coverUrl: coverId is int ? coverUrl(coverId, 'L') : null,
        isbn: edition?.isbn,
        edition: edition,
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
