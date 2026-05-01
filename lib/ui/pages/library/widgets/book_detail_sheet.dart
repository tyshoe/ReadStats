import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../../data/repositories/book_repository.dart';
import '../../../../data/repositories/tag_repository.dart';
import '../../../../viewmodels/SettingsViewModel.dart';
import '../book_form_page.dart';
import '/data/database/database_helper.dart';
import 'book_share_card.dart';
import 'session_notes_sheet.dart';

class BookPopup {
  static void showBookPopup(
      BuildContext context,
      Map<String, dynamic> book,
      int ratingStyle,
      String dateFormatString,
      Function navigateToEditBookPage,
      Function navigateToAddSessionPage,
      Function confirmDelete,
      TagRepository tagRepository,
      BookRepository bookRepository,
      SettingsViewModel settingsViewModel,
      {required Function() refreshCallback}) async {
    final DatabaseHelper dbHelper = DatabaseHelper();
    final stats = await dbHelper.getBookStats(book['id']);
    final ThemeData theme = Theme.of(context);
    final Color textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final Color subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final tags = await tagRepository.getTagsForBook(book['id']);
    final shelves = await dbHelper.getShelves();

    final mutableBook = Map<String, dynamic>.from(book);

    DateTime? startDateTime =
    book['date_started'] != null ? DateTime.parse(book['date_started']) : null;

    DateTime? finishDateTime =
    book['date_finished'] != null ? DateTime.parse(book['date_finished']) : null;

    String daysToCompleteString = "";

    if (startDateTime != null && finishDateTime != null) {
      int days = finishDateTime.difference(startDateTime).inDays;
      int adjustedDays = days == 0 ? 1 : days;
      daysToCompleteString = " ($adjustedDays ${adjustedDays == 1 ? 'day' : 'days'})";
    }

    final dateFormat = DateFormat(dateFormatString);
    final String? startDate = startDateTime != null ? dateFormat.format(startDateTime) : null;
    final String? finishDate = finishDateTime != null ? dateFormat.format(finishDateTime) : null;

    String dateRangeString = "";

    if (startDate != null && finishDate != null) {
      dateRangeString = "$startDate - $finishDate";
    } else if (startDate != null) {
      dateRangeString = "Started $startDate";
    } else if (finishDate != null) {
      dateRangeString = "Finished $finishDate";
    }

    // Format counts
    int pageCount = book['page_count'] ?? 0;
    int wordCount = book['word_count'] ?? 0;
    final bool isAudiobook = book['book_type_id'] == 4;

    String formatNumberWithCommas(int number) {
      return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
      );
    }

    String pageCountString = pageCount == 0
        ? ""
        : "${formatNumberWithCommas(pageCount)} ${pageCount == 1 ? 'page' : 'pages'}";

    String wordCountString = wordCount == 0
        ? ""
        : "${formatNumberWithCommas(wordCount)} ${wordCount == 1 ? 'word' : 'words'}";

    // Audiobook duration string for top-right display
    String durationString = '';
    if (isAudiobook && (book['duration_minutes'] ?? 0) > 0) {
      final totalMins = book['duration_minutes'] as int;
      final hours = totalMins ~/ 60;
      final mins = totalMins % 60;
      durationString = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    }

    String formatTime(int totalTimeInMinutes) {
      int days = totalTimeInMinutes ~/ (24 * 60);
      int hours = (totalTimeInMinutes % (24 * 60)) ~/ 60;
      int minutes = totalTimeInMinutes % 60;

      String formattedTime = '';
      if (days > 0) {
        formattedTime += '${days}d ';
      }
      if (hours > 0 || days > 0) {
        formattedTime += '${hours}h ';
      }
      formattedTime += '${minutes}m';
      return formattedTime;
    }

    // Completion status
    final bool isDark = theme.brightness == Brightness.dark;
    IconData completionIcon;
    Color completionColor;

    if (book['is_completed'] == 1) {
      completionIcon = Icons.check;
      completionColor = isDark ? Colors.green.shade300 : Colors.green.shade700;
    } else if (book['is_completed'] == 0 && stats['date_started'] != null) {
      completionIcon = Icons.autorenew;
      completionColor = theme.colorScheme.primary;
    } else {
      completionIcon = Icons.schedule;
      completionColor = theme.colorScheme.onSurfaceVariant;
    }

    // Book type
    IconData bookTypeIcon;
    switch (book['book_type_id']) {
      case 1:
        bookTypeIcon = Icons.book_outlined;
        break;
      case 2:
        bookTypeIcon = Icons.book;
        break;
      case 3:
        bookTypeIcon = Icons.computer;
        break;
      case 4:
        bookTypeIcon = Icons.headset;
        break;
      default:
        bookTypeIcon = Icons.book;
    }

    String bookTypeString;
    switch (book['book_type_id']) {
      case 1:
        bookTypeString = 'Paperback';
        break;
      case 2:
        bookTypeString = 'Hardback';
        break;
      case 3:
        bookTypeString = 'eBook';
        break;
      case 4:
        bookTypeString = 'Audiobook';
        break;
      default:
        bookTypeString = 'Paperback';
    }

    void duplicateBook(BuildContext context, Map<String, dynamic> book, Function refreshCallback,
        dynamic settingsViewModel) {
      Navigator.pop(context);
      Map<String, dynamic> duplicatedBook = {
        'title': '${book['title']} (Copy)',
        'author': book['author'],
        'word_count': book['word_count'],
        'page_count': book['page_count'],
        'book_type_id': book['book_type_id'],
        'rating': null,
        'is_completed': 0,
        'is_favorite': 0,
        'date_started': null,
        'date_finished': null,
        'date_added': DateTime.now().toIso8601String(),
      };

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookFormPage(
            book: duplicatedBook,
            onSave: (newBookData) {
              refreshCallback();
            },
            settingsViewModel: settingsViewModel,
          ),
        ),
      );
    }

    final statsKey = GlobalKey();
    double? statsHeight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final box = statsKey.currentContext?.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize && box.size.height != statsHeight) {
                setState(() => statsHeight = box.size.height);
              }
            });
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: DefaultTabController(
                length: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── BOOK SECTION ─────────────────────────────────────
                    ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Stack(
                      children: [
                        if (book['cover_path'] != null) ...[
                          Positioned.fill(
                            child: ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                              child: Image.file(
                                File(book['cover_path'] as String),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Drag handle
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Container(
                                    height: 4,
                                    width: 40,
                                    decoration: BoxDecoration(
                                      color: book['cover_path'] != null
                                          ? Colors.white.withValues(alpha: 0.5)
                                          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (book['cover_path'] != null) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(book['cover_path'] as String),
                                        width: 90,
                                        height: 135,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                book['title'],
                                                style: theme.textTheme.titleLarge?.copyWith(
                                                  color: book['cover_path'] != null ? Colors.white : null,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () async {
                                                final newStatus = mutableBook['is_favorite'] != 1;
                                                await bookRepository.toggleFavoriteStatus(
                                                  mutableBook['id'],
                                                  newStatus,
                                                );
                                                setState(() {
                                                  mutableBook['is_favorite'] = newStatus ? 1 : 0;
                                                });
                                                refreshCallback();
                                              },
                                              child: Icon(
                                                mutableBook['is_favorite'] == 1
                                                    ? Icons.favorite
                                                    : Icons.favorite_border,
                                                size: 22,
                                                color: mutableBook['is_favorite'] == 1
                                                    ? Colors.red
                                                    : book['cover_path'] != null
                                                        ? Colors.white70
                                                        : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "by ${book['author']}",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: book['cover_path'] != null
                                                ? Colors.white70
                                                : subtitleColor,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(bookTypeIcon, size: 16,
                                              color: book['cover_path'] != null ? Colors.white70 : subtitleColor),
                                            const SizedBox(width: 5),
                                            Text(bookTypeString, style: TextStyle(
                                              fontSize: 14,
                                              color: book['cover_path'] != null ? Colors.white70 : subtitleColor,
                                            )),
                                          ],
                                        ),
                                        if (!isAudiobook && (pageCountString != '' || wordCountString != '')) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            [pageCountString, wordCountString].where((s) => s.isNotEmpty).join(' · '),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: book['cover_path'] != null ? Colors.white70 : subtitleColor,
                                            ),
                                          ),
                                        ],
                                        if (isAudiobook && durationString != '') ...[
                                          const SizedBox(height: 4),
                                          Text(durationString, style: TextStyle(
                                            fontSize: 14,
                                            color: book['cover_path'] != null ? Colors.white70 : subtitleColor,
                                          )),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    ), // ClipRect

                    // ── TABBED CONTENT ────────────────────────────────────
                    TabBar(
                      indicatorColor: settingsViewModel.accentColorNotifier.value,
                      labelColor: settingsViewModel.accentColorNotifier.value,
                      unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(160),
                      tabs: const [Tab(text: 'Stats'), Tab(text: 'Notes')],
                    ),
                    SizedBox(
                      height: statsHeight ?? MediaQuery.sizeOf(context).height * 0.32,
                      child: TabBarView(
                      children: [
                      Container(
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Padding(
                            key: statsKey,
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Shelf chip + rating
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  final currentShelfId = mutableBook['shelf_id'] as int?;
                                  await showModalBottomSheet(
                                    context: context,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                    ),
                                    builder: (ctx) {
                                      final sheetTheme = Theme.of(ctx);
                                      return SafeArea(
                                        minimum: const EdgeInsets.only(bottom: 12),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(height: 12),
                                            Container(
                                              width: 36,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: sheetTheme.colorScheme.outlineVariant,
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                                              child: Text(
                                                'Move to shelf',
                                                style: sheetTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                            ...shelves.map((shelf) {
                                              final isSelected = shelf['id'] == currentShelfId;
                                              return ListTile(
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                                title: Text(
                                                  shelf['name'],
                                                  style: TextStyle(
                                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                                    color: isSelected ? sheetTheme.colorScheme.primary : null,
                                                  ),
                                                ),
                                                trailing: isSelected
                                                    ? Icon(Icons.check_rounded, color: sheetTheme.colorScheme.primary)
                                                    : null,
                                                onTap: isSelected ? null : () async {
                                                  Navigator.pop(ctx);
                                                  await bookRepository.updateBookShelf(mutableBook['id'], shelf['id']);
                                                  setState(() => mutableBook['shelf_id'] = shelf['id']);
                                                  refreshCallback();
                                                },
                                              );
                                            }),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: completionColor.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(completionIcon, size: 14, color: completionColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        shelves.firstWhere(
                                          (s) => s['id'] == mutableBook['shelf_id'],
                                          orElse: () => {'name': 'Unknown'},
                                        )['name'] as String,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: completionColor,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.expand_more, size: 14, color: completionColor),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              _buildRatingDisplay(ratingStyle, book['rating']),
                            ],
                          ),

                          // Progress bar for currently reading books only
                          if (mutableBook['shelf_id'] == DatabaseHelper.shelfCurrentlyReading &&
                              (isAudiobook
                                  ? (stats['total_time'] ?? 0) > 0 && (book['duration_minutes'] ?? 0) > 0
                                  : (stats['total_pages'] ?? 0) > 0 && (book['page_count'] ?? 0) > 0)) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: isAudiobook
                                    ? ((stats['total_time'] ?? 0) / (book['duration_minutes'] ?? 1)).clamp(0.0, 1.0)
                                    : ((stats['total_pages'] ?? 0) / (book['page_count'] ?? 1)).clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isAudiobook
                                  ? _getAudiobookProgressCompact(stats['total_time'] ?? 0, book['duration_minutes'] ?? 0)
                                  : _getTimeToFinishCompact(stats['total_pages'] ?? 0, book['page_count'] ?? 0, stats['pages_per_minute'] ?? 0),
                              style: TextStyle(fontSize: 12, color: subtitleColor),
                            ),
                          ],

                          // Date range
                          if (dateRangeString != '') ...[
                            const SizedBox(height: 10),
                            Text(
                              dateRangeString + daysToCompleteString,
                              style: TextStyle(fontSize: 14, color: textColor),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Stats grid
                          Builder(builder: (context) {
                            final sessionCount = (stats['session_count'] as int?) ?? 0;
                            final totalTime = (stats['total_time'] as int?) ?? 0;
                            final ppm = (stats['pages_per_minute'] as num?)?.toDouble() ?? 0.0;
                            final wpm = (stats['words_per_minute'] as num?)?.toDouble() ?? 0.0;
                            final avgSession = sessionCount > 0 ? (totalTime / sessionCount).round() : 0;

                            final cells = <(String, String)>[
                              ('Sessions', sessionCount.toString()),
                              ('Read Time', formatTime(totalTime)),
                              if (!isAudiobook) ('Pages Read', stats['total_pages']?.toString() ?? '0'),
                              if (totalTime > 0) ('Avg Session', formatTime(avgSession)),
                              if (wpm > 0) ('Words/Min', wpm.round().toString()),
                              if (!isAudiobook && ppm > 0) ('Pages/Min', ppm.toStringAsFixed(1)),
                            ];

                            final rows = <List<(String, String)>>[];
                            for (var i = 0; i < cells.length; i += 3) {
                              rows.add(cells.sublist(i, (i + 3).clamp(0, cells.length)));
                            }

                            return Column(
                              children: [
                                for (var r = 0; r < rows.length; r++) ...[
                                  if (r > 0) const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      for (var c = 0; c < rows[r].length; c++) ...[
                                        if (c > 0) _buildStatDivider(context),
                                        _buildStatCell(context, rows[r][c].$1, rows[r][c].$2),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            );
                          }),

                          // Tags
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 28,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: tags.length,
                                separatorBuilder: (context, index) => const SizedBox(width: 6),
                                itemBuilder: (context, index) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.sell, size: 12, color: theme.colorScheme.onSecondaryContainer),
                                        const SizedBox(width: 4),
                                        Text(
                                          tags[index].name,
                                          style: TextStyle(color: theme.colorScheme.onSecondaryContainer, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                            ],
                          ),
                          ),
                        ),
                      ),
                      Container(
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: SessionNotesContent(
                          bookId: book['id'] as int,
                          dateFormatString: dateFormatString,
                        ),
                      ),
                    ],
                    ),
                    ),
                    // ── ACTION ROW ───────────────────────────────────────
                    Container(
                      color: theme.colorScheme.surfaceContainerHigh,
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + MediaQuery.of(context).padding.bottom),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _PopupAction(
                            icon: FluentIcons.calendar_add_16_filled,
                            label: 'Session',
                            color: book['is_completed'] == 1
                                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)
                                : Theme.of(context).colorScheme.onSurface,
                            onTap: book['is_completed'] == 1 ? null : () {
                              Navigator.pop(context);
                              navigateToAddSessionPage(book);
                            },
                          ),
                          _PopupAction(
                            icon: Icons.edit,
                            label: 'Edit',
                            color: Theme.of(context).colorScheme.onSurface,
                            onTap: () {
                              Navigator.pop(context);
                              navigateToEditBookPage(book);
                            },
                          ),
                          _PopupAction(
                            icon: FluentIcons.share_16_filled,
                            label: 'Share',
                            color: Theme.of(context).colorScheme.onSurface,
                            onTap: () {
                              _showShareModal(context, book, stats, ratingStyle, dateRangeString);
                            },
                          ),
                          SizedBox(
                            width: 64,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert,
                                      color: Theme.of(context).colorScheme.onSurface, size: 32),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'duplicate':
                                        duplicateBook(context, book, refreshCallback, settingsViewModel);
                                        break;
                                      case 'delete':
                                        confirmDelete(book['id']);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'duplicate',
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(Icons.copy, size: 20,
                                            color: Theme.of(context).colorScheme.onSurface),
                                        title: Text('Duplicate',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurface)),
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(Icons.delete, size: 20, color: Colors.red),
                                        title: Text('Delete',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red)),
                                      ),
                                    ),
                                  ],
                                ),
                                Text('More', style: TextStyle(fontSize: 14,
                                    color: Theme.of(context).colorScheme.onSurface)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static void _showShareModal(
      BuildContext context,
      Map<String, dynamic> book,
      Map<String, dynamic> stats,
      int ratingStyle,
      String? dateRangeString,
      ) {
    final theme = Theme.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    Future<Uint8List?> captureKey(GlobalKey key) async {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    }

    Future<void> saveImage(GlobalKey key) async {
      try {
        final imageBytes = await captureKey(key);
        if (imageBytes == null) return;

        final result = await ImageGallerySaverPlus.saveImage(
          imageBytes,
          quality: 100,
          name: 'book_share_${book['id']}_${DateTime.now().millisecondsSinceEpoch}',
        );

        scaffoldMessenger.showSnackBar(SnackBar(
          content: Text(result['isSuccess'] == true
              ? 'Image saved to gallery!'
              : 'Failed to save image'),
        ));
      } catch (e) {
        scaffoldMessenger
            .showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }

    Future<void> shareImage(GlobalKey key) async {
      try {
        final imageBytes = await captureKey(key);
        if (imageBytes == null) return;

        final directory = await getTemporaryDirectory();
        final imagePath = '${directory.path}/book_share_${book['id']}.png';
        await File(imagePath).writeAsBytes(imageBytes);

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(imagePath)],
            text: 'Just finished "${book['title']}" — here are my reading stats!',
          ),
        );
      } catch (e) {
        scaffoldMessenger
            .showSnackBar(SnackBar(content: Text('Error sharing: $e')));
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final GlobalKey coverKey = GlobalKey();
        final GlobalKey minimalKey = GlobalKey();
        final CarouselSliderController carouselController = CarouselSliderController();
        int currentPage = 0;
        _ShareCardTheme selectedTheme = _ShareCardTheme.dark;

        final args = (
          title: book['title'] as String,
          author: book['author'] as String,
          rating: (book['rating'] as num?)?.toDouble() ?? 0.0,
          totalWords: (book['word_count'] as num?)?.toInt() ?? 0,
          totalPages: (stats['total_pages'] as num?)?.toInt() ?? 0,
          daysToComplete:
              _calculateDaysToComplete(book['date_started'], book['date_finished']),
          pagesPerMinute: (stats['pages_per_minute'] as num?)?.toDouble() ?? 0.0,
          wordsPerMinute: (stats['words_per_minute'] as num?)?.toDouble() ?? 0.0,
          totalTime: (stats['total_time'] as num?)?.toInt() ?? 0,
          dateRangeString: dateRangeString,
        );

        return StatefulBuilder(
          builder: (context, setState) {
            final isTransparent = selectedTheme == _ShareCardTheme.transparent;
            final isDark = selectedTheme == _ShareCardTheme.dark;

            Widget buildCard(GlobalKey key, bool allowCoverUpload) {
              final card = BookShareCard(
                title: args.title,
                author: args.author,
                rating: args.rating,
                totalWords: args.totalWords,
                totalPages: args.totalPages,
                daysToComplete: args.daysToComplete,
                pagesPerMinute: args.pagesPerMinute,
                wordsPerMinute: args.wordsPerMinute,
                totalTime: args.totalTime,
                dateRangeString: args.dateRangeString,
                allowCoverUpload: allowCoverUpload,
                isTransparent: isTransparent,
                isDark: isDark,
                initialCoverPath: book['cover_path'] as String?,
              );

              if (isTransparent) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      const Positioned.fill(child: CheckerboardBackground()),
                      RepaintBoundary(key: key, child: card),
                    ],
                  ),
                );
              }
              return RepaintBoundary(key: key, child: card);
            }

            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  CarouselSlider(
                    carouselController: carouselController,
                    options: CarouselOptions(
                      height: 480,
                      enlargeCenterPage: false,
                      viewportFraction: 0.78,
                      enableInfiniteScroll: false,
                      onPageChanged: (index, _) =>
                          setState(() => currentPage = index),
                      padEnds: true,
                    ),
                    items: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: buildCard(coverKey, true),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: buildCard(minimalKey, false),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  AnimatedSmoothIndicator(
                    activeIndex: currentPage,
                    count: 2,
                    effect: WormEffect(
                      dotHeight: 8,
                      dotWidth: 8,
                      activeDotColor: theme.colorScheme.primary,
                      dotColor: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                    ),
                    onDotClicked: (index) =>
                        carouselController.animateToPage(index),
                  ),

                  const SizedBox(height: 16),

                  // Theme selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ThemeCircle(
                        selected: selectedTheme == _ShareCardTheme.dark,
                        onTap: () => setState(() => selectedTheme = _ShareCardTheme.dark),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF121212),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _ThemeCircle(
                        selected: selectedTheme == _ShareCardTheme.light,
                        onTap: () => setState(() => selectedTheme = _ShareCardTheme.light),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _ThemeCircle(
                        selected: selectedTheme == _ShareCardTheme.transparent,
                        onTap: () =>
                            setState(() => selectedTheme = _ShareCardTheme.transparent),
                        child: ClipOval(child: CheckerboardBackground(squareSize: 12)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ShareAction(
                        icon: FluentIcons.arrow_download_16_filled,
                        label: 'Save',
                        theme: theme,
                        onTap: () async {
                          final key = currentPage == 0 ? coverKey : minimalKey;
                          await saveImage(key);
                        },
                      ),
                      _ShareAction(
                        icon: FluentIcons.share_16_filled,
                        label: 'Share',
                        theme: theme,
                        onTap: () async {
                          final key = currentPage == 0 ? coverKey : minimalKey;
                          await shareImage(key);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static int _calculateDaysToComplete(String? startDate, String? finishDate) {
    if (startDate != null && finishDate != null) {
      DateTime startDateTime = DateTime.parse(startDate);
      DateTime finishDateTime = DateTime.parse(finishDate);
      int days = finishDateTime.difference(startDateTime).inDays;
      int adjustedDays = days == 0 ? 1 : days;
      return adjustedDays;
    }
    return 0;
  }

  static String _getTimeToFinishCompact(
      int pagesRead,
      int totalPages,
      double pagesPerMinute,
      ) {
    if (totalPages <= 0) return "";

    final percentage = ((pagesRead / totalPages) * 100).clamp(0, 100).toStringAsFixed(1);

    if (pagesPerMinute <= 0 || totalPages <= pagesRead) {
      return "$percentage% complete";
    }

    final remainingPages = totalPages - pagesRead;
    final remainingMinutes = (remainingPages / pagesPerMinute).round();

    final hours = remainingMinutes ~/ 60;
    final minutes = remainingMinutes % 60;

    final timeString = hours > 0 ? "${hours}h ${minutes}m left" : "${minutes}m left";

    return "$percentage% (${remainingPages}p, $timeString)";
  }

  static String _getAudiobookProgressCompact(
      int timeListened,
      int totalDuration,
      ) {
    if (totalDuration <= 0) return "";

    final percentage =
    ((timeListened / totalDuration) * 100).clamp(0, 100).toStringAsFixed(1);

    if (timeListened >= totalDuration) {
      return "$percentage% complete";
    }

    final remainingMinutes = totalDuration - timeListened;
    final hours = remainingMinutes ~/ 60;
    final minutes = remainingMinutes % 60;

    final timeString = hours > 0 ? "${hours}h ${minutes}m left" : "${minutes}m left";

    return "$percentage% ($timeString)";
  }

  static Widget _buildRatingStars(double? rating) {
    final safeRating = rating ?? 0.0;

    return Align(
      alignment: Alignment.centerLeft,
      child: RatingBarIndicator(
        rating: safeRating,
        itemCount: 5,
        itemSize: 24.0,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, _) => Icon(
          Icons.star,
          color: rating == null ? Colors.grey.shade400 : Color(0xFFFBCB04),
        ),
      ),
    );
  }

  static Widget _buildRatingDisplay(int ratingStyle, double? rating) {
    if (ratingStyle == 0) {
      return _buildRatingStars(rating);
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rating != null ? rating.toStringAsFixed(1) : '-',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.star, size: 16, color: Color(0xFFFBCB04)),
        ],
      );
    }
  }

  static Widget _buildStatCell(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildStatDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _PopupAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _PopupAction({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, size: 32),
          color: color,
          onPressed: onTap,
        ),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: color),
        ),
      ],
    );
  }
}

enum _ShareCardTheme { light, dark, transparent }

class _ShareAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;
  final VoidCallback onTap;

  const _ShareAction({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, size: 26),
            color: theme.colorScheme.onSurface,
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _ThemeCircle extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _ThemeCircle({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: 3.0,
          ),
        ),
        padding: EdgeInsets.zero,
        child: ClipOval(child: child),
      ),
    );
  }
}
