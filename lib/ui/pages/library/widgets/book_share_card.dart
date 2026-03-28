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
  final bool isTransparent;
  final bool isDark;
  final String? initialCoverPath;

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
    this.isTransparent = false,
    this.isDark = false,
    this.initialCoverPath,
  });

  @override
  State<BookShareCard> createState() => _BookShareCardState();
}

class _BookShareCardState extends State<BookShareCard> {
  File? _coverImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.initialCoverPath != null) {
      _coverImage = File(widget.initialCoverPath!);
    }
  }

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
    // Fixed palette — independent of app theme so screenshots are consistent
    final Color bg;
    final Color textPrimary;
    final Color textSecondary;
    final Color divider;
    final Color cellBg;

    if (widget.isTransparent || widget.isDark) {
      bg = widget.isTransparent ? Colors.transparent : const Color(0xFF121212);
      textPrimary = Colors.white;
      textSecondary = Colors.white.withValues(alpha: 0.6);
      divider = Colors.white.withValues(alpha: 0.15);
      cellBg = widget.isTransparent
          ? Colors.white.withValues(alpha: 0.15)
          : const Color(0xFF2A2A2A);
    } else {
      bg = Colors.white;
      textPrimary = const Color(0xFF1A1A1A);
      textSecondary = const Color(0xFF6B7280);
      divider = const Color(0xFFE5E7EB);
      cellBg = const Color(0xFFF3F4F6);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          if (widget.allowCoverUpload)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _coverImage != null
                        ? Image.file(
                            _coverImage!,
                            width: 100,
                            height: 148,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 100,
                            height: 148,
                            color: cellBg,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(FluentIcons.book_add_20_filled,
                                    size: 32, color: textSecondary),
                                const SizedBox(height: 6),
                                Text('Add Cover',
                                    style: TextStyle(fontSize: 11, color: textSecondary)),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'by ${widget.author}',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      _buildRating(textPrimary),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textPrimary,
                height: 1.2,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'by ${widget.author}',
              style: TextStyle(fontSize: 14, color: textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            _buildRating(textPrimary),
          ],

          const SizedBox(height: 16),
          Divider(height: 1, thickness: 1, color: divider),
          const SizedBox(height: 14),

          // Stats grid
          _buildStatsGrid(textPrimary, textSecondary, cellBg),

          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: divider),
          const SizedBox(height: 12),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.dateRangeString ?? '',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icon/readstats_white.png',
                    width: 18,
                    height: 18,
                    color: textPrimary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'ReadStats',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRating(Color textPrimary) {
    return Row(
      children: [
        Text(
          widget.rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(width: 5),
        RatingBarIndicator(
          rating: widget.rating,
          itemBuilder: (context, _) => const Icon(Icons.star, color: Color(0xFFFBCB04)),
          itemCount: 5,
          itemSize: 18,
          physics: const NeverScrollableScrollPhysics(),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(Color textPrimary, Color textSecondary, Color cellBg) {
    final items = <(String, String)>[
      if (widget.totalTime > 0) ('Read Time', _formatTime(widget.totalTime)),
      if (widget.daysToComplete > 0) ('Days', '${widget.daysToComplete}'),
      if (widget.totalPages > 0) ('Pages', '${widget.totalPages}'),
      if (widget.pagesPerMinute > 0)
        ('Pages/min', widget.pagesPerMinute.toStringAsFixed(1)),
      if (widget.totalWords > 0) ('Words', _formatNumber(widget.totalWords)),
      if (widget.wordsPerMinute > 0)
        ('Words/min', widget.wordsPerMinute.toStringAsFixed(1)),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 8));
      rows.add(Row(
        children: [
          Expanded(
            child: _buildStatCell(items[i].$1, items[i].$2, textPrimary, textSecondary, cellBg),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: i + 1 < items.length
                ? _buildStatCell(
                    items[i + 1].$1, items[i + 1].$2, textPrimary, textSecondary, cellBg)
                : const SizedBox(),
          ),
        ],
      ));
    }
    return Column(children: rows);
  }

  Widget _buildStatCell(
    String label,
    String value,
    Color textPrimary,
    Color textSecondary,
    Color cellBg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cellBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: textSecondary)),
        ],
      ),
    );
  }

  String _formatTime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

/// Checkerboard background used in the share preview to indicate transparency.
/// Place this behind the transparent [BookShareCard] but outside its
/// [RepaintBoundary] so it is never included in the captured image.
class CheckerboardBackground extends StatelessWidget {
  final double squareSize;

  const CheckerboardBackground({super.key, this.squareSize = 14});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CheckerboardPainter(squareSize: squareSize),
      child: const SizedBox.expand(),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  final double squareSize;

  _CheckerboardPainter({required this.squareSize});

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = const Color(0xFF888888);
    final dark = Paint()..color = const Color(0xFF606060);

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final isEven =
            ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, squareSize, squareSize),
          isEven ? light : dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
