import 'dart:io';
import 'dart:typed_data';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screenshot/screenshot.dart';
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
      // Create a new book map with only the fields you want to duplicate
      Map<String, dynamic> duplicatedBook = {
        'title': '${book['title']} (Copy)', // Add "Copy" to title to distinguish
        'author': book['author'],
        'word_count': book['word_count'],
        'page_count': book['page_count'],
        'book_type_id': book['book_type_id'],
        'rating': null, // Reset rating for new copy
        'is_completed': 0, // New copy is not completed
        'is_favorite': 0, // Reset favorite status
        'date_started': null, // Reset start date
        'date_finished': null, // Clear finished date
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
                        style: TextStyle(
                          fontSize: 14,
                          color: subtitleColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            bookTypeIcon,
                            size: 18,
                            color: textColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            bookTypeString,
                            style: TextStyle(
                              fontSize: 14,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Divider(
                        color: Colors.grey[300],
                        height: 1,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Book Completion Statuses
                          Expanded(
                            flex: 7,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      completionIcon,
                                      color: completionColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      completionStatus,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: textColor,
                                      ),
                                    ),
                                    if (book['is_completed'] == 0 &&
                                        (stats['total_pages'] ?? 0) > 0 &&
                                        (book['page_count'] ?? 0) > 0) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        _getTimeToFinishCompact(
                                          stats['total_pages'] ?? 0,
                                          book['page_count'] ?? 0,
                                          stats['pages_per_minute'] ?? 0,
                                        ),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: subtitleColor,
                                        ),
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
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Pages and words
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (pageCountString != '') ...[
                                  Text(
                                    pageCountString,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                                if (wordCountString != '') ...[
                                  Text(
                                    wordCountString,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColor,
                                    ),
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
                                    Icon(
                                      Icons.sell,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      tags[index].name,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      _buildStatCard(
                          context, 'Sessions', stats['session_count']?.toString() ?? '0'),
                      _buildStatCard(
                          context, 'Pages Read', stats['total_pages']?.toString() ?? '0'),
                      _buildStatCard(context, 'Read Time', formatTime(stats['total_time'] ?? 0)),
                      _buildStatCard(context, 'Pages/Min',
                          stats['pages_per_minute']?.toStringAsFixed(2) ?? '0'),
                      _buildStatCard(context, 'Words/Min',
                          stats['words_per_minute']?.toStringAsFixed(2) ?? '0'),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Add Session Button
                          _PopupAction(
                            icon: FluentIcons.calendar_add_16_filled,
                            label: 'Session',
                            color: book['is_completed'] == 1
                                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.38)
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
                              // Navigator.pop(context);
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
                                      color: Theme.of(context).colorScheme.onSurface,
                                      size: 32), // Match icon size
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
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                )),
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(Icons.delete, size: 20, color: Colors.red),
                                        title: Text('Delete',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: Colors.red,
                                                )),
                                      ),
                                    ),
                                  ],
                                ),
                                // const SizedBox(height: 2),
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
    Future<void> saveImage(ScreenshotController controller) async {
      // Request permission (Android 13+ needs READ_MEDIA_IMAGES, iOS uses Photos)
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permission denied")),
        );
        return;
      }

      try {
        final Uint8List? imageBytes = await controller.capture();
        if (imageBytes == null) return;

        final result = await ImageGallerySaverPlus.saveImage(
          imageBytes,
          quality: 100,
          name: "book_share_${book['id']}_${DateTime.now().millisecondsSinceEpoch}",
        );

        final isSuccess = (result['isSuccess'] == true);
        if (isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Image saved to gallery!")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to save image")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }

    Future<void> shareImage(ScreenshotController controller) async {
      try {
        final Uint8List? imageBytes = await controller.capture();
        if (imageBytes == null) return;

        // Create a temporary file to share
        final directory = await getTemporaryDirectory();
        final imagePath = '${directory.path}/book_share_${book['id']}.png';
        final File imageFile = File(imagePath);
        await imageFile.writeAsBytes(imageBytes);

        // Using ShareParams format
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(imagePath)],
            text: 'Check out my reading stats!',
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sharing: $e")),
        );
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final ScreenshotController screenshotControllerMinimal = ScreenshotController();
        final ScreenshotController screenshotControllerCover = ScreenshotController();
        final CarouselSliderController carouselController = CarouselSliderController();

        int currentPage = 0; // track active page

        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              minChildSize: 0.6,
              maxChildSize: 0.85,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      // draggable notch
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Container(
                          height: 4,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          child: Column(
                            children: [
                              Expanded(
                                child: CarouselSlider(
                                  carouselController: carouselController,
                                  options: CarouselOptions(
                                      height: 650,
                                      enlargeCenterPage: false,
                                      viewportFraction: 0.9,
                                      enableInfiniteScroll: false,
                                      onPageChanged: (index, reason) {
                                        setState(() {
                                          currentPage = index;
                                        });
                                      },
                                      padEnds: true),
                                  items: [
                                    Screenshot(
                                      controller: screenshotControllerCover,
                                      child: BookShareCard(
                                        title: book['title'],
                                        author: book['author'],
                                        rating: (book['rating'] as num?)?.toDouble() ?? 0.0,
                                        totalWords: (book['word_count'] as num?)?.toInt() ?? 0,
                                        totalPages: (stats['total_pages'] as num?)?.toInt() ?? 0,
                                        daysToComplete: _calculateDaysToComplete(
                                            book['date_started'], book['date_finished']),
                                        pagesPerMinute:
                                            (stats['pages_per_minute'] as num?)?.toDouble() ?? 0.0,
                                        wordsPerMinute:
                                            (stats['words_per_minute'] as num?)?.toDouble() ?? 0.0,
                                        totalTime: (stats['total_time'] as num?)?.toInt() ?? 0,
                                        dateRangeString: dateRangeString,
                                        allowCoverUpload: true,
                                      ),
                                    ),
                                    Screenshot(
                                      controller: screenshotControllerMinimal,
                                      child: BookShareCard(
                                        title: book['title'],
                                        author: book['author'],
                                        rating: (book['rating'] as num?)?.toDouble() ?? 0.0,
                                        totalWords: (book['word_count'] as num?)?.toInt() ?? 0,
                                        totalPages: (stats['total_pages'] as num?)?.toInt() ?? 0,
                                        daysToComplete: _calculateDaysToComplete(
                                            book['date_started'], book['date_finished']),
                                        pagesPerMinute:
                                            (stats['pages_per_minute'] as num?)?.toDouble() ?? 0.0,
                                        wordsPerMinute:
                                            (stats['words_per_minute'] as num?)?.toDouble() ?? 0.0,
                                        totalTime: (stats['total_time'] as num?)?.toInt() ?? 0,
                                        dateRangeString: dateRangeString,
                                        allowCoverUpload: false,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Page indicator synced with Carousel
                              AnimatedSmoothIndicator(
                                activeIndex: currentPage,
                                count: 2,
                                effect: WormEffect(
                                  dotHeight: 8,
                                  dotWidth: 8,
                                  activeDotColor: theme.colorScheme.primary,
                                  dotColor: theme.colorScheme.onSurface.withOpacity(0.3),
                                ),
                                onDotClicked: (index) {
                                  carouselController.animateToPage(index);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ACTION BUTTONS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Save
                          Column(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(FluentIcons.arrow_download_16_filled, size: 24),
                                  color: theme.colorScheme.onSurface,
                                  onPressed: () async {
                                    final controller = currentPage == 0
                                        ? screenshotControllerMinimal
                                        : screenshotControllerCover;
                                    await saveImage(controller);
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text("Save", style: TextStyle(fontSize: 12)),
                            ],
                          ),

                          // Share
                          Column(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(FluentIcons.share_16_filled, size: 24),
                                  color: theme.colorScheme.onSurface,
                                  onPressed: () async {
                                    final controller = currentPage == 0
                                        ? screenshotControllerMinimal
                                        : screenshotControllerCover;
                                    await shareImage(controller);
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text("Share", style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
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
          style: TextStyle(
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
  }
}
