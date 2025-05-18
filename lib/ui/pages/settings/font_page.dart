import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../viewmodels/SettingsViewModel.dart';
import '../library/widgets/book_row.dart';

class FontSelectionPage extends StatelessWidget {
  final SettingsViewModel settingsViewModel;

  const FontSelectionPage({
    super.key,
    required this.settingsViewModel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Simplified font list with just names
    final List<String> fonts = [
      'Roboto',
      'Open Sans',
      'Lato',
      'Montserrat',
      'Playfair Display',
      'Raleway',
      'Poppins',
      'Merriweather',
    ];

    final String selectedFont = settingsViewModel.selectedFontNotifier.value;

    // Sample book data for the preview
    final sampleBook = {
      'title': 'The Art of War',
      'author': 'Sun Tzu',
      'book_type_id': 1,
      'is_favorite': 1,
      'rating': 4.5,
      'date_started': '2024-08-16',
      'date_finished': '2024-08-24',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Font Style'),
        backgroundColor: colors.surface,
        elevation: 0,
      ),
      backgroundColor: colors.background,
      body: Column(
        children: [
          // Preview section at the top
          Container(
            padding: const EdgeInsets.all(16),
            color: colors.surfaceVariant.withOpacity(0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preview', style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                )),
                const SizedBox(height: 12),
                Theme(
                  data: theme.copyWith(
                    textTheme: GoogleFonts.getTextTheme(selectedFont, theme.textTheme),
                  ),
                  child: BookRow(
                    book: sampleBook,
                    textColor: colors.onSurface,
                    onTap: () {},
                    isCompactView: false,
                    showStars: true,
                    dateFormatString: 'MMM d, yyyy',
                  ),
                ),
              ],
            ),
          ),

          // Font selection list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: fonts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final fontName = fonts[index];
                final isSelected = fontName == selectedFont;

                return _buildFontOption(
                  context: context,
                  fontName: fontName,
                  isSelected: isSelected,
                  onTap: () async {
                    await settingsViewModel.setSelectedFont(fontName);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(context),
        child: const Icon(Icons.check),
      ),
    );
  }

  Widget _buildFontOption({
    required BuildContext context,
    required String fontName,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Material(
      borderRadius: BorderRadius.circular(12),
      color: isSelected
          ? colors.primary.withOpacity(0.1)
          : colors.surfaceVariant.withOpacity(0.5),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: colors.primary, width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              if (isSelected) Icon(
                Icons.check_circle_rounded,
                color: colors.primary,
                size: 20,
              ),
              if (isSelected) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fontName,
                  style: GoogleFonts.getFont(
                    fontName,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? colors.primary : colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}