import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/ui/widgets/field_decoration.dart';

/// What the reader paid for this copy and when they bought it, side by
/// side. Both optional; without a date the book counts as bought the day
/// it was added.
class PricePaidFields extends StatelessWidget {
  final TextEditingController priceController;

  /// The currency symbol, e.g. "$".
  final String symbol;
  final DateTime? datePurchased;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;

  const PricePaidFields({
    super.key,
    required this.priceController,
    required this.symbol,
    required this.datePurchased,
    required this.onPickDate,
    required this.onClearDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bought = datePurchased;
    // Digits with up to two decimals, either mark. A keystroke that would
    // break that is dropped rather than clearing what is there.
    final amount = RegExp(r'^\d{0,9}([.,]\d{0,2})?$');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: priceController,
              decoration: filledFieldDecoration(theme).copyWith(
                labelText: 'Price paid',
                hintText: '0.00',
                prefixText: '$symbol ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) =>
                      amount.hasMatch(newValue.text) ? newValue : oldValue,
                ),
              ],
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              readOnly: true,
              onTap: onPickDate,
              controller: TextEditingController(
                text: bought == null
                    ? ''
                    : DateFormat('MMM d, y').format(bought),
              ),
              decoration: filledFieldDecoration(theme).copyWith(
                labelText: 'Bought on',
                suffixIcon: bought != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: onClearDate,
                      )
                    : const Icon(Icons.calendar_today),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
