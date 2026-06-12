import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../../../data/services/book_search_service.dart';
import '../../../../viewmodels/SettingsViewModel.dart';
import '../book_form_page.dart';
import 'barcode_scanner_page.dart';

class BookSearchSheet extends StatefulWidget {
  final SettingsViewModel settingsViewModel;
  final Function(Map<String, dynamic>) onSave;

  const BookSearchSheet({
    super.key,
    required this.settingsViewModel,
    required this.onSave,
  });

  @override
  State<BookSearchSheet> createState() => _BookSearchSheetState();
}

class _BookSearchSheetState extends State<BookSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<BookSearchResult> _results = [];
  int _totalFound = 0;
  int _offset = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _searched = false;
  String? _error;
  BookSortOption _sort = BookSortOption.relevance;
  BookSearchScope _scope = BookSearchScope.all;

  bool get _hasMore => _results.length < _totalFound;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchController.text.isEmpty) {
        setState(() {
          _scope = BookSearchScope.all;
          _searched = false;
          _results = [];
          _totalFound = 0;
          _error = null;
        });
      } else {
        setState(() {});
      }
    });
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    _searchFocusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.unfocus();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _search(String query, {BookSortOption? sort, BookSearchScope? scope}) async {
    if (query.trim().isEmpty) return;
    _dismissKeyboard();
    final effectiveSort = sort ?? _sort;
    final effectiveScope = scope ?? _scope;
    setState(() {
      _isLoading = true;
      _searched = true;
      _error = null;
      _results = [];
      _totalFound = 0;
      _offset = 0;
      if (sort != null) _sort = sort;
      if (scope != null) _scope = scope;
    });
    try {
      final response = await BookSearchService.search(
        query.trim(),
        sort: effectiveSort,
        scope: effectiveScope,
      );
      if (mounted) {
        _dismissKeyboard();
        setState(() {
          _results = response.results;
          _totalFound = response.totalFound;
          _offset = response.results.length;
          _isLoading = false;
        });
      }
    } on BookSearchException catch (e) {
      if (mounted) {
        _dismissKeyboard();
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    setState(() => _isLoadingMore = true);
    try {
      final response = await BookSearchService.search(
        _searchController.text.trim(),
        sort: _sort,
        scope: _scope,
        offset: _offset,
      );
      if (mounted) {
        setState(() {
          _results.addAll(response.results);
          _totalFound = response.totalFound;
          _offset += response.results.length;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _scanBarcode() async {
    final isbn = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (isbn == null || !mounted) return;

    setState(() {
      _isLoading = true;
      _searched = true;
      _error = null;
    });

    final result = await BookSearchService.lookupByIsbn(isbn);

    if (!mounted) return;

    if (result != null) {
      _openForm(result);
      setState(() => _isLoading = false);
    } else {
      setState(() {
        _isLoading = false;
        _error = 'No book found for ISBN $isbn. Try searching by title.';
      });
    }
  }

  void _openForm(BookSearchResult? result) {
    _dismissKeyboard();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookFormPage(
          searchResult: result,
          onSave: widget.onSave,
          settingsViewModel: widget.settingsViewModel,
        ),
      ),
    );
  }

  void _openManualForm() {
    _dismissKeyboard();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookFormPage(
          onSave: widget.onSave,
          settingsViewModel: widget.settingsViewModel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasText = _searchController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: 'Search Open Library…',
            border: InputBorder.none,
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
        ),
        actions: [
          if (hasText)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _searchController.clear(),
            ),
          IconButton(
            icon: const Icon(FluentIcons.barcode_scanner_24_regular),
            tooltip: 'Scan ISBN',
            onPressed: _scanBarcode,
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissKeyboard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasText) _buildScopeChips(theme),
            Expanded(child: _buildBody(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeChips(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: BookSearchScope.values.map((scope) {
            final selected = scope == _scope;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FilterChip(
                label: Text(scope.label),
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
                onSelected: (_) {
                  if (_searched) {
                    _search(_searchController.text, scope: scope);
                  } else {
                    setState(() => _scope = scope);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_outlined, size: 56, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                "You're offline",
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: () => _search(_searchController.text),
                child: const Text('Try Again'),
              ),
              const SizedBox(height: 40),
              OutlinedButton.icon(
                onPressed: _openManualForm,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add manually'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (!_searched) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 48, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'Search by title, author, or keyword',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Center(
              child: OutlinedButton.icon(
                onPressed: _openManualForm,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add manually'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 56, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'No results found',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _openManualForm,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add manually'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
          child: Row(
            children: [
              Text(
                _formatResultCount(_totalFound),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              PopupMenuButton<BookSortOption>(
                onSelected: (s) => _search(_searchController.text, sort: s),
                itemBuilder: (_) => BookSortOption.values
                    .map((opt) => PopupMenuItem(
                          value: opt,
                          child: Row(
                            children: [
                              if (opt == _sort)
                                Icon(Icons.check, size: 16, color: theme.colorScheme.primary)
                              else
                                const SizedBox(width: 16),
                              const SizedBox(width: 8),
                              Text(opt.label),
                            ],
                          ),
                        ))
                    .toList(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sort: ${_sort.label}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (_) {
              _dismissKeyboard();
              return false;
            },
            child: Scrollbar(
              controller: _scrollController,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _results.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _results.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: _isLoadingMore
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const SizedBox.shrink(),
                      ),
                    );
                  }
                  return _BookResultTile(
                    result: _results[index],
                    onTap: () => _openForm(_results[index]),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatResultCount(int total) {
    if (total >= 1000000) {
      return '${(total / 1000000).toStringAsFixed(1)}M results';
    }
    if (total >= 1000) {
      return '${(total / 1000).toStringAsFixed(total >= 10000 ? 0 : 1)}k results';
    }
    return '$total results';
  }
}


class _BookResultTile extends StatelessWidget {
  final BookSearchResult result;
  final VoidCallback onTap;

  const _BookResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;

    final metaParts = <String>[
      if (result.firstPublishYear != null) '${result.firstPublishYear}',
      if (result.pageCount != null) '${result.pageCount} pages',
    ];

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              height: 96,
              child: result.thumbnailUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        result.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(theme),
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
                    result.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (result.author.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      result.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                    ),
                  ],
                  if (metaParts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      metaParts.join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (result.ratingsAverage != null || result.ratingsCount != null) ...[
                    const SizedBox(height: 4),
                    _RatingRow(
                      average: result.ratingsAverage,
                      count: result.ratingsCount,
                      theme: theme,
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
        child: Icon(Icons.book_outlined, size: 22, color: theme.colorScheme.outlineVariant),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final double? average;
  final int? count;
  final ThemeData theme;

  const _RatingRow({this.average, this.count, required this.theme});

  @override
  Widget build(BuildContext context) {
    final amber = Colors.amber.shade600;
    return Row(
      children: [
        Icon(Icons.star_rounded, size: 13, color: amber),
        const SizedBox(width: 3),
        if (average != null)
          Text(
            average!.toStringAsFixed(2),
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: amber,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (count != null) ...[
          const SizedBox(width: 4),
          Text(
            '(${_formatCount(count!)})',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k';
    return '$n';
  }
}
