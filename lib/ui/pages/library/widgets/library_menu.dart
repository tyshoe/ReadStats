import 'package:flutter/material.dart';

/// What the library's overflow menu can do.
enum LibraryMenuAction { random, shareText, findSeries, viewRows, viewGrid }

/// The library's overflow menu: random book, share, find series, and the
/// rows/grid switch with the current view ticked. Grouping series lives in
/// the Sort & Filter sheet, beside the sort.
class LibraryMenu extends StatelessWidget {
  /// 'rows' or 'grid'.
  final String view;
  final ValueChanged<LibraryMenuAction> onSelected;

  const LibraryMenu({super.key, required this.view, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final check = Icon(
      Icons.check,
      size: 18,
      color: Theme.of(context).colorScheme.primary,
    );
    return PopupMenuButton<LibraryMenuAction>(
      icon: const Icon(Icons.more_vert),
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: LibraryMenuAction.random,
          child: Text('Random Book'),
        ),
        const PopupMenuItem(
          value: LibraryMenuAction.shareText,
          child: Text('Share as text'),
        ),
        const PopupMenuItem(
          value: LibraryMenuAction.findSeries,
          child: Text('Find series in titles'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: LibraryMenuAction.viewRows,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.view_agenda_outlined, size: 20),
            title: const Text('Rows'),
            trailing: view == 'rows' ? check : null,
          ),
        ),
        PopupMenuItem(
          value: LibraryMenuAction.viewGrid,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.grid_view, size: 20),
            title: const Text('Grid'),
            trailing: view == 'grid' ? check : null,
          ),
        ),
      ],
    );
  }
}
