import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:read_stats/ui/pages/book/widgets/isbn_input_formatter.dart';
import 'package:read_stats/ui/pages/book_search/barcode_scanner_page.dart';
import 'package:read_stats/ui/widgets/field_decoration.dart';

/// The ISBN, typed or scanned from the barcode with the button beside it.
class IsbnField extends StatelessWidget {
  final TextEditingController controller;

  /// The reader typed in the field.
  final VoidCallback onEdited;

  /// A barcode was scanned; the field is not yet filled in.
  final ValueChanged<String> onScanned;

  const IsbnField({
    super.key,
    required this.controller,
    required this.onEdited,
    required this.onScanned,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: filledFieldDecoration(
                theme,
              ).copyWith(labelText: 'ISBN', hintText: '978-X-XX-XXXXXX-X'),
              keyboardType: TextInputType.number,
              inputFormatters: [IsbnInputFormatter()],
              onChanged: (_) => onEdited(),
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
          ),
          const SizedBox(width: 8),
          AspectRatio(
            aspectRatio: 1,
            child: Tooltip(
              message: 'Scan barcode',
              child: Material(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final result = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) => const BarcodeScannerPage(),
                      ),
                    );
                    if (result != null) onScanned(result);
                  },
                  child: const Center(
                    child: Icon(FluentIcons.barcode_scanner_24_regular),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
