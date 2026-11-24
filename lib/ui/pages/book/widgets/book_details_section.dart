import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/data/models/book_type.dart';
import 'package:read_stats/data/services/analytics_service.dart';
import 'package:read_stats/data/services/book_search_service.dart';
import 'package:read_stats/data/utils/money.dart';
import 'package:read_stats/ui/pages/book/widgets/detail_section.dart';
import 'package:read_stats/ui/settings_view_model.dart';
import 'package:read_stats/ui/widgets/book_type.dart';
import 'package:url_launcher/url_launcher.dart';

/// The facts about the copy, two to a row.
class BookDetailsSection extends StatelessWidget {
  final Map<String, dynamic> book;
  final SettingsViewModel settingsViewModel;

  /// "320 pages" or "9h 5m", if known.
  final String? length;
  final VoidCallback onEdit;

  const BookDetailsSection({
    super.key,
    required this.book,
    required this.settingsViewModel,
    required this.length,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final f = DateFormat(settingsViewModel.defaultDateFormatNotifier.value);
    final isAudio = book['book_type_id'] == BookType.audiobook;
    final (_, type) = bookTypeDetails(book['book_type_id'] as int?);
    final words = (book['word_count'] as int?) ?? 0;
    final added = DetailFormat.parse(book['date_added']);
    final narrator = isAudio ? (book['narrator'] as String? ?? '').trim() : '';
    final isbn = (book['isbn'] as String? ?? '').trim();
    // The edition's, kept when one was picked; either may be missing.
    final publisher = (book['edition_publisher'] as String? ?? '').trim();
    final year = book['edition_year'] as int?;

    String? paid;
    if (settingsViewModel.spendingEnabledNotifier.value) {
      final price = (book['price_paid'] as num?)?.toDouble();
      if (price != null) {
        final bought = DetailFormat.parse(book['date_purchased']);
        paid = [
          Money.format(price, settingsViewModel.currencyNotifier.value),
          if (bought != null) DateFormat.yMMMd().format(bought),
        ].join(' · ');
      }
    }

    final cells = <(String, String)>[
      ('Format', type),
      if (length case final l?) (isAudio ? 'Length' : 'Pages', l),
      if (!isAudio && words > 0) ('Words', DetailFormat.number(words)),
      if (narrator.isNotEmpty) ('Narrator', narrator),
      if (isbn.isNotEmpty) ('ISBN', isbn),
      if (publisher.isNotEmpty) ('Publisher', publisher),
      if (year != null) ('Published', '$year'),
      if (added != null) ('Added', f.format(added)),
      if (paid != null) ('Paid', paid),
    ];
    final label = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );
    final value = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    // Shown for a book with keys from Open Library; opens the edition where
    // it's known (see _openOnline).
    final workId = RegExp(
      r'OL\d+W',
    ).firstMatch(book['open_library_key'] as String? ?? '')?.group(0);
    final editionId = RegExp(
      r'OL\d+M',
    ).firstMatch(book['open_library_edition_key'] as String? ?? '')?.group(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailHeading('Details', trailing: 'Edit', onTrailing: onEdit),
        DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var r = 0; r < cells.length; r += 2) ...[
                if (r > 0) const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = r; i < r + 2; i++)
                      Expanded(
                        child: i < cells.length
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cells[i].$1, style: label),
                                  const SizedBox(height: 1),
                                  Text(
                                    cells[i].$2,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: value,
                                  ),
                                ],
                              )
                            : const SizedBox(),
                      ),
                  ],
                ),
              ],
              if (workId != null || editionId != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => _openOnline(editionId, workId, isbn),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('View on Open Library'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Opens the reader's own edition: the one saved with the book, else (for
  /// a book saved before editions were kept) the one with its ISBN — or the
  /// work, with all its editions, when neither is known on Open Library.
  static Future<void> _openOnline(
    String? editionId,
    String? workId,
    String isbn,
  ) async {
    AnalyticsService.instance.openLibraryOpened();
    if (editionId != null) {
      await launchUrl(
        Uri.https('openlibrary.org', '/books/$editionId'),
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    var path = '/works/$workId';
    if (isbn.isNotEmpty) {
      try {
        final found = await BookSearchService.editionByIsbn(isbn);
        if (found != null) path = found.edition.key;
      } on BookSearchException {
        // The work page still helps.
      }
    }
    await launchUrl(
      Uri.https('openlibrary.org', path),
      mode: LaunchMode.externalApplication,
    );
  }
}
