import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import '/viewmodels/SettingsViewModel.dart';

class SortFilterOptions {
  final String sortOption;
  final bool isAscending;
  final List<String> bookTypes;
  final bool isFavorite;
  final List<String> finishedYears;
  final List<String> tags;
  final String tagFilterMode;
  final bool isReviewed;

  const SortFilterOptions({
    required this.sortOption,
    required this.isAscending,
    required this.bookTypes,
    required this.isFavorite,
    this.finishedYears = const [],
    this.tags = const [],
    this.tagFilterMode = 'any',
    this.isReviewed = false,
  });

  SortFilterOptions copyWith({
    String? sortOption,
    bool? isAscending,
    List<String>? bookTypes,
    bool? isFavorite,
    List<String>? finishedYears,
    List<String>? tags,
    String? tagFilterMode,
    bool? isReviewed,
  }) {
    return SortFilterOptions(
      sortOption: sortOption ?? this.sortOption,
      isAscending: isAscending ?? this.isAscending,
      bookTypes: bookTypes ?? this.bookTypes,
      isFavorite: isFavorite ?? this.isFavorite,
      finishedYears: finishedYears ?? this.finishedYears,
      tags: tags ?? this.tags,
      tagFilterMode: tagFilterMode ?? this.tagFilterMode,
      isReviewed: isReviewed ?? this.isReviewed,
    );
  }
}

class SortFilterPopup {
  static Future<void> show({
    required BuildContext context,
    required SortFilterOptions currentOptions,
    required Function(SortFilterOptions) onOptionsChange,
    required List<String> availableYears,
    required List<String> availableTags,
    required SettingsViewModel settingsViewModel,
  }) async {
    final result = await showModalBottomSheet<SortFilterOptions>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return _SortFilterView(
          initialOptions: currentOptions,
          availableYears: availableYears,
          availableTags: availableTags,
          settingsViewModel: settingsViewModel,
        );
      },
    );

    if (result != null) {
      onOptionsChange(result);
    }
  }
}

class _SortFilterView extends StatefulWidget {
  final SortFilterOptions initialOptions;
  final List<String> availableYears;
  final List<String> availableTags;
  final SettingsViewModel settingsViewModel;

  const _SortFilterView({
    required this.initialOptions,
    required this.availableYears,
    required this.availableTags,
    required this.settingsViewModel,
  });

  @override
  State<_SortFilterView> createState() => _SortFilterViewState();
}

class _SortFilterViewState extends State<_SortFilterView> {
  late SortFilterOptions currentOptions;
  final List<String> bookTypes = [
    'Paperback',
    'Hardback',
    'eBook',
    'Audiobook',
  ];
  final List<String> sortOptions = [
    'Title',
    'Author',
    'Rating',
    'Pages',
    'Date started',
    'Date finished',
    'Date added',
  ];

  @override
  void initState() {
    super.initState();
    currentOptions = widget.initialOptions;
  }

  void _clearAllFilters() {
    setState(() {
      currentOptions = SortFilterOptions(
        sortOption: currentOptions.sortOption,
        isAscending: currentOptions.isAscending,
        bookTypes: [],
        isFavorite: false,
        finishedYears: [],
        tags: [],
        tagFilterMode: 'any',
        isReviewed: false,
      );
    });
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildSortControls() {
    final theme = Theme.of(context);
    final fieldColor = theme.colorScheme.surfaceContainerHighest;

    // Decide which icon to show based on sort option
    IconData sortIcon;
    if (currentOptions.sortOption == 'Title' ||
        currentOptions.sortOption == 'Author') {
      sortIcon = currentOptions.isAscending
          ? FluentIcons.text_sort_ascending_16_regular
          : FluentIcons.text_sort_descending_16_regular;
    } else {
      sortIcon = currentOptions.isAscending
          ? FluentIcons.arrow_sort_up_lines_20_regular
          : FluentIcons.arrow_sort_down_lines_20_regular;
    }

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: currentOptions.sortOption,
              decoration: InputDecoration(
                filled: true,
                fillColor: fieldColor,
                border: fieldBorder,
                enabledBorder: fieldBorder,
                focusedBorder: fieldBorder,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              items: sortOptions.map((option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    currentOptions = currentOptions.copyWith(
                      sortOption: value,
                    );
                  });
                }
              },
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              dropdownColor: fieldColor,
              menuMaxHeight: 200,
              alignment: AlignmentDirectional.centerStart,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: FilledButton(
              onPressed: () {
                setState(() {
                  currentOptions = currentOptions.copyWith(
                    isAscending: !currentOptions.isAscending,
                  );
                });
              },
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                elevation: 0,
                backgroundColor: fieldColor,
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Icon(sortIcon),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagFilterModeSelector() {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment<String>(value: 'any', label: Text('Any')),
          ButtonSegment<String>(value: 'all', label: Text('All')),
          ButtonSegment<String>(value: 'exclude', label: Text('Exclude')),
        ],
        selected: {currentOptions.tagFilterMode},
        onSelectionChanged: (Set<String> newSelection) {
          setState(() {
            currentOptions = currentOptions.copyWith(
              tagFilterMode: newSelection.first,
            );
          });
        },
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          selectedBackgroundColor: theme.colorScheme.primaryContainer,
          selectedForegroundColor: theme.colorScheme.onPrimaryContainer,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          textStyle: theme.textTheme.bodySmall,
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildFilterChips({
    required List<String> options,
    required List<String> selected,
    required Function(List<String>) onChanged,
  }) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        return FilterChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (value) {
            final newSelection = List<String>.from(selected);
            if (option == 'All') {
              onChanged(value ? ['All'] : []);
            } else {
              if (value) {
                newSelection.add(option);
                newSelection.remove('All');
              } else {
                newSelection.remove(option);
              }
              onChanged(newSelection.isEmpty ? ['All'] : newSelection);
            }
          },
          showCheckmark: false,
          labelStyle: theme.textTheme.bodySmall,
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          selectedColor: theme.colorScheme.primaryContainer,
          elevation: 0,
          pressElevation: 0,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required IconData icon,
    required bool selected,
    Color? selectedIconColor,
    required ValueChanged<bool> onSelected,
  }) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      avatar: Icon(
        icon,
        size: 18,
        color: selected
            ? (selectedIconColor ?? theme.colorScheme.onPrimaryContainer)
            : theme.colorScheme.onSurface.withAlpha(153),
      ),
      labelStyle: theme.textTheme.bodySmall?.copyWith(
        color: selected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface,
      ),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      selectedColor: theme.colorScheme.primaryContainer,
      elevation: 0,
      pressElevation: 0,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelPadding: const EdgeInsets.only(left: 6, right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  int _countActiveFilters() {
    int count = 0;

    if (currentOptions.bookTypes.isNotEmpty) {
      count += 1;
    }

    if (currentOptions.isFavorite) {
      count += 1;
    }

    if (currentOptions.isReviewed) {
      count += 1;
    }

    if (currentOptions.finishedYears.isNotEmpty) {
      count += 1;
    }

    if (currentOptions.tags.isNotEmpty) {
      count += 1;
    }

    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle at the top
            Container(
              height: 24,
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),

            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== SORT SECTION =====
                      Center(
                        child: Text(
                          'Sort',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSortControls(),
                      const SizedBox(height: 24),

                      // ===== FILTERS SECTION =====
                      Center(
                        child: Text(
                          'Filters',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Book Type Filter
                      _buildSectionHeader('Book Type'),
                      _buildFilterChips(
                        options: ['All', ...bookTypes],
                        selected: currentOptions.bookTypes.isEmpty
                            ? ['All']
                            : currentOptions.bookTypes,
                        onChanged: (selected) {
                          setState(() {
                            currentOptions = currentOptions.copyWith(
                              bookTypes: selected.contains('All')
                                  ? []
                                  : selected,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Status Filter
                      _buildSectionHeader('Status'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildStatusChip(
                            label: 'Favorites',
                            icon: Icons.favorite,
                            selected: currentOptions.isFavorite,
                            selectedIconColor: Colors.red,
                            onSelected: (value) {
                              setState(() {
                                currentOptions = currentOptions.copyWith(
                                  isFavorite: value,
                                );
                              });
                            },
                          ),
                          _buildStatusChip(
                            label: 'Reviewed',
                            icon: Icons.rate_review_rounded,
                            selected: currentOptions.isReviewed,
                            onSelected: (value) {
                              setState(() {
                                currentOptions = currentOptions.copyWith(
                                  isReviewed: value,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Year Filter
                      if (widget.availableYears.isNotEmpty) ...[
                        _buildSectionHeader('Finished Year'),
                        _buildFilterChips(
                          options: ['All', ...widget.availableYears],
                          selected: currentOptions.finishedYears.isEmpty
                              ? ['All']
                              : currentOptions.finishedYears,
                          onChanged: (selected) {
                            setState(() {
                              currentOptions = currentOptions.copyWith(
                                finishedYears: selected.contains('All')
                                    ? []
                                    : selected,
                              );
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Tag Filter
                      if (widget.availableTags.isNotEmpty) ...[
                        _buildSectionHeader('Tags'),
                        _buildFilterChips(
                          options: ['All', ...widget.availableTags],
                          selected: currentOptions.tags.isEmpty
                              ? ['All']
                              : currentOptions.tags,
                          onChanged: (selected) {
                            setState(() {
                              currentOptions = currentOptions.copyWith(
                                tags: selected.contains('All') ? [] : selected,
                              );
                            });
                          },
                        ),
                        if (currentOptions.tags.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildTagFilterModeSelector(),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Buttons
            Container(
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: 16 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: () => _clearAllFilters(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: Text(
                        _countActiveFilters() > 0
                            ? 'Reset (${_countActiveFilters()})'
                            : 'Reset',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, currentOptions),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            widget.settingsViewModel.accentColorNotifier.value,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
