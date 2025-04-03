import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '/data/database/database_helper.dart';

class BookPopup {
  static void showBookPopup(
    BuildContext context,
    Map<String, dynamic> book,
    int ratingStyle,
    Function navigateToEditBookPage,
    Function navigateToAddSessionPage,
    Function confirmDelete,
  ) async {
    final DatabaseHelper dbHelper = DatabaseHelper();
    final stats = await dbHelper.getBookStats(book['id']);
    final DateFormat dateFormat = DateFormat('M/d/yy');

    final bgColor = CupertinoColors.systemBackground.resolveFrom(context);
    final textColor = CupertinoColors.label.resolveFrom(context);
    final subtitleColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final cardColor =
        CupertinoColors.systemGrey5.resolveFrom(context).withOpacity(0.8);

    String defaultDate = '1999-11-15';

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

    // Get the page and word count from the book object
    int pageCount = book['page_count'] ?? 0;
    int wordCount = book['word_count'] ?? 0;

    // Format page count
    String pageCountString = pageCount == 0
        ? ""
        : "${pageCount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (match) => '${match[1]},')} "
            "${pageCount == 1 ? 'page' : 'pages'}";

    // Format word count with comma separator
    String wordCountString = wordCount == 0
        ? ""
        : "${wordCount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (match) => '${match[1]},')} "
            "${wordCount == 1 ? 'word' : 'words'}";

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

    String completionStatus = '';
    IconData completionIcon;
    Color completionColor;

    if (book['is_completed'] == 1) {
      completionStatus = 'Completed';
      completionIcon = CupertinoIcons.check_mark;
      completionColor = CupertinoColors.systemGrey;
    } else if (book['is_completed'] == 0 && stats['date_started'] != null) {
      // In progress
      completionStatus = 'In Progress';
      completionIcon = CupertinoIcons.arrow_2_circlepath;
      completionColor = CupertinoColors.systemGrey;
    } else {
      // Not started
      completionStatus = 'Not Started';
      completionIcon = CupertinoIcons.clock;
      completionColor = CupertinoColors.systemGrey;
    }

    IconData bookTypeIcon;
    switch (book['book_type_id']) {
      case 1:
        bookTypeIcon = CupertinoIcons.book;
        break;
      case 2:
        bookTypeIcon = CupertinoIcons.book_fill;
        break;
      case 3:
        bookTypeIcon = CupertinoIcons.device_desktop;
        break;
      case 4:
        bookTypeIcon = CupertinoIcons.headphones;
        break;
      default:
        bookTypeIcon = CupertinoIcons.book_fill;
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

    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoPopupSurface(
          isSurfacePainted: true,
          child: Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Book title
                Row(children: [
                  Expanded(
                    child: Text(
                      book['title'],
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Expanded(
                    child: Text(
                      "by ${book['author']}",
                      style: const TextStyle(fontSize: 14, wordSpacing: 2),
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      bookTypeIcon,
                      size: 18,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        bookTypeString,
                        style: const TextStyle(fontSize: 14, wordSpacing: 2),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 1.0, // Height of the divider
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey, // Color of the divider
                    borderRadius: BorderRadius.circular(
                        1.0), // Optional: Add rounded corners
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Book Completion Statuses
                    Expanded(
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
                                style: const TextStyle(fontSize: 14),
                              ),
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
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // const SizedBox(width: 10),

                    // Pages and words
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (pageCountString != '') ...[
                            Text(
                              pageCountString,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                          if (wordCountString != '') ...[
                            Text(
                              wordCountString,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _statCard(
                    title: 'Sessions',
                    value: stats['session_count']?.toString() ?? '0',
                    bgColor: cardColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor),
                _statCard(
                    title: 'Pages Read',
                    value: stats['total_pages']?.toString() ?? '0',
                    bgColor: cardColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor),
                _statCard(
                    title: 'Read Time',
                    value: formatTime(stats['total_time'] ?? 0),
                    bgColor: cardColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor),
                _statCard(
                    title: 'Pages/Minute',
                    value: stats['pages_per_minute']?.toStringAsFixed(2) ?? '0',
                    bgColor: cardColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor),
                _statCard(
                    title: 'Words/Minute',
                    value: stats['words_per_minute']?.toStringAsFixed(2) ?? '0',
                    bgColor: cardColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _popupAction(
                      icon: CupertinoIcons.trash,
                      label: 'Delete',
                      color: CupertinoColors.destructiveRed,
                      onTap: () {
                        Navigator.pop(context);
                        confirmDelete(book['id']);
                      },
                    ),
                    _popupAction(
                      icon: CupertinoIcons.square_pencil,
                      label: 'Edit',
                      color: textColor,
                      onTap: () {
                        Navigator.pop(context);
                        navigateToEditBookPage(book);
                      },
                    ),
                    _popupAction(
                      icon: CupertinoIcons.time,
                      label: 'Add',
                      color: book['is_completed'] == 1
                          ? CupertinoColors.systemGrey.withOpacity(0.5)
                          : textColor,
                      onTap: book['is_completed'] == 1
                          ? () {} // Disable interaction by providing an empty function
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
        );
      },
    );
  }

  static Widget _statCard({
    required String title,
    required String value,
    required Color bgColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 16, color: subtitleColor)),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  static Widget _popupAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: color),
          ),
        ],
      ),
    );
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
          CupertinoIcons.star_fill,
          color: CupertinoColors.systemYellow,
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
}
