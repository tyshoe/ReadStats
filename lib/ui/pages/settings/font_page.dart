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

  static const List<String> _fonts = [
    'Roboto',
    'Inter',
    'Poppins',
    'Montserrat',
    'Raleway',
    'Playfair Display',
    'Merriweather',
    'Lora',
    'EB Garamond',
  ];

  static const _sampleBook = {
    'title': 'The Art of War',
    'author': 'Sun Tzu',
    'book_type_id': 1,
    'is_favorite': 1,
    'rating': 4.5,
    'date_started': '2024-08-16',
    'date_finished': '2024-08-24',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Font Style'),
        backgroundColor: colors.surfaceContainer,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ValueListenableBuilder<String>(
        valueListenable: settingsViewModel.selectedFontNotifier,
        builder: (context, selectedFont, _) {
          return Column(
            children: [
              // Preview section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PREVIEW',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withAlpha(120),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Theme(
                      data: theme.copyWith(
                        textTheme: GoogleFonts.getTextTheme(selectedFont, theme.textTheme),
                      ),
                      child: BookRow(
                        book: _sampleBook,
                        onTap: () {},
                        showStars: true,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 24),

              // Font list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _fonts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final fontName = _fonts[index];
                    final isSelected = fontName == selectedFont;
                    return _FontOption(
                      fontName: fontName,
                      isSelected: isSelected,
                      onTap: () async => await settingsViewModel.setSelectedFont(fontName),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FontOption extends StatelessWidget {
  final String fontName;
  final bool isSelected;
  final VoidCallback onTap;

  const _FontOption({
    required this.fontName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      borderRadius: BorderRadius.circular(12),
      color: isSelected
          ? colors.primary.withAlpha(26)
          : colors.surfaceContainer,
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
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: colors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
