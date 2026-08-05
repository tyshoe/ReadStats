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
import '../../sessions/widgets/rate_book_dialog.dart';
import '../book_form_page.dart';
import '/data/database/database_helper.dart';
import '/ui/widgets/book_cover.dart';
import 'book_share_card.dart';
import 'book_sessions_content.dart';
import 'bulk_tag_sheet.dart';

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
      {required Function() refreshCallback,
      bool isPinned = false,
      required Function(int) onTogglePin}) async {
    final DatabaseHelper dbHelper = DatabaseHelper();
    final stats = await dbHelper.getBookStats(book['id']);
    final ThemeData theme = Theme.of(context);
    final Color textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final Color subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    var tags = await tagRepository.getTagsForBook(book['id']);
    final shelves = await dbHelper.getShelves();

    final mutableBook = Map<String, dynamic>.from(book);
    var isPinnedState = isPinned;

    DateTime? startDateTime =
    book['date_started'] != null ? DateTime.parse(book['date_started']) : null;

    DateTime? finishDateTime =
    book['date_finished'] != null ? DateTime.parse(book['date_finished']) : null;

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

    final bool isAudiobook = book['book_type_id'] == 4;
    final int pageCount = book['page_count'] ?? 0;
    final int wordCount = book['word_count'] ?? 0;

    final String pageCountString = pageCount == 0
        ? ''
        : '${_formatCount(pageCount)} ${pageCount == 1 ? 'page' : 'pages'}';
    final String wordCountString = wordCount == 0
        ? ''
        : '${_formatCount(wordCount)} ${wordCount == 1 ? 'word' : 'words'}';

    String durationString = '';
    if (isAudiobook && (book['duration_minutes'] ?? 0) > 0) {
      final totalMins = book['duration_minutes'] as int;
      final hours = totalMins ~/ 60;
      final mins = totalMins % 60;
      durationString = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    }

    final (bookTypeIcon, bookTypeString) = _bookTypeDetails(book['book_type_id'] as int?);

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

            Future<void> openRateReview() => showRatingDialogForBook(
              context: context,
              book: mutableBook,
              bookRepository: bookRepository,
              settingsViewModel: settingsViewModel,
              onSaved: (rating, review) {
                setState(() {
                  mutableBook['rating'] = rating;
                  mutableBook['user_review'] = review;
                });
                refreshCallback();
              },
            );

            return DefaultTabController(
                length: 3,
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
                                    BookCover(
                                      path: book['cover_path'] as String,
                                      shape: book['cover_shape'] as int?,
                                      width: 90,
                                      borderRadius: 8,
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
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme.textTheme.titleLarge?.copyWith(
                                                  color: book['cover_path'] != null ? Colors.white : null,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () {
                                                onTogglePin(book['id']);
                                                setState(() => isPinnedState = !isPinnedState);
                                              },
                                              borderRadius: BorderRadius.circular(20),
                                              child: Icon(
                                                isPinnedState
                                                    ? Icons.push_pin
                                                    : Icons.push_pin_outlined,
                                                size: 24,
                                                color: isPinnedState
                                                    ? (book['cover_path'] != null
                                                        ? Colors.white
                                                        : theme.colorScheme.primary)
                                                    : book['cover_path'] != null
                                                        ? Colors.white.withValues(alpha: 0.7)
                                                        : Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
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
                                              borderRadius: BorderRadius.circular(20),
                                              child: Icon(
                                                mutableBook['is_favorite'] == 1
                                                    ? Icons.favorite
                                                    : Icons.favorite_border,
                                                size: 24,
                                                color: mutableBook['is_favorite'] == 1
                                                    ? Colors.red
                                                    : book['cover_path'] != null
                                                        ? Colors.white.withValues(alpha: 0.7)
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
                                                ? Colors.white.withValues(alpha: 0.7)
                                                : subtitleColor,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(bookTypeIcon, size: 16,
                                              color: book['cover_path'] != null ? Colors.white.withValues(alpha: 0.7) : subtitleColor),
                                            const SizedBox(width: 5),
                                            Text(bookTypeString, style: TextStyle(
                                              fontSize: 14,
                                              color: book['cover_path'] != null ? Colors.white.withValues(alpha: 0.7) : subtitleColor,
                                            )),
                                          ],
                                        ),
                                        if (!isAudiobook && (pageCountString != '' || wordCountString != '')) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            [pageCountString, wordCountString].where((s) => s.isNotEmpty).join(' · '),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: book['cover_path'] != null ? Colors.white.withValues(alpha: 0.7) : subtitleColor,
                                            ),
                                          ),
                                        ],
                                        if (isAudiobook && durationString != '') ...[
                                          const SizedBox(height: 4),
                                          Text(durationString, style: TextStyle(
                                            fontSize: 14,
                                            color: book['cover_path'] != null ? Colors.white.withValues(alpha: 0.7) : subtitleColor,
                                          )),
                                        ],
                                        const SizedBox(height: 8),
                                        Builder(builder: (context) {
                                          final ratingValue =
                                              (mutableBook['rating'] as num?)?.toDouble();
                                          final starColor = ratingValue == null
                                              ? Colors.grey.shade400
                                              : const Color(0xFFFBCB04);
                                          return Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (ratingValue != null) ...[
                                                Text(
                                                  ratingValue.toStringAsFixed(1),
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w800,
                                                    color: book['cover_path'] != null
                                                        ? Colors.white
                                                        : null,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              // Star preference → 5 stars; numeric → single star
                                              ratingStyle == 0
                                                  ? RatingBarIndicator(
                                                      rating: ratingValue ?? 0.0,
                                                      itemCount: 5,
                                                      itemSize: 24.0,
                                                      physics:
                                                          const NeverScrollableScrollPhysics(),
                                                      itemBuilder: (context, _) => Icon(
                                                        Icons.star_rounded,
                                                        color: starColor,
                                                      ),
                                                    )
                                                  : Icon(
                                                      Icons.star_rounded,
                                                      size: 22,
                                                      color: starColor,
                                                    ),
                                            ],
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Builder(builder: (context) {
                                      Future<void> openTagSheet() async {
                                        await showBulkTagSheet(
                                          context: context,
                                          selectedBookIds: [book['id']],
                                          tagRepository: tagRepository,
                                        );
                                        if (!context.mounted) return;
                                        final updatedTags = await tagRepository.getTagsForBook(book['id']);
                                        setState(() => tags = updatedTags);
                                        refreshCallback();
                                      }

                                      Widget tagChip(String label) => Container(
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        child: Text(label,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSecondaryContainer,
                                          ),
                                        ),
                                      );

                                      final addChip = GestureDetector(
                                        onTap: openTagSheet,
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
                                              Icon(Icons.add, size: 12,
                                                color: theme.colorScheme.onSurfaceVariant),
                                              const SizedBox(width: 3),
                                              Text('Add',
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );

                                      final tagIcon = Padding(
                                        padding: const EdgeInsets.only(top: 4, right: 6),
                                        child: Icon(Icons.sell, size: 16,
                                          color: book['cover_path'] != null
                                              ? Colors.white.withValues(alpha: 0.7)
                                              : theme.colorScheme.onSecondaryContainer),
                                      );

                                      if (tags.isEmpty) {
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [tagIcon, addChip],
                                        );
                                      }

                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          tagIcon,
                                          Expanded(
                                            child: Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: [
                                                for (final tag in tags.take(5)) tagChip(tag.name),
                                                if (tags.length > 5) tagChip('+${tags.length - 5}'),
                                                addChip,
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                              const SizedBox(height: 12),
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
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
                                              width: 36, height: 4,
                                              decoration: BoxDecoration(
                                                color: sheetTheme.colorScheme.outlineVariant,
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                                              child: Text('Move to shelf',
                                                style: sheetTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                            ),
                                            ...shelves.map((shelf) {
                                              final isSelected = shelf['id'] == currentShelfId;
                                              return ListTile(
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                                title: Text(shelf['name'],
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
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        shelves.firstWhere(
                                          (s) => s['id'] == mutableBook['shelf_id'],
                                          orElse: () => {'name': 'Unknown'},
                                        )['name'] as String,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: theme.colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.expand_more, size: 14,
                                        color: theme.colorScheme.onPrimaryContainer),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    ), // ClipRRect

                    // ── TABBED CONTENT ────────────────────────────────────
                    TabBar(
                      indicatorColor: settingsViewModel.accentColorNotifier.value,
                      labelColor: settingsViewModel.accentColorNotifier.value,
                      unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.63),
                      tabs: const [Tab(text: 'Stats'), Tab(text: 'Review'), Tab(text: 'Sessions')],
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

                          if (startDate != null || finishDate != null) ...[
                            const SizedBox(height: 12),
                            Builder(builder: (context) {
                              final daysValue = startDateTime != null && finishDateTime != null
                                  ? (finishDateTime.difference(startDateTime).inDays == 0
                                      ? 1
                                      : finishDateTime.difference(startDateTime).inDays)
                                  : null;
                              final lineColor = Theme.of(context).colorScheme.outlineVariant;

                              final cs = Theme.of(context).colorScheme;

                              Widget dateCard(String label, String? date, {bool alignEnd = false}) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: alignEnd
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      Text(label,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: subtitleColor,
                                          letterSpacing: 0.3,
                                        )),
                                      const SizedBox(height: 2),
                                      Text(date ?? '—',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        )),
                                    ],
                                  ),
                                );
                              }

                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    dateCard('Started', startDate),
                                    Expanded(
                                      child: Center(
                                        child: Row(
                                          children: [
                                            Expanded(child: Container(height: 1.5, color: lineColor)),
                                            if (daysValue != null) ...[
                                              Container(
                                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: lineColor),
                                                ),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text('$daysValue',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w700,
                                                        color: textColor,
                                                        height: 1.1,
                                                      )),
                                                    Text('days',
                                                      style: TextStyle(fontSize: 10, color: subtitleColor)),
                                                  ],
                                                ),
                                              ),
                                              Expanded(child: Container(height: 1.5, color: lineColor)),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    dateCard('Finished', finishDate, alignEnd: true),
                                  ],
                                ),
                              );
                            }),
                          ],

                          const SizedBox(height: 12),

                          // Stats grid
                          Builder(builder: (context) {
                            final sessionCount = (stats['session_count'] as int?) ?? 0;

                            // Empty state — no sessions logged yet
                            if (sessionCount == 0) {
                              final shelfId = mutableBook['shelf_id'] as int?;
                              final isFinished = shelfId == DatabaseHelper.shelfFinished ||
                                  shelfId == DatabaseHelper.shelfUnfinished;
                              final isCurrentlyReading =
                                  shelfId == DatabaseHelper.shelfCurrentlyReading;
                              final accent = settingsViewModel.accentColorNotifier.value;

                              final String title;
                              final String subtitle;
                              if (isFinished) {
                                title = 'No session data';
                                subtitle = 'This book was finished without logged sessions.';
                              } else if (isCurrentlyReading) {
                                title = 'No sessions yet';
                                subtitle = 'Log a session to start tracking time and pace.';
                              } else {
                                title = 'Nothing tracked yet';
                                subtitle = 'Stats appear once you start reading.';
                              }

                              return SizedBox(
                                width: double.infinity,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bar_chart_rounded,
                                          size: 32,
                                          color: subtitleColor.withValues(alpha: 0.4)),
                                      const SizedBox(height: 12),
                                      Text(title,
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: textColor)),
                                      const SizedBox(height: 4),
                                      Text(subtitle,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: subtitleColor.withValues(alpha: 0.7))),
                                      if (isCurrentlyReading) ...[
                                        const SizedBox(height: 16),
                                        FilledButton.tonalIcon(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            navigateToAddSessionPage(book);
                                          },
                                          style: FilledButton.styleFrom(
                                            backgroundColor: accent.withValues(alpha: 0.15),
                                            foregroundColor: accent,
                                            elevation: 0,
                                          ),
                                          icon: const Icon(
                                              FluentIcons.calendar_add_16_filled, size: 17),
                                          label: const Text('Log a session'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }

                            final totalTime = (stats['total_time'] as int?) ?? 0;
                            final ppm = (stats['pages_per_minute'] as num?)?.toDouble() ?? 0.0;
                            final wpm = (stats['words_per_minute'] as num?)?.toDouble() ?? 0.0;
                            final avgSession = sessionCount > 0 ? (totalTime / sessionCount).round() : 0;

                            final cells = <(String, String)>[
                              ('Sessions', sessionCount.toString()),
                              ('Read Time', _formatTime(totalTime)),
                              if (!isAudiobook) ('Pages Read', stats['total_pages']?.toString() ?? '0'),
                              if (totalTime > 0) ('Avg Session', _formatTime(avgSession)),
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

                            ],
                          ),
                          ),
                        ),
                      ),
                      Container(
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: Builder(builder: (context) {
                          final review = mutableBook['user_review'] as String?;
                          final hasReview = review != null && review.trim().isNotEmpty;
                          final accent = settingsViewModel.accentColorNotifier.value;
                          final openEditor = openRateReview;

                          if (!hasReview) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.rate_review_outlined,
                                    size: 32, color: subtitleColor.withValues(alpha: 0.4)),
                                  const SizedBox(height: 12),
                                  Text('No review yet',
                                    style: TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
                                  const SizedBox(height: 4),
                                  Text('Capture your thoughts on this book',
                                    style: TextStyle(
                                      fontSize: 12, color: subtitleColor.withValues(alpha: 0.7))),
                                  const SizedBox(height: 16),
                                  FilledButton.tonalIcon(
                                    onPressed: openEditor,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: accent.withValues(alpha: 0.15),
                                      foregroundColor: accent,
                                      elevation: 0,
                                    ),
                                    icon: const Icon(FluentIcons.compose_16_filled, size: 17),
                                    label: const Text('Write a review'),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: openEditor,
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                                    child: Text(
                                      review.trim(),
                                      style: TextStyle(fontSize: 15, color: textColor, height: 1.6),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: openEditor,
                                    style: TextButton.styleFrom(
                                      foregroundColor: accent,
                                      backgroundColor: accent.withValues(alpha: 0.12),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    icon: const Icon(FluentIcons.edit_16_filled, size: 15),
                                    label: const Text('Edit review'),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                      Container(
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: BookSessionsContent(
                          book: mutableBook,
                          dateFormatString: dateFormatString,
                          settingsViewModel: settingsViewModel,
                          onChanged: refreshCallback,
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
                            // Reads mutableBook so re-shelving from this sheet
                            // enables the action straight away.
                            color: DatabaseHelper.acceptsSessions(
                                    mutableBook['shelf_id'] as int?)
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                            onTap: DatabaseHelper.acceptsSessions(
                                    mutableBook['shelf_id'] as int?)
                                ? () {
                                    Navigator.pop(context);
                                    navigateToAddSessionPage(mutableBook);
                                  }
                                : null,
                          ),
                          _PopupAction(
                            icon: FluentIcons.share_16_filled,
                            label: 'Share',
                            color: Theme.of(context).colorScheme.onSurface,
                            onTap: () {
                              _showShareModal(context, mutableBook, stats, ratingStyle, dateRangeString);
                            },
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert,
                                      color: Theme.of(context).colorScheme.onSurface, size: 28),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'edit':
                                        Navigator.pop(context);
                                        navigateToEditBookPage(book);
                                        break;
                                      case 'duplicate':
                                        _duplicateBook(context, book, refreshCallback, settingsViewModel);
                                        break;
                                      case 'delete':
                                        confirmDelete(book['id']);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(Icons.edit, size: 20,
                                            color: Theme.of(context).colorScheme.onSurface),
                                        title: Text('Edit',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurface)),
                                      ),
                                    ),
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
                              Text('More', style: TextStyle(fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
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

    Future<Uint8List?> captureKey(GlobalKey key) async {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    }

    Future<bool> saveImage(GlobalKey key) async {
      try {
        final imageBytes = await captureKey(key);
        if (imageBytes == null) return false;
        final result = await ImageGallerySaverPlus.saveImage(
          imageBytes,
          quality: 100,
          name: 'book_share_${book['id']}_${DateTime.now().millisecondsSinceEpoch}',
        );
        return result['isSuccess'] == true;
      } catch (e) {
        return false;
      }
    }

    Future<bool> shareImage(GlobalKey key) async {
      try {
        final imageBytes = await captureKey(key);
        if (imageBytes == null) return false;
        final directory = await getTemporaryDirectory();
        final imagePath = '${directory.path}/book_share_${book['id']}.png';
        await File(imagePath).writeAsBytes(imageBytes);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(imagePath)],
            text: 'Just finished "${book['title']}" — here are my reading stats!',
          ),
        );
        return true;
      } catch (e) {
        return false;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final GlobalKey coverKey = GlobalKey();
        final GlobalKey coverMinimalKey = GlobalKey();
        final GlobalKey dominantKey = GlobalKey();
        final GlobalKey reviewKey = GlobalKey();
        final CarouselSliderController carouselController = CarouselSliderController();
        int currentPage = 0;
        bool isSaving = false;
        bool isSharing = false;
        bool saveSuccess = false;
        String? actionError;
        final appIsDark = Theme.of(context).brightness == Brightness.dark;
        _ShareCardTheme selectedTheme = appIsDark ? _ShareCardTheme.dark : _ShareCardTheme.light;

        final args = (
          title: book['title'] as String,
          author: book['author'] as String,
          rating: (book['rating'] as num?)?.toDouble() ?? 0.0,
          totalPages: (stats['total_pages'] as num?)?.toInt() ?? 0,
          wordCount: (book['word_count'] as int?) ?? 0,
          daysToComplete:
              _calculateDaysToComplete(book['date_started'], book['date_finished']),
          pagesPerMinute: (stats['pages_per_minute'] as num?)?.toDouble() ?? 0.0,
          wordsPerMinute: (stats['words_per_minute'] as num?)?.toDouble() ?? 0.0,
          totalTime: (stats['total_time'] as num?)?.toInt() ?? 0,
          sessionCount: (stats['session_count'] as num?)?.toInt() ?? 0,
          dateRangeString: dateRangeString,
          userReview: book['user_review'] as String?,
          bookTypeName: _bookTypeName(book['book_type_id'] as int?),
        );

        final hasCoverImage = book['cover_path'] != null;
        bool useCoverBackground = true;

        return StatefulBuilder(
          builder: (context, setState) {
            final isTransparent = selectedTheme == _ShareCardTheme.transparent;
            final isDark = selectedTheme == _ShareCardTheme.dark;

            Widget buildCard(GlobalKey key, ShareCardStyle style) {
              final card = BookShareCard(
                title: args.title,
                author: args.author,
                rating: args.rating,
                totalPages: args.totalPages,
                wordCount: args.wordCount,
                daysToComplete: args.daysToComplete,
                pagesPerMinute: args.pagesPerMinute,
                wordsPerMinute: args.wordsPerMinute,
                totalTime: args.totalTime,
                sessionCount: args.sessionCount,
                dateRangeString: args.dateRangeString,
                userReview: args.userReview,
                bookTypeName: args.bookTypeName,
                headerColor: theme.colorScheme.primary,
                useCoverBackground: useCoverBackground,
                isTransparent: isTransparent,
                isDark: isDark,
                initialCoverPath: book['cover_path'] as String?,
                coverShape: book['cover_shape'] as int?,
                style: style,
              );

              final repaint = RepaintBoundary(key: key, child: card);
              final inner = isTransparent
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: const CheckerboardBackground(
                                squareSize: _kCheckerSquareSize),
                          ),
                        ),
                        repaint,
                      ],
                    )
                  : repaint;
              return SizedBox(
                height: _kCardHeight,
                child: Align(alignment: Alignment.topCenter, child: inner),
              );
            }

            final sheetBg = appIsDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8E8E8);
            return Container(
              decoration: BoxDecoration(
                color: sheetBg,
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
                      height: 420,
                      enlargeCenterPage: false,
                      viewportFraction: 0.85,
                      enableInfiniteScroll: false,
                      onPageChanged: (index, _) =>
                          setState(() => currentPage = index),
                      padEnds: true,
                    ),
                    items: [
                      ClipRect(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: buildCard(coverKey, ShareCardStyle.cover),
                        ),
                      ),
                      ClipRect(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: buildCard(coverMinimalKey, ShareCardStyle.coverMinimal),
                        ),
                      ),
                      ClipRect(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: buildCard(dominantKey, ShareCardStyle.coverDominant),
                        ),
                      ),
                      ClipRect(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: buildCard(reviewKey, ShareCardStyle.review),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),
                  AnimatedSmoothIndicator(
                    activeIndex: currentPage,
                    count: 4,
                    effect: WormEffect(
                      dotHeight: 7,
                      dotWidth: 7,
                      activeDotColor: theme.colorScheme.primary,
                      dotColor: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                    ),
                    onDotClicked: (index) =>
                        carouselController.animateToPage(index),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    const ['Cover', 'Cover Simple', 'Poster', 'Review'][currentPage],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (isTransparent) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Saves as PNG with transparency',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Theme selector — circles centered, cover toggle in right spacer
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        const Spacer(),
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
                        Expanded(
                          child: hasCoverImage
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 16),
                                    child: FilterChip(
                                      avatar: Icon(
                                        Icons.image_outlined,
                                        size: 14,
                                        color: useCoverBackground
                                            ? theme.colorScheme.onPrimaryContainer
                                            : theme.colorScheme.onSurfaceVariant,
                                      ),
                                      label: const Text('Cover'),
                                      selected: useCoverBackground,
                                      onSelected: (v) => setState(() => useCoverBackground = v),
                                      showCheckmark: false,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: useCoverBackground
                                              ? Colors.transparent
                                              : theme.colorScheme.outline,
                                        ),
                                      ),
                                      selectedColor: theme.colorScheme.primaryContainer,
                                      labelStyle: theme.textTheme.labelSmall?.copyWith(
                                        color: useCoverBackground
                                            ? theme.colorScheme.onPrimaryContainer
                                            : theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: actionError != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              actionError!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ShareAction(
                        icon: FluentIcons.arrow_download_16_filled,
                        label: 'Save',
                        theme: theme,
                        isLoading: isSaving,
                        isSuccess: saveSuccess,
                        onTap: isSaving || isSharing || saveSuccess ? null : () async {
                          setState(() { isSaving = true; actionError = null; });
                          final key = [coverKey, coverMinimalKey, dominantKey, reviewKey][currentPage];
                          final success = await saveImage(key);
                          if (success) {
                            setState(() { isSaving = false; saveSuccess = true; });
                            Future.delayed(const Duration(milliseconds: 1400), () {
                              if (context.mounted) Navigator.pop(context);
                            });
                          } else {
                            setState(() {
                              isSaving = false;
                              actionError = 'Failed to save. Please try again.';
                            });
                          }
                        },
                      ),
                      _ShareAction(
                        icon: FluentIcons.share_16_filled,
                        label: 'Share',
                        theme: theme,
                        isLoading: isSharing,
                        onTap: isSaving || isSharing || saveSuccess ? null : () async {
                          setState(() { isSharing = true; actionError = null; });
                          final key = [coverKey, coverMinimalKey, dominantKey, reviewKey][currentPage];
                          final success = await shareImage(key);
                          if (!success) {
                            setState(() { isSharing = false; actionError = 'Failed to share. Please try again.'; });
                          } else {
                            setState(() => isSharing = false);
                          }
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

  static String? _bookTypeName(int? id) {
    return switch (id) {
      1 => 'Paperback',
      2 => 'Hardback',
      3 => 'eBook',
      4 => 'Audiobook',
      _ => null,
    };
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

  static (IconData, String) _bookTypeDetails(int? id) {
    return switch (id) {
      1 => (Icons.book_outlined, 'Paperback'),
      2 => (Icons.book, 'Hardback'),
      3 => (Icons.computer, 'eBook'),
      4 => (Icons.headset, 'Audiobook'),
      _ => (Icons.book, 'Paperback'),
    };
  }

  static String _formatTime(int totalMinutes) {
    final days = totalMinutes ~/ (24 * 60);
    final hours = (totalMinutes % (24 * 60)) ~/ 60;
    final minutes = totalMinutes % 60;
    final buf = StringBuffer();
    if (days > 0) buf.write('${days}d ');
    if (hours > 0 || days > 0) buf.write('${hours}h ');
    buf.write('${minutes}m');
    return buf.toString();
  }

  static String _formatCount(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  static void _duplicateBook(
      BuildContext context,
      Map<String, dynamic> book,
      Function refreshCallback,
      SettingsViewModel settingsViewModel) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookFormPage(
          book: {
            'title': '${book['title']} (Copy)',
            'author': book['author'],
            'word_count': book['word_count'],
            'page_count': book['page_count'],
            'book_type_id': book['book_type_id'],
            'rating': null,
            'is_favorite': 0,
            'date_started': null,
            'date_finished': null,
            'date_added': DateTime.now().toIso8601String(),
          },
          onSave: (_) => refreshCallback(),
          settingsViewModel: settingsViewModel,
        ),
      ),
    );
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
          icon: Icon(icon, size: 28),
          color: color,
          onPressed: onTap,
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }
}

enum _ShareCardTheme { light, dark, transparent }

const double _kCheckerSquareSize = 22;
const double _kCardHeight = 370;

class _ShareAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isSuccess;

  const _ShareAction({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.isLoading = false,
    this.isSuccess = false,
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
            color: isSuccess
                ? const Color(0xFF34C759)
                : theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: isLoading
              ? Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                )
              : isSuccess
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 28)
                  : IconButton(
                      icon: Icon(icon, size: 26),
                      color: onTap != null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      onPressed: onTap,
                    ),
        ),
        const SizedBox(height: 6),
        Text(
          isSuccess ? 'Saved!' : label,
          style: TextStyle(
            fontSize: 12,
            color: isSuccess
                ? const Color(0xFF34C759)
                : onTap != null
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
        ),
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
          color: selected
              ? primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
        padding: const EdgeInsets.all(3),
        child: ClipOval(child: child),
      ),
    );
  }
}
