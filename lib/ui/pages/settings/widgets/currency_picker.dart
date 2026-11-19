import 'package:flutter/material.dart';
import 'package:read_stats/data/utils/money.dart';
import 'package:read_stats/ui/settings_view_model.dart';

/// "USD · $" — a currency as Settings names it.
String currencyLabel(String code) {
  final symbol = Money.symbol(code);
  return symbol == code ? code : '$code · $symbol';
}

/// Picks the currency every price is shown in. Changing it relabels
/// the amounts already entered; it doesn't convert them.
void showCurrencyPicker(
    BuildContext context, SettingsViewModel settingsViewModel) {
  final theme = Theme.of(context);
  final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
  final current = settingsViewModel.currencyNotifier.value;
  final accentColor = settingsViewModel.accentColorNotifier.value;

  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Currency',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Amounts you have entered are kept as they are, not converted.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final code in Money.codes)
                    ListTile(
                      onTap: () {
                        settingsViewModel.setCurrency(code);
                        Navigator.pop(context);
                      },
                      contentPadding: EdgeInsets.zero,
                      leading: code == current
                          ? Icon(Icons.check, color: accentColor)
                          : const SizedBox(width: 24),
                      title: Text(
                        currencyLabel(code),
                        style: TextStyle(
                          fontSize: 16,
                          color: code == current ? accentColor : textColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
