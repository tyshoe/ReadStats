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
    final DateFormat dateFormat = DateFormat(dateFormatString);

    final ThemeData theme = Theme.of(context);
    final Color textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final Color subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final tags = await tagRepository.getTagsForBook(book['id']);

    final mutableBook = Map<String, dynamic>.from(book);

    DateTime? startDateTime =
    book['date_started'] != null ? DateTime.parse(book['date_started']) : null;

    DateTime? finishDateTime =
    book['date_finished'] != null ? DateTime.parse(book['date_finished']) : null;

    String? startDate = startDateTime != null ? dateFormat.format(startDateTime) : null;
    String? finishDate = finishDateTime != null ? dateFormat.format(finishDateTime) : null;

    String daysToCompleteString = "";

    if (startDateTime != null && finishDateTime != null) {
      int days = finishDateTime.difference(startDateTime).inDays;
      int adjustedDays = days == 0 ? 1 : days;
      daysToCompleteString = " ($adjustedDays ${adjustedDays == 1 ? 'day' : 'days'})";
    }

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
    String completionStatus = '';
    IconData completionIcon;
    Color completionColor;

    if (book['is_completed'] == 1) {
      completionStatus = 'Completed';
      completionIcon = Icons.check;
      completionColor = Colors.grey;
    } else if (book['is_completed'] == 0 && stats['date_started'] != null) {
      completionStatus = 'In Progress';
      completionIcon = Icons.autorenew;
      completionColor = Colors.grey;
    } else {
      completionStatus = 'Not Started';
      completionIcon = Icons.schedule;
      completionColor = Colors.grey;
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              book['title'],
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              mutableBook['is_favorite'] == 1
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                            ),
                            color: mutableBook['is_favorite'] == 1 ? Colors.red : Colors.grey,
                            onPressed: () async {
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "by ${book['author']}",
                        style: TextStyle(fontSize: 14, color: subtitleColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(bookTypeIcon, size: 18, color: textColor),
                          const SizedBox(width: 5),
                          Text(
                            bookTypeString,
                            style: TextStyle(fontSize: 14, color: textColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Divider(color: Colors.grey[300], height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Book Completion Status
                          Expanded(
                            flex: 7,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(completionIcon, color: completionColor, size: 18),
                                    const SizedBox(width: 5),
                                    Text(
                                      completionStatus,
                                      style: TextStyle(fontSize: 14, color: textColor),
                                    ),
                                    if (book['is_completed'] == 0 &&
                                        (isAudiobook
                                            ? (stats['total_time'] ?? 0) > 0 &&
                                            (book['duration_minutes'] ?? 0) > 0
                                            : (stats['total_pages'] ?? 0) > 0 &&
                                            (book['page_count'] ?? 0) > 0)) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        isAudiobook
                                            ? _getAudiobookProgressCompact(
                                          stats['total_time'] ?? 0,
                                          book['duration_minutes'] ?? 0,
                                        )
                                            : _getTimeToFinishCompact(
                                          stats['total_pages'] ?? 0,
                                          book['page_count'] ?? 0,
                                          stats['pages_per_minute'] ?? 0,
                                        ),
                                        style: TextStyle(fontSize: 14, color: subtitleColor),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 5),
                                _buildRatingDisplay(ratingStyle, book['rating']),
                                if (dateRangeString != '') ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    dateRangeString + daysToCompleteString,
                                    style: TextStyle(fontSize: 14, color: textColor),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Pages/words or duration
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isAudiobook) ...[
                                  if (pageCountString != '')
                                    Text(
                                      pageCountString,
                                      style: TextStyle(fontSize: 14, color: textColor),
                                    ),
                                  if (wordCountString != '')
                                    Text(
                                      wordCountString,
                                      style: TextStyle(fontSize: 14, color: textColor),
                                    ),
                                ] else if (durationString != '') ...[
                                  Text(
                                    durationString,
                                    style: TextStyle(fontSize: 14, color: textColor),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (tags.isNotEmpty) ...[
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: tags.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.sell, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      tags[index].name,
                                      style: TextStyle(color: textColor, fontSize: 12),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Stat cards — Read Time moved above Pages Read,
                      // pages/speed stats hidden for audiobooks
                      _buildStatCard(
                          context, 'Sessions', stats['session_count']?.toString() ?? '0'),
                      _buildStatCard(
                          context, 'Read Time', formatTime(stats['total_time'] ?? 0)),
                      if (!isAudiobook) ...[
                        _buildStatCard(
                            context, 'Pages Read', stats['total_pages']?.toString() ?? '0'),
                        _buildStatCard(context, 'Pages/Min',
                            stats['pages_per_minute']?.toStringAsFixed(2) ?? '0'),
                        _buildStatCard(context, 'Words/Min',
                            stats['words_per_minute']?.toStringAsFixed(2) ?? '0'),
                      ],

                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Add Session Button
                          _PopupAction(
                            icon: FluentIcons.calendar_add_16_filled,
                            label: 'Session',
                            color: book['is_completed'] == 1
                                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)
                                : Theme.of(context).colorScheme.onSurface,
                            onTap: book['is_completed'] == 1
                                ? null
                                : () {
                              Navigator.pop(context);
                              navigateToAddSessionPage(book);
                            },
                          ),

                          // Edit Button
                          _PopupAction(
                            icon: Icons.edit,
                            label: 'Edit',
                            color: Theme.of(context).colorScheme.onSurface,
                            onTap: () {
                              Navigator.pop(context);
                              navigateToEditBookPage(book);
                            },
                          ),

                          // Share Button
                          _PopupAction(
                            icon: FluentIcons.share_16_filled,
                            label: 'Share',
                            color: Theme.of(context).colorScheme.onSurface,
                            onTap: () {
                              _showShareModal(
                                  context, book, stats, ratingStyle, dateRangeString);
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
                                        duplicateBook(
                                            context, book, refreshCallback, settingsViewModel);
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
                                        leading: Icon(Icons.copy,
                                            size: 20,
                                            color: Theme.of(context).colorScheme.onSurface),
                                        title: Text('Duplicate',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                              color:
                                              Theme.of(context).colorScheme.onSurface,
                                            )),
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        dense: true,
                                        leading:
                                        Icon(Icons.delete, size: 20, color: Colors.red),
                                        title: Text('Delete',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(color: Colors.red)),
                                      ),
                                    ),
                                  ],
                                ),
                                Text('More',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
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

  static Widget _buildStatCard(BuildContext context, String title, String value) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
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
