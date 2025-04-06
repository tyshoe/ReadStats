import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../viewmodels/SettingsViewModel.dart';
import 'package:google_fonts/google_fonts.dart';

class FontSelectionPage extends StatelessWidget {
  final SettingsViewModel settingsViewModel;

  const FontSelectionPage({
    super.key,
    required this.settingsViewModel,
  });

  @override
  Widget build(BuildContext context) {
    // Define a list of font styles with Google Fonts
    final List<Map<String, String>> fonts = [
      {
        'name': 'Roboto',
        'sampleText': 'The quick brown fox jumps over the lazy dog.'
      },
      {
        'name': 'Open Sans',
        'sampleText': 'The quick brown fox jumps over the lazy dog.'
      },
      {
        'name': 'Lato',
        'sampleText': 'The quick brown fox jumps over the lazy dog.'
      },
      {
        'name': 'Montserrat',
        'sampleText': 'The quick brown fox jumps over the lazy dog.'
      },
      {
        'name': 'Playfair Display',
        'sampleText': 'The quick brown fox jumps over the lazy dog.'
      },
      {
        'name': 'Raleway',
        'sampleText': 'The quick brown fox jumps over the lazy dog.'
      },
      {
        'name': 'Poppins',
        'sampleText': 'The quick brown fox jumps over the lazy dog.'
      },
      {
        'name': 'Merriweather',
        'sampleText': 'The quick brown fox jumps over the lazy dog.'
      },
    ];

    // Get the current theme mode (light or dark)
    bool isDarkMode =
        settingsViewModel.themeModeNotifier.value == ThemeMode.dark;

    // Get the currently selected font
    String selectedFont = settingsViewModel.selectedFontNotifier.value;

    // Choose colors based on the theme
    Color backgroundColor = isDarkMode
        ? CupertinoColors.systemGrey6
        : CupertinoColors.secondarySystemBackground;
    final textColor = CupertinoColors.label.resolveFrom(context);
    final accentColor = settingsViewModel.accentColorNotifier.value;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Select Font', style: TextStyle(color: textColor)),
        backgroundColor: backgroundColor,
      ),
      child: SafeArea(
        child: ListView.builder(
          itemCount: fonts.length,
          itemBuilder: (context, index) {
            bool isSelected = fonts[index]['name'] == selectedFont;

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () async {
                  // Update the font selection in the settings view model
                  await settingsViewModel
                      .setSelectedFont(fonts[index]['name']!);
                  // Optionally, pop the page after selecting the font
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withOpacity(0.2)
                        : CupertinoColors.secondarySystemBackground
                            .resolveFrom(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isSelected) ...[
                            Icon(
                              CupertinoIcons.check_mark,
                              color: accentColor,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            fonts[index]['name']!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
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
                          color: textColor,
                        ),
                      ),

                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
