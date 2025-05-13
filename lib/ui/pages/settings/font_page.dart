import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../viewmodels/SettingsViewModel.dart';

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

    // Define a list of font styles with Google Fonts
    final List<Map<String, String>> fonts = [
      {'name': 'Roboto', 'sampleText': 'The quick brown fox jumps over the lazy dog'},
      {'name': 'Open Sans', 'sampleText': 'The quick brown fox jumps over the lazy dog'},
      {'name': 'Lato', 'sampleText': 'The quick brown fox jumps over the lazy dog'},
      {'name': 'Montserrat', 'sampleText': 'The quick brown fox jumps over the lazy dog'},
      {'name': 'Playfair Display', 'sampleText': 'The quick brown fox jumps over the lazy dog'},
      {'name': 'Raleway', 'sampleText': 'The quick brown fox jumps over the lazy dog'},
      {'name': 'Poppins', 'sampleText': 'The quick brown fox jumps over the lazy dog'},
      {'name': 'Merriweather', 'sampleText': 'The quick brown fox jumps over the lazy dog'},
    ];

    final String selectedFont = settingsViewModel.selectedFontNotifier.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Font'),
        backgroundColor: colors.surface,
        elevation: 0,
      ),
      backgroundColor: colors.background,
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: fonts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final isSelected = fonts[index]['name'] == selectedFont;

          return Card(
            elevation: 0,
            color: isSelected
                ? colors.primary.withOpacity(0.1)
                : colors.surfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isSelected
                  ? BorderSide(color: colors.primary, width: 1.5)
                  : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await settingsViewModel.setSelectedFont(fonts[index]['name']!);
                Navigator.pop(context);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: colors.primary,
                          ),
                        if (isSelected) const SizedBox(width: 8),
                        Text(
                          fonts[index]['name']!,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? colors.primary : colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fonts[index]['sampleText']!,
                      style: GoogleFonts.getFont(
                        fonts[index]['name']!,
                        fontSize: 14,
                        color: colors.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}