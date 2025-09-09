import 'package:flutter/material.dart';

class YearFilterWidget extends StatelessWidget {
  final List<int> years;
  final int selectedYear;
  final Function(int) onYearSelected;

  const YearFilterWidget({
    super.key,
    required this.years,
    required this.selectedYear,
    required this.onYearSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: years.length + 1,
        itemBuilder: (context, index) {
          final year = index == 0 ? 0 : years[index - 1];
          final isSelected = selectedYear == year;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: isSelected ? colors.primary : colors.onSurface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onPressed: () => onYearSelected(year),
              child: Container(
                decoration: BoxDecoration(
                  border: isSelected
                      ? Border(
                    bottom: BorderSide(
                      color: colors.primary,
                      width: 2,
                    ),
                  )
                      : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  year == 0 ? 'All' : year.toString(),
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
