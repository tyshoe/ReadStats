import 'package:flutter/material.dart';
import '../../../../data/services/book_search_service.dart';

/// Full-screen cover search backed by Open Library. Prefilled with the book's
/// title + author; the user searches and taps a cover to attach it. Returns the
/// chosen cover URL via [Navigator.pop], or null if dismissed.
class CoverSearchSheet extends StatefulWidget {
  final String initialQuery;

  const CoverSearchSheet({super.key, required this.initialQuery});

  @override
  State<CoverSearchSheet> createState() => _CoverSearchSheetState();
}

class _CoverSearchSheetState extends State<CoverSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<String> _covers = [];
  bool _isLoading = false;
  bool _searched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    // Auto-run the first search when we already have a title/author to go on;
    // otherwise focus the field so the user can type one.
    if (widget.initialQuery.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search(widget.initialQuery);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    _searchFocusNode.unfocus();
    setState(() {
      _isLoading = true;
      _searched = true;
      _error = null;
      _covers = [];
    });
    try {
      final covers = await BookSearchService.searchCovers(query.trim());
      if (mounted) {
        setState(() {
          _covers = covers;
          _isLoading = false;
        });
      }
    } on BookSearchException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    }
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
            hintText: 'Search for a cover…',
            border: InputBorder.none,
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          onSubmitted: _search,
        ),
        actions: [
          if (hasText)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _searchController.clear()),
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _CenteredMessage(
        icon: Icons.wifi_off_outlined,
        iconColor: theme.colorScheme.error,
        title: "You're offline",
        message: _error,
        action: FilledButton.tonal(
          onPressed: () => _search(_searchController.text),
          child: const Text('Try Again'),
        ),
      );
    }
    if (!_searched) {
      return _CenteredMessage(
        icon: Icons.image_search_outlined,
        iconColor: theme.colorScheme.outlineVariant,
        message: 'Search by title or author to find a cover',
      );
    }
    if (_covers.isEmpty) {
      return _CenteredMessage(
        icon: Icons.image_not_supported_outlined,
        iconColor: theme.colorScheme.outlineVariant,
        message: 'No covers found',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _covers.length,
      itemBuilder: (context, index) {
        final url = _covers[index];
        return _CoverTile(
          url: url,
          onTap: () => Navigator.of(context).pop(url),
        );
      },
    );
  }
}

class _CoverTile extends StatelessWidget {
  final String url;
  final VoidCallback onTap;

  const _CoverTile({required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: onTap,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String? title;
  final String? message;
  final Widget? action;

  const _CenteredMessage({
    required this.icon,
    required this.iconColor,
    this.title,
    this.message,
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
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
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
