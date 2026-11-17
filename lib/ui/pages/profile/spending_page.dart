import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/data/models/spending_summary.dart';
import '/data/utils/money.dart';
import '/ui/widgets/book_cover.dart';
import '/ui/widgets/book_type.dart';
import '/viewmodels/settings_view_model.dart';

/// What the reader's books have cost: the total, how it built up, and where
/// it went — by year, by format, and into books read or still waiting.
///
/// Only for readers who turned spending on in Settings. Everything here is
/// worked out from the price on each book, which is entered on its own form;
/// nothing is stored for this page.
class SpendingPage extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> sessions;
  final SettingsViewModel settingsViewModel;

  const SpendingPage({
    super.key,
    required this.books,
    required this.sessions,
    required this.settingsViewModel,
  });

  @override
  State<SpendingPage> createState() => _SpendingPageState();
}

class _SpendingPageState extends State<SpendingPage> {
  /// How many books the list shows before "Show all".
  static const _preview = 5;

  late final SpendingSummary _summary =
      SpendingSummary.from(widget.books, widget.sessions);
  bool _showAll = false;

  String get _currency => widget.settingsViewModel.currencyNotifier.value;

  String _books(int n) => '$n ${n == 1 ? 'book' : 'books'}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.settingsViewModel.accentColorNotifier.value;
    final s = _summary;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Spending')),
      body: s.isEmpty
          ? _buildEmpty(theme)
          : ListView(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
              children: [
                _buildTotals(theme, s),
                if (s.timeline.length > 1) ...[
                  const SizedBox(height: 12),
                  _buildChart(theme, accent, s),
                ],
                if (s.byStatus.length > 1) ...[
                  const SizedBox(height: 20),
                  _heading(theme, 'Read and unread'),
                  const SizedBox(height: 12),
                  _groupCard(theme, accent, [
                    for (final g in s.byStatus)
                      (null, g.key.label, g.books, g.spent),
                  ]),
                ],
                if (s.byYear.length > 1) ...[
                  const SizedBox(height: 20),
                  _heading(theme, 'By year'),
                  const SizedBox(height: 12),
                  _groupCard(theme, accent, [
                    for (final g in s.byYear)
                      (null, '${g.key}', g.books, g.spent),
                  ]),
                ],
                if (s.byFormat.length > 1) ...[
                  const SizedBox(height: 20),
                  _heading(theme, 'By format'),
                  const SizedBox(height: 12),
                  _groupCard(theme, accent, [
                    for (final g in s.byFormat)
                      () {
                        final (icon, name) = bookTypeDetails(g.key);
                        return (icon, name, g.books, g.spent);
                      }(),
                  ]),
                ],
                const SizedBox(height: 20),
                _buildMostExpensive(theme, accent, s),
                if (s.unpriced > 0) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${_books(s.unpriced)} '
                    '${s.unpriced == 1 ? 'has' : 'have'} no price and '
                    '${s.unpriced == 1 ? "isn't" : "aren't"} counted. '
                    'Add one from the book\'s edit page.',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _heading(ThemeData theme, String text) => Text(
        text,
        style:
            theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      );

  Widget _card({required Widget child, EdgeInsets? padding}) => Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      );

  Widget _buildEmpty(ThemeData theme) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payments, size: 40, color: muted),
            const SizedBox(height: 16),
            Text(
              'No prices yet',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Edit a book and enter what you paid for it, and your '
              'spending starts adding up here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }

  // ── Totals ─────────────────────────────────────────────────────────────────

  Widget _buildTotals(ThemeData theme, SpendingSummary s) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final perHour = s.perHour;

    Widget stat(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total spent',
              style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.format(s.spent, _currency),
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'on ${_books(s.books.length)}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stat('Per book', Money.format(s.perBook, _currency)),
              const SizedBox(width: 12),
              stat(
                'Per hour read',
                perHour == null ? '—' : Money.format(perHour, _currency),
              ),
            ],
          ),
          if (s.boughtThisYear > 0) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This year: ${Money.format(s.spentThisYear, _currency)} '
                    'on ${_books(s.boughtThisYear)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Over time ──────────────────────────────────────────────────────────────

  Widget _buildChart(ThemeData theme, Color accent, SpendingSummary s) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final points = s.timeline;
    final start = points.first.date;
    double x(SpendingPoint p) => p.date.difference(start).inDays.toDouble();

    final line = LineChartBarData(
      spots: [for (final p in points) FlSpot(x(p), p.spent)],
      color: accent,
      barWidth: 2.5,
      isCurved: false,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withAlpha(70), accent.withAlpha(0)],
        ),
      ),
    );

    return _card(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending over time',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: x(points.last),
                minY: 0,
                maxY: s.spent <= 0 ? 1 : s.spent * 1.12,
                lineBarsData: [line],
                titlesData: const FlTitlesData(show: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  // Anywhere along the chart finds the nearest day.
                  touchSpotThreshold: double.infinity,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (spots) => [
                      for (final spot in spots)
                        LineTooltipItem(
                          '${Money.format(spot.y, _currency, whole: true)}\n',
                          TextStyle(
                            color: theme.colorScheme.onInverseSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          children: [
                            TextSpan(
                              text: DateFormat('MMM d, y').format(
                                  start.add(Duration(days: spot.x.round()))),
                              style: TextStyle(
                                color: theme.colorScheme.onInverseSurface
                                    .withAlpha(180),
                                fontWeight: FontWeight.normal,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(DateFormat('MMM y').format(start),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              const Spacer(),
              Text('Today',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Breakdowns ─────────────────────────────────────────────────────────────

  /// Rows of (icon, name, books, spent), each with a bar measured against
  /// the largest.
  Widget _groupCard(
    ThemeData theme,
    Color accent,
    List<(IconData?, String, int, double)> rows,
  ) {
    final muted = theme.colorScheme.onSurfaceVariant;
    var most = 0.0;
    for (final r in rows) {
      if (r.$4 > most) most = r.$4;
    }

    return _card(
      child: Column(
        children: [
          for (final (i, (icon, name, books, spent)) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: 14),
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: muted),
                  const SizedBox(width: 8),
                ],
                Text(name, style: theme.textTheme.bodyMedium),
                const SizedBox(width: 8),
                Text(
                  _books(books),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                const Spacer(),
                Text(
                  Money.format(spent, _currency),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: most <= 0 ? 0 : spent / most,
                minHeight: 5,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Books ──────────────────────────────────────────────────────────────────

  Widget _buildMostExpensive(
      ThemeData theme, Color accent, SpendingSummary s) {
    final shown = _showAll ? s.books : s.books.take(_preview).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _heading(theme, _showAll ? 'All books' : 'Most expensive'),
            const Spacer(),
            if (s.books.length > _preview)
              GestureDetector(
                onTap: () => setState(() => _showAll = !_showAll),
                behavior: HitTestBehavior.opaque,
                child: Text(
                  _showAll ? 'Show less' : 'Show all',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              for (final (i, b) in shown.indexed) ...[
                if (i > 0)
                  Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant.withAlpha(90)),
                _bookRow(theme, b),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _bookRow(ThemeData theme, PricedBook b) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final (_, format) = bookTypeDetails(b.bookTypeId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: b.coverPath != null
                ? BookCover(
                    path: b.coverPath!,
                    shape: b.coverShape,
                    width: 34,
                    borderRadius: 4,
                  )
                : Container(
                    height: 51,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.menu_book, size: 16, color: muted),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${b.author} · $format',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            Money.format(b.paid, _currency),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
