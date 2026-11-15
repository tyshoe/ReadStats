import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../../../data/services/book_search_service.dart';
import 'barcode_scanner_page.dart';

/// The edition the reader picked, and the work it belongs to. A null
/// [edition] is the reader passing on the question: the book as the search
/// found it, no edition in particular.
typedef EditionChoice = ({BookEdition? edition, String? workKey});

/// An edition in the list, which unlike an [EditionChoice] always is one.
typedef _Listed = ({BookEdition edition, String? workKey});

/// Full-screen picker for which edition of a book the reader has: the
/// editions Open Library lists for the work, narrowed by cover, format and
/// language, or found outright by the ISBN on the reader's copy. Returns an
/// [EditionChoice] via [Navigator.pop], or null if dismissed.
///
/// A work can have thousands of editions, which Open Library returns a page
/// at a time in no useful order and can't filter. So the filters here work
/// on what has been loaded so far, and say how much that is; the ISBN is the
/// sure way to one edition.
class EditionPickerPage extends StatefulWidget {
  /// The work whose editions to list, e.g. "/works/OL66554W".
  final String? workKey;

  /// The ISBN the book has now. Marks that edition in the list, and finds
  /// the work when [workKey] isn't known.
  final String? isbn;

  /// The book as the search found it, when the picker is the step between
  /// choosing a book and filling in its form. Offered first, as "Any
  /// edition", so a reader who doesn't mind which is one tap from the form.
  final BookSearchResult? general;

  const EditionPickerPage({super.key, this.workKey, this.isbn, this.general});

  @override
  State<EditionPickerPage> createState() => _EditionPickerPageState();
}

class _EditionPickerPageState extends State<EditionPickerPage> {
  final TextEditingController _filterController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _workKey;
  String? _currentIsbn;
  final List<BookEdition> _editions = [];
  int _total = 0;
  int _offset = 0;
  bool _hasMore = true;
  // Finding the work from the book's ISBN, before any editions can load.
  bool _starting = false;
  bool _loadingMore = false;
  String? _error;

  // Pages fetched in a row without the reader asking, to fill a screen the
  // filters left short. Capped: a filter nothing matches would otherwise
  // walk through every edition of the work.
  int _autoLoads = 0;
  static const _maxAutoLoads = 3;

  bool _withCover = true;
  int? _format;
  String? _language;

  // An ISBN typed or scanned into the filter is looked up directly, since
  // the edition may be thousands deep in the list.
  String? _isbnQuery;
  bool _isbnLooking = false;
  _Listed? _isbnMatch;

  @override
  void initState() {
    super.initState();
    _workKey = widget.workKey;
    _currentIsbn =
        widget.isbn == null ? null : BookSearchService.asIsbn(widget.isbn!);
    _starting = _workKey == null && _currentIsbn != null;
    _scrollController.addListener(_onScroll);
    _start();
  }

  @override
  void dispose() {
    _filterController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Loads the first editions, finding the work from the book's ISBN first
  /// when it isn't known. Also what "Try Again" runs.
  Future<void> _start() async {
    if (_workKey == null && _currentIsbn != null) {
      if (!_starting) {
        setState(() {
          _starting = true;
          _error = null;
        });
      }
      try {
        final found = await BookSearchService.editionByIsbn(_currentIsbn!);
        _workKey = found?.workKey;
      } on BookSearchException catch (e) {
        _error = e.message;
      }
      if (!mounted) return;
      setState(() => _starting = false);
    }
    await _loadMore();
  }

  void _onScroll() {
    if (_error != null) return; // retried from the footer, not by scrolling
    if (_scrollController.position.extentAfter < 300) {
      _autoLoads = 0;
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final workKey = _workKey;
    if (workKey == null || _loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final page = await BookSearchService.editions(workKey, offset: _offset);
      if (!mounted) return;
      setState(() {
        _editions.addAll(page.editions);
        _total = page.total;
        _offset += page.fetched;
        _hasMore = page.fetched > 0 && _offset < page.total;
        _loadingMore = false;
      });
      _fillIfShort();
    } on BookSearchException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loadingMore = false;
      });
    }
  }

  /// Loads another page when what matches doesn't fill the screen, since a
  /// list that can't scroll never asks for more on its own.
  void _fillIfShort() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasMore || _loadingMore || _error != null) return;
      if (_isbnQuery != null || _autoLoads >= _maxAutoLoads) return;
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent > 0) return;
      _autoLoads++;
      _loadMore();
    });
  }

  void _setFilter(VoidCallback change) {
    setState(change);
    _autoLoads = 0;
    _fillIfShort();
  }

  void _onFilterChanged() {
    final isbn = BookSearchService.asIsbn(_filterController.text);
    if (isbn != _isbnQuery) {
      _isbnQuery = isbn;
      _isbnMatch = null;
      _isbnLooking = false;
      if (isbn != null && !_editions.any((e) => e.hasIsbn(isbn))) {
        _lookUpIsbn(isbn);
      }
    }
    _setFilter(() {});
  }

  Future<void> _lookUpIsbn(String isbn) async {
    _isbnLooking = true;
    _Listed? found;
    try {
      found = await BookSearchService.editionByIsbn(isbn);
    } on BookSearchException {
      found = null;
    }
    if (!mounted || _isbnQuery != isbn) return;
    setState(() {
      _isbnLooking = false;
      _isbnMatch = found;
    });
    // Opened without a work: the ISBN just gave one, so list its editions.
    if (_workKey == null && found?.workKey != null) {
      _workKey = found!.workKey;
      _loadMore();
    }
  }

  Future<void> _scan() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || !mounted) return;
    _filterController.text = code;
    _onFilterChanged();
  }

  /// Carries on with the book as the search found it. Null when the picker
  /// wasn't opened with that to fall back on.
  VoidCallback? get _skip => widget.general == null
      ? null
      : () => Navigator.of(context)
          .pop<EditionChoice>((edition: null, workKey: _workKey));

  List<BookEdition> _matching() {
    // A whole ISBN names one edition, whatever the other filters say.
    final isbn = _isbnQuery;
    if (isbn != null) return _editions.where((e) => e.hasIsbn(isbn)).toList();

    final text = _filterController.text.trim().toLowerCase();
    final digits = text.replaceAll(RegExp(r'[\s-]'), '');
    return _editions.where((e) {
      if (_withCover && e.coverId == null) return false;
      if (_format != null && e.bookTypeId != _format) return false;
      if (_language != null && e.language != _language) return false;
      if (text.isEmpty) return true;
      return e.title.toLowerCase().contains(text) ||
          (e.publisher ?? '').toLowerCase().contains(text) ||
          (e.publishDate ?? '').toLowerCase().contains(text) ||
          (digits.isNotEmpty &&
              e.isbns.any((i) => i.toLowerCase().contains(digits)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasText = _filterController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        titleSpacing: 0,
        title: TextField(
          controller: _filterController,
          decoration: InputDecoration(
            hintText: 'ISBN, publisher or year…',
            border: InputBorder.none,
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          textInputAction: TextInputAction.search,
          onChanged: (_) => _onFilterChanged(),
        ),
        actions: [
          if (hasText)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _filterController.clear();
                _onFilterChanged();
              },
            ),
          IconButton(
            icon: const Icon(FluentIcons.barcode_scanner_24_regular),
            tooltip: 'Scan the ISBN on your copy',
            onPressed: _scan,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_editions.isNotEmpty) _buildFilters(theme),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    final counts = <String, int>{};
    for (final edition in _editions) {
      final language = edition.language;
      if (language != null) counts[language] = (counts[language] ?? 0) + 1;
    }
    final languages = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    Widget chip(String label, bool selected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          labelStyle: theme.textTheme.bodySmall,
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          selectedColor: theme.colorScheme.primaryContainer,
          elevation: 0,
          pressElevation: 0,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          onSelected: (_) => onTap(),
        ),
      );
    }

    const languageLabel = BookEdition.languageNameOf;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            chip(
              'With cover',
              _withCover,
              () => _setFilter(() => _withCover = !_withCover),
            ),
            for (var type = 1; type <= 4; type++)
              chip(
                BookEdition.bookTypeLabels[type - 1],
                _format == type,
                () => _setFilter(
                  () => _format = _format == type ? null : type,
                ),
              ),
            if (languages.length > 1)
              PopupMenuButton<String>(
                tooltip: 'Language',
                // '' is every language: a null value would read as dismissal.
                onSelected: (code) => _setFilter(
                  () => _language = code.isEmpty ? null : code,
                ),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: '', child: Text('Any language')),
                  for (final code in languages)
                    PopupMenuItem(
                      value: code,
                      child: Text('${languageLabel(code)} (${counts[code]})'),
                    ),
                ],
                // The chip is only the menu's face; the menu takes the tap.
                child: IgnorePointer(
                  child: chip(
                    _language == null
                        ? 'Language'
                        : languageLabel(_language!),
                    _language != null,
                    () {},
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_starting || (_editions.isEmpty && _loadingMore)) {
      return const Center(child: CircularProgressIndicator());
    }

    final matches = _matching();
    final isbnMatch = _isbnMatch;
    final pinned = isbnMatch != null &&
            !matches.any((e) => e.key == isbnMatch.edition.key)
        ? isbnMatch
        : null;

    if (_editions.isEmpty && pinned == null) {
      if (_isbnLooking) return const Center(child: CircularProgressIndicator());
      if (_error != null) {
        return _Message(
          icon: Icons.wifi_off,
          iconColor: theme.colorScheme.error,
          title: "You're offline",
          message: _error!,
          action: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.tonal(
                onPressed: _start,
                child: const Text('Try Again'),
              ),
              if (_skip != null)
                TextButton(
                  onPressed: _skip,
                  child: const Text('Continue without an edition'),
                ),
            ],
          ),
        );
      }
      return _Message(
        icon: Icons.menu_book,
        iconColor: theme.colorScheme.outlineVariant,
        action: _skip == null
            ? null
            : FilledButton.tonal(
                onPressed: _skip,
                child: const Text('Continue without an edition'),
              ),
        message: _isbnQuery != null
            ? "Open Library doesn't know that ISBN"
            : _workKey != null
                ? 'Open Library lists no editions for this book'
                : _currentIsbn != null
                    ? "Open Library doesn't know this book's ISBN. Scan or "
                        'type the one on your copy.'
                    : 'Scan or type the ISBN on your copy to find its edition',
      );
    }

    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final rows = <_Listed>[
      ?pinned,
      for (final edition in matches) (edition: edition, workKey: _workKey),
    ];
    // Stays put under the filters, which narrow editions and it isn't one.
    // An ISBN names an edition outright, so it steps aside for that.
    final general = _isbnQuery == null ? widget.general : null;
    final lead = general == null ? 0 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isbnQuery == null && _editions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              _hasMore
                  ? '${_count(matches.length)} shown · ${_count(_offset)} of '
                      '${_count(_total)} editions loaded'
                  : '${_count(matches.length)} of ${_count(_total)} editions',
              style: secondary,
            ),
          ),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            child: ListView.builder(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: lead + rows.length + 1,
              itemBuilder: (context, index) {
                if (index < lead) {
                  return _GeneralTile(book: general!, onTap: _skip!);
                }
                index -= lead;
                if (index == rows.length) {
                  return _buildFooter(theme, secondary, rows.isEmpty);
                }
                final row = rows[index];
                final current = _currentIsbn;
                return _EditionTile(
                  edition: row.edition,
                  isCurrent: current != null && row.edition.hasIsbn(current),
                  onTap: () => Navigator.of(context).pop<EditionChoice>(row),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// What is still to come, under the list: more editions to load, a lookup
  /// in flight, or why the list is empty.
  Widget _buildFooter(ThemeData theme, TextStyle? secondary, bool empty) {
    Widget centered(Widget child) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(child: child),
        );
    const spinner = SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2),
    );

    if (_isbnQuery != null) {
      if (_isbnLooking) return centered(spinner);
      if (empty) {
        return centered(
          Text("Open Library doesn't know that ISBN", style: secondary),
        );
      }
      return const SizedBox(height: 20);
    }
    if (_loadingMore) return centered(spinner);
    if (_error != null) {
      return centered(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: secondary, textAlign: TextAlign.center),
            TextButton(onPressed: _loadMore, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_hasMore) {
      return centered(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (empty)
              Text(
                'Nothing matches in the first ${_count(_offset)} editions',
                style: secondary,
                textAlign: TextAlign.center,
              ),
            TextButton(
              onPressed: () {
                _autoLoads = 0;
                _loadMore();
              },
              child: const Text('Load more editions'),
            ),
          ],
        ),
      );
    }
    if (empty) return centered(Text('No editions match', style: secondary));
    return const SizedBox(height: 20);
  }

  static String _count(int number) => number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}

class _EditionTile extends StatelessWidget {
  final BookEdition edition;

  /// Whether this is the edition the book's ISBN already names.
  final bool isCurrent;
  final VoidCallback onTap;

  const _EditionTile({
    required this.edition,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final small = theme.textTheme.bodySmall?.copyWith(
      color: secondary,
      fontSize: 11,
    );

    final published = [
      if (edition.publisher != null) edition.publisher!,
      // Dates are free text; one without a year in it ("xxxx") says nothing.
      if (edition.year != null) edition.publishDate!,
    ];
    final details = [
      if (edition.formatLabel != null) edition.formatLabel!,
      if (edition.pageCount != null) '${edition.pageCount} pages',
      ?edition.durationLabel,
      if (edition.languageName != null) edition.languageName!,
    ];
    final isbn = edition.isbn;
    final url = edition.thumbnailUrl;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56,
              height: 84,
              child: url != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(theme),
                      ),
                    )
                  : _placeholder(theme),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    edition.title.isEmpty ? 'Untitled edition' : edition.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (published.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      published.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: secondary),
                    ),
                  ],
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      details.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: small,
                    ),
                  ],
                  if (isbn != null) ...[
                    const SizedBox(height: 4),
                    Text('ISBN $isbn', style: small),
                  ],
                  if (published.isEmpty && details.isEmpty && isbn == null) ...[
                    const SizedBox(height: 4),
                    Text('No details on Open Library', style: small),
                  ],
                  if (isCurrent) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Current ISBN',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Icon(
          Icons.book,
          size: 22,
          color: theme.colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

/// The first row when choosing for a new book: no edition in particular,
/// drawn like one so it can be weighed against them.
class _GeneralTile extends StatelessWidget {
  final BookSearchResult book;
  final VoidCallback onTap;

  const _GeneralTile({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final url = book.thumbnailUrl;
    final placeholder = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Icon(Icons.book, size: 22, color: theme.colorScheme.outlineVariant),
      ),
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 84,
              child: url != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => placeholder,
                      ),
                    )
                  : placeholder,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Any edition',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Skip this and use the book's general cover",
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: secondary),
                  ),
                  if (book.pageCount != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${book.pageCount} pages, typical of its editions',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: secondary, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: secondary),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String? title;
  final String message;
  final Widget? action;

  const _Message({
    required this.icon,
    required this.iconColor,
    this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: iconColor),
            if (title != null) ...[
              const SizedBox(height: 16),
              Text(
                title!,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
