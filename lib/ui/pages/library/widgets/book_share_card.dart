import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class BookShareCard extends StatefulWidget {
  final String title;
  final String author;
  final double rating;
  final int totalWords;
  final int totalPages;
  final int daysToComplete;
  final double pagesPerMinute;
  final double wordsPerMinute;
  final int totalTime;
  final String? dateRangeString;
  final bool allowCoverUpload;

  const BookShareCard({
    super.key,
    required this.title,
    required this.author,
    required this.rating,
    required this.totalWords,
    required this.totalPages,
    required this.daysToComplete,
    required this.pagesPerMinute,
    required this.wordsPerMinute,
    required this.totalTime,
    required this.dateRangeString,
    required this.allowCoverUpload,
  });

  @override
  State<BookShareCard> createState() => _BookShareCardState();
}

class _BookShareCardState extends State<BookShareCard> {
  File? _coverImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _coverImage = File(picked.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.allowCoverUpload)
              Column(
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _coverImage != null
                            ? Image.file(_coverImage!, width: 140, height: 200, fit: BoxFit.cover)
                            : Container(
                                width: 140,
                                height: 200,
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      FluentIcons.book_add_20_filled,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Add Cover",
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // Title & Author
            Text(widget.title,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('by ${widget.author}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),

            const SizedBox(height: 8),

            // Rating
            Row(
              children: [
                Text(widget.rating.toStringAsFixed(1),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                const SizedBox(width: 4),
                RatingBarIndicator(
                  rating: widget.rating,
                  itemBuilder: (context, index) => const Icon(Icons.star, color: Color(0xFFFBCB04)),
                  itemCount: 5,
                  itemSize: 24,
                ),
              ],
            ),

            const SizedBox(height: 16),

            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StatItem(label: "Read Time", value: _formatTime(widget.totalTime)),
                _StatItem(label: "Days", value: "${widget.daysToComplete}"),
                if (widget.totalPages > 0) _StatItem(label: "Pages", value: "${widget.totalPages}"),
                if (widget.pagesPerMinute > 0)
                  _StatItem(label: "Pages/min", value: widget.pagesPerMinute.toStringAsFixed(1)),
                if (widget.totalWords > 0) _StatItem(label: "Words", value: "${widget.totalWords}"),
                if (widget.wordsPerMinute > 0)
                  _StatItem(label: "Words/min", value: widget.wordsPerMinute.toStringAsFixed(1)),
              ],
            ),

            const SizedBox(height: 16),
            Divider(thickness: 1, color: theme.dividerColor.withAlpha(77)),
            const SizedBox(height: 16),

            // Dates
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.dateRangeString ?? ''),
              ],
            ),

            const SizedBox(height: 16),

            // Logo
            Align(
              alignment: Alignment.bottomLeft,
              child: Row(
                children: [
                  Image.asset(
                    'assets/icon/readstats_white.png',
                    width: 32,
                    height: 32,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 6),
                  Text("ReadStats",
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return hours > 0 ? "${hours}h ${mins}m" : "${mins}m";
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
