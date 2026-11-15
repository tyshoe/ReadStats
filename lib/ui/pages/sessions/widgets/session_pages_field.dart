import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The pages a session covered, as the session form and the post-timer page
/// edit them.
///
/// Recorded as the page the reader started on and the page they stopped on.
/// The start page is read and the stop page isn't — 400 to 422 is pages 400
/// through 421, 22 of them — so the page one session stops on is the page
/// the next one starts on.
///
/// The only exception is the end of the book: the stop page is then the last
/// one, and that page was read. Whether a session ends the book is settled
/// against the book's length rather than its page numbers, which needn't run
/// from 1 to the page count — see [countsLastPage]. Which shelf the book is
/// on plays no part.
///
/// A bare page count stays available for sittings logged from memory, and is
/// what sessions from before page numbers hold.
class SessionPages {
  final from = TextEditingController();
  final to = TextEditingController();
  final count = TextEditingController();

  /// Start and stop pages, or a bare count.
  bool byRange = true;

  /// The book's length, when it has one: how many pages there are to read,
  /// not the number printed on the last one. A book whose first chapter
  /// opens on page 7 ends on page 206 of its 200.
  int? bookPageCount;

  /// Pages logged for the book in sessions before this one.
  int pagesBefore = 0;

  /// Pages logged for the book in sessions after this one — only when a
  /// session is being added or edited behind later ones.
  int pagesAfter = 0;

  /// Whether no session for the book comes after this one.
  bool isLastSession = true;


  /// True once [from] holds something the reader typed, which a later
  /// [suggestStart] must not overwrite.
  bool _fromTouched = false;

  /// Whether the suggested start came from a stored page, or was added up
  /// from page counts — see [suggestStart].
  bool? startIsExact;

  /// Loads a saved session for editing.
  void load({int? startPage, int? endPage, int? pagesRead}) {
    if (startPage != null && endPage != null) {
      byRange = true;
      from.text = startPage.toString();
      to.text = endPage.toString();
      _fromTouched = true;
    } else {
      byRange = pagesRead == null;
      count.text = pagesRead?.toString() ?? '';
    }
  }

  /// Offers [page] as where this session starts, unless the reader already
  /// typed their own. [exact] is false when it was estimated.
  void suggestStart(int page, {required bool exact}) {
    if (_fromTouched) return;
    from.text = page.toString();
    startIsExact = exact;
  }

  /// Forgets everything typed, for a form that moves to another book.
  void clear() {
    from.clear();
    to.clear();
    count.clear();
    _fromTouched = false;
    startIsExact = null;
  }

  void markStartTyped() {
    _fromTouched = true;
    startIsExact = null;
  }

  int? get _from => int.tryParse(from.text);
  int? get _to => int.tryParse(to.text);

  /// True when both pages are in and the stop page is before the start.
  bool get isBackwards =>
      byRange && _from != null && _to != null && _to! < _from!;

  /// The pages to store, or null where they are missing or don't make sense.
  int? get startPage => byRange && _to != null && !isBackwards ? _from : null;
  int? get endPage => byRange && _from != null && !isBackwards ? _to : null;

  int? get _gap {
    final start = startPage, end = endPage;
    return start == null || end == null ? null : end - start;
  }

  /// Whether this session reads the book to its end: with the pages logged
  /// before it, it covers the book's length, give or take the stop page
  /// itself. The page number alone can't say — see [bookPageCount].
  bool get reachesEnd {
    final gap = _gap;
    final total = bookPageCount ?? 0;
    return byRange &&
        isLastSession &&
        gap != null &&
        total > 0 &&
        pagesBefore + gap >= total - 1;
  }

  /// Whether the stop page itself counts as read: only at the end of the
  /// book. A reader who stops on the book's last page read it, so there the
  /// stop page is "through" where everywhere else it is "to". In a book whose
  /// last page is 211, stopping on 211 brings it to its full length, and 212
  /// is a page past the end — see [passesEnd].
  bool get countsLastPage => reachesEnd;

  /// Pages read: from the start page up to the stop page — through it at the
  /// end of the book — or the count that was typed.
  int? get pagesRead {
    if (!byRange) return int.tryParse(count.text);
    final gap = _gap;
    return gap == null ? null : gap + (countsLastPage ? 1 : 0);
  }

  /// Whether the pages logged for the book would come to more than it has:
  /// the stop page is past the book's last.
  bool get passesEnd {
    final read = pagesRead;
    final total = bookPageCount ?? 0;
    return byRange && read != null && total > 0 && pagesBefore + read > total;
  }

  void dispose() {
    from.dispose();
    to.dispose();
    count.dispose();
  }
}

/// The start-and-stop page fields, with the count they work out to underneath
/// and a switch to typing a bare count instead. For a book with a page count,
/// a bar below places the session in the book: what was read before it, what
/// this session adds, and what is left.
class SessionPagesField extends StatelessWidget {
  final SessionPages pages;

  /// Called after anything changes, so the page can rebuild and react.
  final VoidCallback onChanged;

  const SessionPagesField({
    super.key,
    required this.pages,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pages.byRange)
          Row(
            children: [
              Expanded(
                child: _field(
                  theme,
                  pages.from,
                  'From page',
                  onChanged: () {
                    pages.markStartTyped();
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward,
                color: theme.colorScheme.onSurface.withAlpha(100),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(theme, pages.to, 'To page', onChanged: onChanged),
              ),
            ],
          )
        else
          _field(theme, pages.count, 'Pages read', onChanged: onChanged),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: _buildNote(theme)),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () {
                pages.byRange = !pages.byRange;
                onChanged();
              },
              child: Text(
                pages.byRange ? 'Enter a page count' : 'Use start and end pages',
              ),
            ),
          ],
        ),
        if ((pages.bookPageCount ?? 0) > 0) ...[
          const SizedBox(height: 8),
          _buildProgress(theme),
        ],
      ],
    );
  }

  /// The book as one bar: read before this session, this session, and left.
  ///
  /// Pages from sessions after this one sit with "read before" in the figures
  /// and after the session on the bar, so the session keeps its place in the
  /// book when an earlier one is being edited.
  Widget _buildProgress(ThemeData theme) {
    final total = pages.bookPageCount!;
    final color = theme.primaryColor;
    final track = theme.colorScheme.surfaceContainerHighest;
    final earlier = color.withValues(alpha: 0.4);

    final before = pages.pagesBefore;
    final after = pages.pagesAfter;
    final session = pages.pagesRead ?? 0;
    final left = (total - before - session - after).clamp(0, total);

    // Flex needs whole numbers; a logged session keeps at least a sliver.
    int flex(int value) => value <= 0 ? 0 : value;
    final segments = <(int, Color)>[
      (flex(before), earlier),
      (flex(session), color),
      (flex(after), earlier),
      (flex(left), track),
    ].where((s) => s.$1 > 0).toList();

    final shares = _wholeShares([before + after, session, left]);

    Widget figure(String label, int value, int share, Color dot,
        {bool strong = false}) {
      final muted = theme.colorScheme.onSurfaceVariant;
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '$value ${value == 1 ? 'page' : 'pages'} · $share%',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: strong ? theme.colorScheme.onSurface : muted,
                fontWeight: strong ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      );
    }

    return Semantics(
      label: '${before + after} of $total pages read before this session, '
          '$session in this session, $left left',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Container(
                height: 10,
                color: track,
                child: Row(
                  children: [
                    for (final (size, fill) in segments)
                      Expanded(flex: size, child: Container(color: fill)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                figure('Read before', before + after, shares[0], earlier),
                const SizedBox(width: 8),
                figure('This session', session, shares[1], color,
                    strong: true),
                const SizedBox(width: 8),
                figure('Left', left, shares[2],
                    theme.colorScheme.outlineVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// [values] as whole percentages of their sum that always add up to 100.
  ///
  /// Rounding each one on its own can leave 99 or 101 — three thirds come to
  /// 33 + 33 + 33. Each is rounded down instead, and the points left over go
  /// to the values that lost the most in the rounding.
  static List<int> _wholeShares(List<int> values) {
    final sum = values.fold<int>(0, (a, b) => a + b);
    if (sum <= 0) return List.filled(values.length, 0);
    final shares = [for (final v in values) v * 100 ~/ sum];
    final remainders = [for (final v in values) v * 100 % sum];
    var spare = 100 - shares.fold<int>(0, (a, b) => a + b);
    final order = List.generate(values.length, (i) => i)
      ..sort((a, b) => remainders[b].compareTo(remainders[a]));
    for (final i in order) {
      if (spare-- <= 0) break;
      shares[i]++;
    }
    return shares;
  }

  /// What the fields add up to, or what's wrong with them.
  Widget _buildNote(ThemeData theme) {
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (!pages.byRange) return const SizedBox.shrink();

    if (pages.isBackwards) {
      return Text(
        'The end page is before the start',
        style: muted?.copyWith(color: theme.colorScheme.error),
      );
    }

    final read = pages.pagesRead;
    final total = pages.bookPageCount ?? 0;
    final end = pages.endPage;
    if (read != null) {
      final count = '$read ${read == 1 ? 'page' : 'pages'}';
      if (pages.passesEnd) {
        final over = pages.pagesBefore + read - total;
        return Text(
          '$count · $over past the end of the book\'s $total',
          style: muted?.copyWith(color: theme.colorScheme.error),
        );
      }
      if (pages.countsLastPage) {
        return Text('$count · through page $end', style: muted);
      }
      return Text(count, style: muted);
    }

    // Nothing to add up yet: say where the start page came from.
    if (pages.from.text.isNotEmpty && pages.startIsExact != null) {
      return Text(
        pages.from.text == '1'
            ? 'Starting from the beginning'
            : pages.startIsExact!
                ? 'Where you left off'
                : 'Estimated from earlier sessions',
        style: muted,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _field(
    ThemeData theme,
    TextEditingController controller,
    String label, {
    required VoidCallback onChanged,
  }) {
    // Underline, like the form's other filled fields: an outline border
    // floats the label up onto the field's top edge.
    UnderlineInputBorder border() => UnderlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        );
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => onChanged(),
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        border: border(),
        enabledBorder: border(),
        focusedBorder: border(),
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      ),
    );
  }
}
