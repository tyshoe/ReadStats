import 'package:flutter/cupertino.dart';
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
    // Determine the icon based on the book type
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

    // Convert date strings to formatted dates
    String formatDate(String? date) {
      if (date == null || date.isEmpty) return "N/A";
      try {
        return DateFormat(dateFormatString).format(DateTime.parse(date));
      } catch (e) {
        return "Invalid Date";
      }
    }

    double containerHeight = isCompactView ? 60 : 100; // Adjust height

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: containerHeight,
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      book['title'],
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      bookTypeIcon,
                      color: CupertinoColors.systemGrey2.resolveFrom(context),
                      size: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "by ${book['author']}",
                style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 14,
                ),
              ),

              // Show additional details if not in compact view
              if (!isCompactView) ...[
                const SizedBox(height: 4),
                // Display either star rating or numeric rating based on showStars
                if (showStars)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RatingBarIndicator(
                      rating: book['rating']?.toDouble() ?? 0.0,
                      itemCount: 5,
                      itemSize: 20.0,
                      itemPadding: const EdgeInsets.symmetric(horizontal: 2.0),
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, _) => const Icon(
                        CupertinoIcons.star_fill,
                        color: CupertinoColors.systemYellow,
                      ),
                    ),
                  )
                else
                  Text(
                    "${book['rating']?.toStringAsFixed(1) ?? '0'}",
                    style: TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  "${formatDate(book['date_started'])} - ${formatDate(book['date_finished'])}",
                  style: TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 14,
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
