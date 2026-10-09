import 'package:flutter/services.dart';

/// Accepts currency values from zero through [maxAmount], with two decimals.
class AmountRangeInputFormatter extends TextInputFormatter {
  const AmountRangeInputFormatter({required this.maxAmount});

  final double maxAmount;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(text)) return oldValue;

    final valueText =
        text.endsWith('.') ? text.substring(0, text.length - 1) : text;
    if (valueText.isEmpty) return oldValue;

    final amount = double.tryParse(valueText);
    if (amount == null || amount < 0 || amount > maxAmount) return oldValue;
    return newValue;
  }
}
