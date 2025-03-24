import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import '/data/database/database_helper.dart';
import 'package:intl/intl.dart';

class BookPopup {
  static void showBookPopup(
    BuildContext context,
    Map<String, dynamic> book,
    Function navigateToEditBookPage,
    Function navigateToAddSessionPage,
    Function confirmDelete,
  ) async {
    final DatabaseHelper dbHelper = DatabaseHelper();
    final stats = await dbHelper.getBookStats(book['id']);
    final DateFormat dateFormat = DateFormat('M/d/yy');

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
                // Book Title and Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Book Title, Author, and Word Count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book['title'],
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow
                                .ellipsis, // Ensures long titles are truncated
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "by ${book['author']}",
                            style:
                                const TextStyle(fontSize: 14, wordSpacing: 2),
                            maxLines: 1,
                            overflow: TextOverflow
                                .ellipsis, // Truncate long author names
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "${book['word_count']?.toString() ?? '0'} words",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Rating and Completion Status to the right
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
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
                          _buildRatingStars(book['rating'] ?? 0),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Stats (Sessions, Pages, Read Time, etc.)
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        title: 'Sessions',
                        value: stats['session_count']?.toString() ?? '0',
                        context: context,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statCard(
                        title: 'Pages Read',
                        value: stats['total_pages']?.toString() ?? '0',
                        context: context,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statCard(
                        title: 'Read Time',
                        value: formatTime(stats['total_time'] ?? 0),
                        context: context,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: _statCard(
                        title: 'Pages/Minute',
                        value: stats['pages_per_minute']?.toStringAsFixed(2) ??
                            '0',
                        context: context,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statCard(
                        title: 'Words/Minute',
                        value: stats['words_per_minute']?.toStringAsFixed(2) ??
                            '0',
                        context: context,
                      ),
                    ),
                  ],
                ),
                _dateStatsCard(
                  startDate: dateFormat.format(
                      DateTime.parse(stats['date_started'] ?? '1999-11-15')),
                  finishDate: dateFormat.format(
                      DateTime.parse(stats['date_finished'] ?? '1999-11-15')),
                  daysToComplete: book['date_started'] != null &&
                          book['date_finished'] != null
                      ? (DateTime.parse(book['date_finished'])
                              .difference(DateTime.parse(book['date_started']))
                              .inDays)
                          .toString()
                      : 'n/a',
                  context: context,
                ),
                const SizedBox(height: 16),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _popupAction(
                      icon: CupertinoIcons.pencil,
                      label: 'Edit',
                      onTap: () {
                        Navigator.pop(context);
                        navigateToEditBookPage(book);
                      },
                    ),
                    _popupAction(
                      icon: CupertinoIcons.book,
                      label: 'Add Session',
                      color: book['is_completed'] == 1
                          ? CupertinoColors.systemGrey
                          : CupertinoColors.activeBlue,
                      onTap: book['is_completed'] == 1
                          ? () {} // Disable interaction by providing an empty function
                          : () {
                              Navigator.pop(context);
                              navigateToAddSessionPage(book['id']);
                            },
                    ),
                    _popupAction(
                      icon: CupertinoIcons.trash,
                      label: 'Delete',
                      color: CupertinoColors.destructiveRed,
                      onTap: () {
                        Navigator.pop(context);
                        confirmDelete(book['id']);
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
    required BuildContext context,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color:
            CupertinoColors.systemGrey5.resolveFrom(context).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 14, color: CupertinoColors.systemGrey),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _dateStatsCard({
    required BuildContext context,
    required String startDate,
    required String finishDate,
    required String daysToComplete,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color:
            CupertinoColors.systemGrey5.resolveFrom(context).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Text(
                'Start Date',
                style: const TextStyle(
                    fontSize: 16, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(height: 6),
              Text(startDate, style: const TextStyle(fontSize: 16)),
            ],
          ),
          Column(
            children: [
              Text(
                'Finish Date',
                style: const TextStyle(
                    fontSize: 16, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(height: 6),
              Text(finishDate, style: const TextStyle(fontSize: 16)),
            ],
          ),
          Column(
            children: [
              Text(
                'Days to Complete',
                style: const TextStyle(
                    fontSize: 16, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(height: 6),
              Text(daysToComplete, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _popupAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = CupertinoColors.activeBlue,
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
    int fullStars = rating.floor();
    bool hasHalfStar = (rating - fullStars) >= 0.5;

    return Row(
      children: List.generate(5, (index) {
        if (index < fullStars) {
          return const Icon(CupertinoIcons.star_fill,
              color: CupertinoColors.systemYellow);
        } else if (index == fullStars && hasHalfStar) {
          return const Icon(CupertinoIcons.star_lefthalf_fill,
              color: CupertinoColors.systemYellow);
        } else {
          return const Icon(CupertinoIcons.star,
              color: CupertinoColors.systemGrey);
        }
      }),
    );
  }
}
