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

  const SortFilterOptions({
    required this.sortOption,
    required this.isAscending,
    required this.bookTypes,
    required this.isFavorite,
    this.finishedYears = const [],
    this.tags = const [],
    this.tagFilterMode = 'any',
  });

  SortFilterOptions copyWith({
    String? sortOption,
    bool? isAscending,
    List<String>? bookTypes,
    bool? isFavorite,
    List<String>? finishedYears,
    List<String>? tags,
    String? tagFilterMode,
  }) {
    return SortFilterOptions(
      sortOption: sortOption ?? this.sortOption,
      isAscending: isAscending ?? this.isAscending,
      bookTypes: bookTypes ?? this.bookTypes,
      isFavorite: isFavorite ?? this.isFavorite,
      finishedYears: finishedYears ?? this.finishedYears,
      tags: tags ?? this.tags,
      tagFilterMode: tagFilterMode ?? this.tagFilterMode,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
  final List<String> bookTypes = ['Paperback', 'Hardback', 'eBook', 'Audiobook'];
  final List<String> sortOptions = [
    'Title',
    'Author',
    'Rating',
    'Pages',
    'Date started',
    'Date finished',
    'Date added'
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
      );
    });
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0, top: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildSortControls() {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outline;

    // Decide which icon to show based on sort option
    IconData sortIcon;
    if (currentOptions.sortOption == 'Title' || currentOptions.sortOption == 'Author') {
      sortIcon = currentOptions.isAscending
          ? FluentIcons.text_sort_ascending_16_regular
          : FluentIcons.text_sort_descending_16_regular;
    } else {
      sortIcon = currentOptions.isAscending
          ? FluentIcons.arrow_sort_up_lines_20_regular
          : FluentIcons.arrow_sort_down_lines_20_regular;
    }

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: currentOptions.sortOption,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
                  currentOptions = currentOptions.copyWith(sortOption: value);
                });
              }
            },
            isExpanded: true,
            dropdownColor: theme.colorScheme.secondaryContainer,
            menuMaxHeight: 200,
            alignment: AlignmentDirectional.centerStart,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          height: 48,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                currentOptions = currentOptions.copyWith(
                  isAscending: !currentOptions.isAscending,
                );
              });
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                sortIcon,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(204),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagFilterModeSelector() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment<String>(
                    value: 'any',
                    label: Text('Match Any'),
                  ),
                  ButtonSegment<String>(
                    value: 'all',
                    label: Text('Match All'),
                  ),
                  ButtonSegment<String>(
                    value: 'exclude',
                    label: Text('Exclude'),
                  ),
                ],
                selected: {currentOptions.tagFilterMode},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    currentOptions = currentOptions.copyWith(
                      tagFilterMode: newSelection.first,
                    );
                  });
                },
                style: SegmentedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: theme.colorScheme.onSurface,
                  selectedBackgroundColor: theme.colorScheme.primaryContainer,
                  selectedForegroundColor: theme.colorScheme.onPrimaryContainer,
                  side: BorderSide(
                    color: theme.colorScheme.outline,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                showSelectedIcon: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFilterChips({
    required List<String> options,
    required List<String> selected,
    required Function(List<String>) onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 0,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? Colors.transparent : Theme.of(context).colorScheme.outline,
              width: 1,
            ),
          ),
          selectedColor: Theme.of(context).colorScheme.primaryContainer,
          labelStyle: Theme.of(context).textTheme.bodyMedium,
        );
      }).toList(),
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
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
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSortControls(),
                      const SizedBox(height: 32),

                      // ===== FILTERS SECTION =====
                      Center(
                        child: Text(
                          'Filters',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Book Type Filter
                      _buildSectionHeader('Book Type'),
                      _buildFilterChips(
                        options: ['All', ...bookTypes],
                        selected:
                            currentOptions.bookTypes.isEmpty ? ['All'] : currentOptions.bookTypes,
                        onChanged: (selected) {
                          setState(() {
                            currentOptions = currentOptions.copyWith(
                              bookTypes: selected.contains('All') ? [] : selected,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Favorites Filter
                      _buildSectionHeader('Favorites'),
                      FilterChip(
                        label: Text(
                          'Favorites',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: currentOptions.isFavorite
                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        selected: currentOptions.isFavorite,
                        onSelected: (value) {
                          setState(() {
                            currentOptions = currentOptions.copyWith(isFavorite: value);
                          });
                        },
                        avatar: Icon(
                          Icons.favorite,
                          color: currentOptions.isFavorite
                              ? Colors.red
                              : Theme.of(context).colorScheme.onSurface.withAlpha(153),
                          size: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: currentOptions.isFavorite
                                ? Colors.transparent
                                : Theme.of(context).colorScheme.outline,
                            width: 1,
                          ),
                        ),
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        labelPadding: const EdgeInsets.only(right: 8),
                        showCheckmark: false,
                      ),
                      const SizedBox(height: 20),

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
                                finishedYears: selected.contains('All') ? [] : selected,
                              );
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Tag Filter
                      if (widget.availableTags.isNotEmpty) ...[
                        _buildSectionHeader('Tags'),
                        _buildTagFilterModeSelector(),
                        _buildFilterChips(
                          options: ['All', ...widget.availableTags],
                          selected: currentOptions.tags.isEmpty ? ['All'] : currentOptions.tags,
                          onChanged: (selected) {
                            setState(() {
                              currentOptions = currentOptions.copyWith(
                                tags: selected.contains('All') ? [] : selected,
                              );
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Buttons
            Container(
              padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: Theme.of(context).colorScheme.outline),
                      ),
                      child: _countActiveFilters() > 0
                          ? Text('Reset Filters (${_countActiveFilters()})')
                          : const Text('Reset Filters'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, currentOptions),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
