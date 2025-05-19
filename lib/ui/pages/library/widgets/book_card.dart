import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../../../data/repositories/tag_repository.dart';
import '/data/database/database_helper.dart';

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
      ) async {
    final DatabaseHelper dbHelper = DatabaseHelper();
    final stats = await dbHelper.getBookStats(book['id']);
    final DateFormat dateFormat = DateFormat(dateFormatString);

    final ThemeData theme = Theme.of(context);
    final Color textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final Color subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final tags = await tagRepository.getTagsForBook(book['id']);

    DateTime? startDateTime = book['date_started'] != null
        ? DateTime.parse(book['date_started'])
        : null;

    DateTime? finishDateTime = book['date_finished'] != null
        ? DateTime.parse(book['date_finished'])
        : null;

    String? startDate =
    startDateTime != null ? dateFormat.format(startDateTime) : null;
    String? finishDate =
    finishDateTime != null ? dateFormat.format(finishDateTime) : null;

    String daysToCompleteString = "";

    if (startDateTime != null && finishDateTime != null) {
      int days = finishDateTime.difference(startDateTime).inDays;
      int adjustedDays = days == 0 ? 1 : days;
      daysToCompleteString =
      "($adjustedDays ${adjustedDays == 1 ? 'day' : 'days'})";
    }

    String dateRangeString = "";

    if (startDate != null && finishDate != null) {
      dateRangeString = "$startDate - $finishDate $daysToCompleteString";
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

    // Favorite
    IconData favoriteIcon = book['is_favorite'] == 1
        ? Icons.favorite
        : Icons.favorite_border;
    Color favoriteIconColor = book['is_favorite'] == 1
        ? Colors.red
        : Colors.grey;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        favoriteIcon,
                        color: favoriteIconColor,
                        size: 24,
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
                            if (book['is_completed'] == 1) ...[
                              const SizedBox(height: 5),
                              _buildRatingDisplay(ratingStyle, book['rating'] ?? 0),
                            ],
                            if (dateRangeString != '') ...[
                              const SizedBox(height: 5),
                              Text(
                                dateRangeString,
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
                  _buildStatCard(context, 'Sessions', stats['session_count']?.toString() ?? '0'),
                  _buildStatCard(context, 'Pages Read', stats['total_pages']?.toString() ?? '0'),
                  _buildStatCard(context, 'Read Time', formatTime(stats['total_time'] ?? 0)),
                  _buildStatCard(context, 'Pages/Min', stats['pages_per_minute']?.toStringAsFixed(2) ?? '0'),
                  _buildStatCard(context, 'Words/Min', stats['words_per_minute']?.toStringAsFixed(2) ?? '0'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _PopupAction(
                        icon: Icons.delete,
                        label: 'Delete',
                        color: Colors.red,
                        onTap: () {
                          Navigator.pop(context);
                          confirmDelete(book['id']);
                        },
                      ),
                      _PopupAction(
                        icon: Icons.edit,
                        label: 'Edit',
                        color: textColor,
                        onTap: () {
                          Navigator.pop(context);
                          navigateToEditBookPage(book);
                        },
                      ),
                      _PopupAction(
                        icon: Icons.more_time,
                        label: 'Add',
                        color: book['is_completed'] == 1
                            ? Colors.grey
                            : textColor,
                        onTap: book['is_completed'] == 1
                            ? null
                            : () {
                          Navigator.pop(context);
                          navigateToAddSessionPage(book['id']);
                        },
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
  }

  static String _getTimeToFinishCompact(
      int pagesRead,
      int totalPages,
      double pagesPerMinute,
      ) {
    if (totalPages <= 0) return "";

    final percentage =
    ((pagesRead / totalPages) * 100).clamp(0, 100).toStringAsFixed(1);

    if (pagesPerMinute <= 0 || totalPages <= pagesRead) {
      return "$percentage% complete";
    }

    final remainingPages = totalPages - pagesRead;
    final remainingMinutes = (remainingPages / pagesPerMinute).round();

    final hours = remainingMinutes ~/ 60;
    final minutes = remainingMinutes % 60;

    final timeString =
    hours > 0 ? "${hours}h ${minutes}m left" : "${minutes}m left";

    return "$percentage% ($timeString)";
  }

  static Widget _buildRatingStars(double rating) {
    return Align(
      alignment: Alignment.centerLeft,
      child: RatingBarIndicator(
        rating: rating, // Directly use the rating value
        itemCount: 5,
        itemSize: 24.0,
        physics: const NeverScrollableScrollPhysics(), // Prevent interaction
        itemBuilder: (context, _) => const Icon(
          Icons.star,
          color: Colors.yellow,
        ),
      ),
    );
  }

  static Widget _buildRatingDisplay(int ratingStyle, double rating) {
    if (ratingStyle == 0) {
      return _buildRatingStars(rating);
    } else {
      return Text(
        rating.toStringAsFixed(1),
        style: const TextStyle(fontSize: 14),
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