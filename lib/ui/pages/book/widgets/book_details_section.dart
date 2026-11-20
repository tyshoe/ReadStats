import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/data/models/book_type.dart';
import 'package:read_stats/data/utils/money.dart';
import 'package:read_stats/ui/pages/book/widgets/detail_section.dart';
import 'package:read_stats/ui/settings_view_model.dart';
import 'package:read_stats/ui/widgets/book_type.dart';

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
      if (added != null) ('Added', f.format(added)),
      if (paid != null) ('Paid', paid),
    ];
    final label = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );
    final value = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

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
            ],
          ),
        ),
      ],
    );
  }
}
