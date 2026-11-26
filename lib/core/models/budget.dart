/// Aylık bütçe limiti. `categoryId == null` ise aylık genel bütçedir.
class Budget {
  const Budget({
    this.id,
    this.categoryId,
    required this.month,
    required this.limitAmount,
  });

  final int? id;

  /// `null` = aylık genel bütçe.
  final int? categoryId;

  /// `yyyy-MM`.
  final String month;

  /// Kuruş, > 0.
  final int limitAmount;

  bool get isOverall => categoryId == null;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'category_id': categoryId,
    'month': month,
    'limit_amount': limitAmount,
  };

  factory Budget.fromMap(Map<String, Object?> m) => Budget(
    id: m['id'] as int?,
    categoryId: m['category_id'] as int?,
    month: m['month'] as String,
    limitAmount: m['limit_amount'] as int,
  );

  Budget copyWith({
    int? id,
    int? categoryId,
    String? month,
    int? limitAmount,
  }) => Budget(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    month: month ?? this.month,
    limitAmount: limitAmount ?? this.limitAmount,
  );

  @override
  bool operator ==(Object other) =>
      other is Budget &&
      other.id == id &&
      other.categoryId == categoryId &&
      other.month == month &&
      other.limitAmount == limitAmount;

  @override
  int get hashCode => Object.hash(id, categoryId, month, limitAmount);
}
