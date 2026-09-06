const productUnits = <String>[
  'KG',
  'Gram',
  'Litre',
  'ML',
  'Piece',
  'Box',
  'Packet',
  'Bottle',
  'Dozen',
  'Carton',
  'Metre',
];

double quantityValue(dynamic value) => (value as num?)?.toDouble() ?? 0;

String formatQuantity(dynamic value) {
  final quantity = quantityValue(value);
  if (quantity == quantity.roundToDouble()) return quantity.toInt().toString();
  return quantity
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String productUnit(Map product) =>
    (product['unit']?.toString().trim().isNotEmpty ?? false)
        ? product['unit'].toString()
        : 'Piece';

String formatProductQuantity(dynamic quantity, Map product) =>
    '${formatQuantity(quantity)} ${productUnit(product)}';
