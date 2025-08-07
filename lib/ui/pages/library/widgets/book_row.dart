import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';

class BookRow extends StatelessWidget {
  final Map<String, dynamic> book;
  final Color textColor;
  final VoidCallback onTap;
  final bool isCompactView;
  final bool showStars;
  final String dateFormatString;

  const BookRow({
    super.key,
    required this.book,
    required this.textColor,
    required this.onTap,
    required this.isCompactView,
    required this.showStars,
    required this.dateFormatString,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine the icon based on the book type
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

    // Helper function to format date
    String formatDate(String? date) {
      if (date == null || date.isEmpty) return "N/A";
      try {
        return DateFormat(dateFormatString).format(DateTime.parse(date));
      } catch (e) {
        return "Invalid Date";
      }
    }

    // Helper function to calculate days to complete
    String calculateDaysToComplete(String? startDate, String? finishDate) {
      if (startDate != null && finishDate != null) {
        DateTime startDateTime = DateTime.parse(startDate);
        DateTime finishDateTime = DateTime.parse(finishDate);
        int days = finishDateTime.difference(startDateTime).inDays;
        int adjustedDays = days == 0 ? 1 : days;
        return "($adjustedDays ${adjustedDays == 1 ? 'day' : 'days'})";
      }
      return "";
    }

    // Get start and finish dates
    String? startDate = book['date_started'];
    String? finishDate = book['date_finished'];

    String daysToCompleteString = calculateDaysToComplete(startDate, finishDate);

    String dateRangeString = "";
    if (startDate != null && finishDate != null) {
      dateRangeString = "${formatDate(startDate)} - ${formatDate(finishDate)} $daysToCompleteString";
    } else if (startDate != null) {
      dateRangeString = "Started ${formatDate(startDate)}";
    } else if (finishDate != null) {
      dateRangeString = "Finished ${formatDate(finishDate)}";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min, // This allows vertical expansion
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      book['title'],
                      style: theme.textTheme.bodyLarge,
                      maxLines: isCompactView ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (book["is_favorite"] == 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 16,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      bookTypeIcon,
                      color: theme.iconTheme.color?.withOpacity(0.6),
                      size: 16,
                    ),
                  ),
                ],
              ),

              // Author
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "by ${book['author']}",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Expanded details section (only for non-compact view)
              if (!isCompactView) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rating
                      if (showStars)
                        RatingBarIndicator(
                          rating: book['rating']?.toDouble() ?? 0.0,
                          itemCount: 5,
                          itemSize: 20,
                          itemBuilder: (context, _) => const Icon(
                            Icons.star,
                            color: Color(0xFFFBCB04),
                          ),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              book['rating'] != null ? book['rating'].toStringAsFixed(1) : '-',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.star, size: 16, color: Color(0xFFFBCB04),),
                          ],
                        ),

                      // Date range
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          dateRangeString,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}