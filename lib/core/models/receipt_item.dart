/// Fişten okunan ürün kalemi. `price` satır tutarıdır (kuruş).
class ReceiptItem {
  const ReceiptItem({
    this.id,
    this.transactionId,
    required this.name,
    this.quantity = 1,
    required this.price,
  });

  final int? id;
  final int? transactionId;
  final String name;
  final double quantity;

  /// Satır tutarı, kuruş.
  final int price;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'transaction_id': transactionId,
    'name': name,
    'quantity': quantity,
    'price': price,
  };

  factory ReceiptItem.fromMap(Map<String, Object?> m) => ReceiptItem(
    id: m['id'] as int?,
    transactionId: m['transaction_id'] as int?,
    name: m['name'] as String,
    quantity: (m['quantity'] as num).toDouble(),
    price: m['price'] as int,
  );

  ReceiptItem copyWith({
    int? id,
    int? transactionId,
    String? name,
    double? quantity,
    int? price,
  }) => ReceiptItem(
    id: id ?? this.id,
    transactionId: transactionId ?? this.transactionId,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    price: price ?? this.price,
  );

  @override
  bool operator ==(Object other) =>
      other is ReceiptItem &&
      other.id == id &&
      other.transactionId == transactionId &&
      other.name == name &&
      other.quantity == quantity &&
      other.price == price;

  @override
  int get hashCode => Object.hash(id, transactionId, name, quantity, price);
}
