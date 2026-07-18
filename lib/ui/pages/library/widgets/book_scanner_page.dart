import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../data/database/database_helper.dart';
import '../../../../data/models/book.dart';
import '../../../../data/models/tag.dart';
import '../../../../data/repositories/book_repository.dart';
import '../../../../data/repositories/tag_repository.dart';
import '../../../../data/services/book_search_service.dart';
import '../../../../data/services/cover_service.dart';
import '../../../../viewmodels/SettingsViewModel.dart';
import '../../../widgets/app_snackbar.dart';
import '../book_form_page.dart';
import 'book_tag_editor_page.dart';

/// One matched book queued from a batch scan. Only created once a lookup
/// succeeds, so [result] is always present.
class _ScanItem {
  _ScanItem(this.isbn, this.result)
    : isbnValue = isbn,
      title = result.title,
      author = result.author,
      pageCount = result.pageCount;

  // The scanned barcode.
  final String isbn;
  final BookSearchResult result;
  // Editable copies of every field that gets saved, so the user can correct a
  // bad match in the review sheet. Seeded from the lookup / batch defaults.
  String title;
  String author;
  String isbnValue;
  int? pageCount;
  int bookTypeId = 1;
  int shelfId = DatabaseHelper.shelfWantToRead;
  double? rating;
  bool isFavorite = false;
  // A cover the user chose in the edit screen; overrides the lookup thumbnail.
  File? coverFile;
  // Lookup-thumbnail download kicked off at scan time so it's ready (local) by
  // the time the user saves — keeps the save fast and covers present up front.
  Future<File?>? coverFetch;
  // Per-book tags chosen in the edit screen (merged with the batch-wide tags).
  Set<int> tagIds = {};
  // Full field map returned by the edit screen — persisted verbatim so every
  // edited field sticks. Null until the book is opened in the editor.
  Map<String, dynamic>? editedData;
  // Title+author already in the library. Still addable — just flagged.
  bool isDuplicate = false;
  bool selected = true;
}

/// How a scan is handled: [single] opens the edit form for that one book;
/// [batch] queues it for a review-and-save-all pass.
enum _ScanMode { single, batch }

/// Barcode scanner for adding books. In single mode a scan opens the edit form
/// for that book; in batch mode scans are queued and saved together from a
/// review sheet. The user toggles modes on the scanner.
class BookScannerPage extends StatefulWidget {
  const BookScannerPage({
    super.key,
    required this.settingsViewModel,
    required this.onSaved,
  });

  final SettingsViewModel settingsViewModel;

  /// Called after books are persisted so the library can refresh.
  final VoidCallback onSaved;

  @override
  State<BookScannerPage> createState() => _BookScannerPageState();
}

class _BookScannerPageState extends State<BookScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: [BarcodeFormat.ean13, BarcodeFormat.ean8],
    facing: CameraFacing.back,
  );
  final BookRepository _bookRepo = BookRepository(DatabaseHelper());
  final List<_ScanItem> _items = [];
  // Last time each barcode produced a detection. Used to tell a continuous read
  // (holding a book in frame) apart from re-presenting it for another copy.
  final Map<String, DateTime> _lastScan = {};
  // How long a book must be out of view before re-scanning it adds another row.
  // Short enough that a quick dip away and back registers.
  static const _reScanGap = Duration(milliseconds: 900);
  _ScanMode _mode = _ScanMode.batch;
  bool _handlingSingle = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_saving || _handlingSingle) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    final isbn = raw.replaceAll(RegExp(r'[\s-]'), '');

    final now = DateTime.now();
    final last = _lastScan[isbn];
    _lastScan[isbn] = now;
    // Ignore the stream of frames while a book stays in view; a new lookup only
    // runs once it has left and come back (or it's a different book).
    if (last != null && now.difference(last) < _reScanGap) return;

    _buzz();
    if (_mode == _ScanMode.single) {
      _handleSingle(isbn);
    } else {
      _lookup(isbn);
    }
  }

  /// Single mode: look the book up and drop straight into the edit form to add
  /// it, then return to the scanner for the next one.
  Future<void> _handleSingle(String isbn) async {
    _handlingSingle = true;
    final result = await BookSearchService.lookupByIsbn(isbn);
    if (!mounted) return;
    if (result == null) {
      AppSnackbar.show('No book found for that barcode');
      _handlingSingle = false;
      return;
    }
    await _controller.stop();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookFormPage(
          searchResult: result,
          settingsViewModel: widget.settingsViewModel,
          onSave: (_) => widget.onSaved(),
        ),
      ),
    );
    if (!mounted) return;
    await _controller.start();
    _handlingSingle = false;
  }

  /// A firm double pulse so a capture is unmistakable even in a noisy setting.
  void _buzz() {
    HapticFeedback.heavyImpact();
    HapticFeedback.vibrate();
    Future.delayed(
      const Duration(milliseconds: 110),
      () => HapticFeedback.vibrate(),
    );
  }

  Future<void> _lookup(String isbn) async {
    final result = await BookSearchService.lookupByIsbn(isbn);
    if (!mounted) return;
    // Only queue a book if the barcode actually matched one.
    if (result == null) {
      AppSnackbar.show('No book found for that barcode');
      return;
    }
    final duplicate = await _bookRepo.doesBookExist(result.title, result.author);
    if (!mounted) return;
    final item = _ScanItem(isbn, result)
      ..bookTypeId = widget.settingsViewModel.defaultBookTypeNotifier.value
      ..isDuplicate = duplicate;
    // Start downloading the cover now, while scanning continues, so it's a local
    // file by save time.
    final url = result.thumbnailUrl;
    if (url != null && url.isNotEmpty) {
      item.coverFetch = CoverService.downloadFromUrl(url);
    }
    // Newest first — front of the strip (left) and top of the review list.
    setState(() => _items.insert(0, item));
  }

  void _removeItem(_ScanItem item) {
    setState(() => _items.remove(item));
  }

  Future<void> _openReview() async {
    await _controller.stop();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ReviewSheet(
        items: _items,
        settingsViewModel: widget.settingsViewModel,
        onRemove: _removeItem,
        onSaveAll: _saveAll,
      ),
    );
    // Resume scanning if the user backed out without saving.
    if (mounted && !_saving) {
      await _controller.start();
    }
  }

  Future<void> _saveAll(List<int> tagIds) async {
    if (_saving) return;
    setState(() => _saving = true);

    final navigator = Navigator.of(context);
    final onSaved = widget.onSaved;
    final toSave = _items.where((i) => i.selected).toList();
    final tagRepo = TagRepository(DatabaseHelper());
    final now = DateTime.now().toIso8601String();
    var added = 0;

    // Resolve covers first. These were pre-fetched during scanning, so this is
    // usually instant — the save stays fast and books show covers immediately.
    final covers = await Future.wait(
      toSave.map((i) async {
        if (i.coverFile != null) return i.coverFile;
        final fetch = i.coverFetch;
        return fetch == null ? null : await fetch;
      }),
    );

    for (var idx = 0; idx < toSave.length; idx++) {
      final item = toSave[idx];
      final r = item.result;
      final coverPath = covers[idx]?.path;
      final itemTags = {...tagIds, ...item.tagIds};
      final isFinished = item.shelfId == DatabaseHelper.shelfFinished;
      final Book book;
      if (item.editedData != null) {
        // Persist exactly what the edit screen returned (word count, review,
        // dates, duration, etc.), just stamping a fresh date_added.
        final data = Map<String, dynamic>.from(item.editedData!)
          ..['date_added'] = now
          ..remove('cover_path'); // cover saved below
        book = Book.fromMap(data);
      } else {
        book = Book(
          title: item.title.trim().isEmpty ? r.title : item.title.trim(),
          author: item.author.trim().isEmpty ? r.author : item.author.trim(),
          pageCount: item.pageCount,
          rating: item.rating,
          isFavorite: item.isFavorite,
          bookTypeId: item.bookTypeId,
          dateAdded: now,
          dateFinished: isFinished ? now : null,
          shelfId: item.shelfId,
          isbn: item.isbnValue.trim().isEmpty ? null : item.isbnValue.trim(),
          openLibraryKey: r.workKey,
        );
      }
      try {
        final id = await _bookRepo.addBook(book);
        for (final tagId in itemTags) {
          await tagRepo.addTagToBook(id, tagId);
        }
        if (coverPath != null) {
          final path = await CoverService.saveFromPath(id, coverPath);
          await _bookRepo.updateCoverPath(id, path);
        }
        added++;
      } catch (_) {
        // Skip a single failed insert; keep going with the rest.
      }
    }

    onSaved(); // books appear immediately, covers included
    navigator.popUntil((route) => route.isFirst); // all the way to the library
    AppSnackbar.show(added == 1 ? 'Added 1 book' : 'Added $added books');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            tooltip: 'Switch camera',
            onPressed: _controller.switchCamera,
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                final isOn = state.torchState == TorchState.on;
                return Icon(
                  isOn ? Icons.flashlight_on : Icons.flashlight_off,
                  color: isOn ? null : Colors.white38,
                );
              },
            ),
            onPressed: _controller.toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Align(
            alignment: const Alignment(0, -0.25),
            child: Container(
              width: 280,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.primary, width: 2.5),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.2),
            child: Text(
              _mode == _ScanMode.single
                  ? 'Scan a book to add it'
                  : 'Scan each barcode — keep going',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                shadows: [const Shadow(blurRadius: 4, color: Colors.black)],
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.9),
            child: _buildModeToggle(theme),
          ),
          if (_mode == _ScanMode.batch)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildCaptureBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildModeToggle(ThemeData theme) {
    return SegmentedButton<_ScanMode>(
      showSelectedIcon: false,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? theme.colorScheme.primary
              : Colors.black.withValues(alpha: 0.55),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? theme.colorScheme.onPrimary
              : Colors.white,
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: Colors.white.withValues(alpha: 0.4)),
        ),
        visualDensity: VisualDensity.compact,
      ),
      segments: const [
        ButtonSegment(
          value: _ScanMode.single,
          label: Text('Single'),
          icon: Icon(Icons.qr_code_scanner, size: 18),
        ),
        ButtonSegment(
          value: _ScanMode.batch,
          label: Text('Batch'),
          icon: Icon(Icons.library_add_outlined, size: 18),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: _handlingSingle
          ? null
          : (s) => setState(() => _mode = s.first),
    );
  }

  Widget _buildCaptureBar() {
    if (_items.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _buildThumb(_items[i]),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _items.isNotEmpty ? _openReview : null,
              icon: const Icon(Icons.check),
              label: Text(
                _items.length == 1
                    ? 'Review 1 book'
                    : 'Review ${_items.length} books',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumb(_ScanItem item) {
    final url = item.result.thumbnailUrl;
    final Widget child = (url != null && url.isNotEmpty)
        ? Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.menu_book, color: Colors.white54),
          )
        : const Icon(Icons.menu_book, color: Colors.white54);
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(color: Colors.white10, child: child),
      ),
    );
  }
}

/// Review list shown after tapping "Review". Lets the user pick which scans to
/// keep, tap a book to edit it in the full form, and apply shared tags before
/// saving.
class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({
    required this.items,
    required this.settingsViewModel,
    required this.onRemove,
    required this.onSaveAll,
  });

  final List<_ScanItem> items;
  final SettingsViewModel settingsViewModel;
  final void Function(_ScanItem) onRemove;
  final Future<void> Function(List<int> tagIds) onSaveAll;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final TagRepository _tagRepo = TagRepository(DatabaseHelper());
  final Set<int> _tagIds = {};
  Map<int, String> _tagNames = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadTagNames();
  }

  Future<void> _loadTagNames() async {
    final tags = await _tagRepo.getAllTags();
    if (!mounted) return;
    setState(() => _tagNames = {for (final Tag t in tags) t.id!: t.name});
  }

  Future<void> _openEditor(_ScanItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookFormPage(
          searchResult: item.result,
          settingsViewModel: widget.settingsViewModel,
          onSave: (_) {},
          initialTagIds: item.tagIds,
          initialData: {
            'title': item.title,
            'author': item.author,
            'isbn': item.isbnValue,
            'page_count': item.pageCount,
            'book_type_id': item.bookTypeId,
            'shelf_id': item.shelfId,
            'rating': item.rating,
            'is_favorite': item.isFavorite ? 1 : 0,
          },
          onSubmitData: (data, cover, tagIds) {
            item.editedData = data;
            // Mirror the fields shown on the review row / used for save defaults.
            item.title = (data['title'] as String?) ?? item.title;
            item.author = (data['author'] as String?) ?? item.author;
            item.isbnValue = (data['isbn'] as String?) ?? '';
            item.pageCount = data['page_count'] as int?;
            item.bookTypeId = (data['book_type_id'] as int?) ?? item.bookTypeId;
            item.shelfId = (data['shelf_id'] as int?) ?? item.shelfId;
            item.rating = (data['rating'] as num?)?.toDouble();
            item.isFavorite = data['is_favorite'] == 1;
            item.coverFile = cover;
            item.tagIds = tagIds.toSet();
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  int get _selectedCount => widget.items.where((i) => i.selected).length;

  Future<void> _editTags() async {
    final result = await showTagSelectorSheet(
      context: context,
      initialSelectedTagIds: _tagIds,
      tagRepository: _tagRepo,
      settingsViewModel: widget.settingsViewModel,
    );
    if (result == null || !mounted) return;
    setState(() {
      _tagIds
        ..clear()
        ..addAll(result);
    });
    _loadTagNames(); // pick up any tags created inside the sheet
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.settingsViewModel.accentColorNotifier.value;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    final media = MediaQuery.of(context);
    final screenH = media.size.height;
    // A tall, fixed-height sheet so the list can scroll under a pinned footer.
    // Shrink to fit above the keyboard when one is up.
    final maxAvail = screenH - media.viewPadding.top - keyboard - 8;
    final sheetHeight = (screenH * 0.9).clamp(0.0, maxAvail);
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: sheetHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add to library',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                    label: const Text('Scan more'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _buildTagRow(theme),
              const Divider(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.items.length,
                  itemBuilder: (_, i) => _buildRow(theme, widget.items[i]),
                ),
              ),
              const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: (_selectedCount == 0 || _saving)
                ? null
                : () async {
                    setState(() => _saving = true);
                    await widget.onSaveAll(_tagIds.toList());
                  },
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _selectedCount == 1
                        ? 'Add 1 book'
                        : 'Add $_selectedCount books',
                  ),
          ),
              SizedBox(
                height: 28 + MediaQuery.of(context).viewPadding.bottom,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagRow(ThemeData theme) {
    final names = _tagIds
        .map((id) => _tagNames[id])
        .whereType<String>()
        .toList();

    Widget tagChip(String label) => Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );

    final addChip = GestureDetector(
      onTap: _saving ? null : _editTags,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 12, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 3),
            Text(
              names.isEmpty ? 'Add tags' : 'Add',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 6),
          child: Icon(
            Icons.sell,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in names) tagChip(name),
              addChip,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(ThemeData theme, _ScanItem item) {
    return Dismissible(
      key: ObjectKey(item),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        widget.onRemove(item);
        setState(() {});
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      child: InkWell(
        onTap: () => _openEditor(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Checkbox(
                value: item.selected,
                onChanged: (v) => setState(() => item.selected = v ?? false),
              ),
              _cover(theme, item),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 2),
                    _buildSubtitle(theme, item),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cover(ThemeData theme, _ScanItem item) {
    final coverFile = item.coverFile;
    final url = item.result.thumbnailUrl;
    return SizedBox(
      width: 36,
      height: 50,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: coverFile != null
            ? Image.file(coverFile, fit: BoxFit.cover)
            : (url != null && url.isNotEmpty)
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _thumbFallback(theme),
              )
            : _thumbFallback(theme),
      ),
    );
  }

  Widget _buildSubtitle(ThemeData theme, _ScanItem item) {
    return Row(
      children: [
        if (item.isDuplicate) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'In library',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            item.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumbFallback(ThemeData theme) => Container(
    color: theme.colorScheme.surfaceContainerHighest,
    child: const Icon(Icons.menu_book, size: 16),
  );

}
