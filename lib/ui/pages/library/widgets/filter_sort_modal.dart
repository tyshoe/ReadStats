import 'package:flutter/material.dart';
import '/viewmodels/SettingsViewModel.dart';

class SortFilterOptions {
  final String sortOption;
  final bool isAscending;
  final List<String> bookTypes;
  final bool isFavorite;
  final List<String> finishedYears;
  final List<String> tags;

  const SortFilterOptions({
    required this.sortOption,
    required this.isAscending,
    required this.bookTypes,
    required this.isFavorite,
    this.finishedYears = const [],
    this.tags = const [],
  });

  SortFilterOptions copyWith({
    String? sortOption,
    bool? isAscending,
    List<String>? bookTypes,
    bool? isFavorite,
    List<String>? finishedYears,
    List<String>? tags,
  }) {
    return SortFilterOptions(
      sortOption: sortOption ?? this.sortOption,
      isAscending: isAscending ?? this.isAscending,
      bookTypes: bookTypes ?? this.bookTypes,
      isFavorite: isFavorite ?? this.isFavorite,
      finishedYears: finishedYears ?? this.finishedYears,
      tags: tags ?? this.tags,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Filter & Sort'),
              centerTitle: false,
              automaticallyImplyLeading: false,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sort Section
                      _buildSectionHeader('Sort By'),
                      _buildSortControls(),
                      const Divider(height: 32),

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
                              bookTypes: selected.contains('All') ? [] : selected,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Favorite Filter
                      FilterChip(
                        label: Text(
                          currentOptions.isFavorite ? 'Favorites Only' : 'All Books',
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
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                        labelPadding: const EdgeInsets.only(left: 4, right: 8),
                        showCheckmark: false,
                      ),
                      const Divider(height: 32),

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
                        const Divider(height: 32),
                      ],

                      // Tag Filter
                      if (widget.availableTags.isNotEmpty) ...[
                        _buildSectionHeader('Tags'),
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
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () => Navigator.pop(context, currentOptions),
                child: const Text('Apply Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
                borderSide: BorderSide(color: borderColor, width: 1.5),
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
                currentOptions.isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected
                  ? Colors.transparent
                  : Theme.of(context).colorScheme.outline,
              width: 1,
            ),
          ),
          selectedColor: Theme.of(context).colorScheme.primaryContainer,
          labelStyle: Theme.of(context).textTheme.bodyMedium,
        );
      }).toList(),
    );
  }


}