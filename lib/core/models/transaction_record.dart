import '../format/dates.dart';
import 'enums.dart';

/// Bir gelir ya da gider kaydı. `amount` kuruş cinsindendir ve 0'dan büyüktür.
class TransactionRecord {
  const TransactionRecord({
    this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.merchant,
    this.note,
    required this.source,
    this.receiptPath,
    required this.createdAt,
  });

  final int? id;
  final TxType type;

  /// Kuruş, > 0.
  final int amount;
  final int categoryId;

  /// İşlemin günü (saat önemsizdir; DB'de `yyyy-MM-dd`).
  final DateTime date;
  final String? merchant;
  final String? note;
  final TxSource source;
  final String? receiptPath;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'type': type.name,
    'amount': amount,
    'category_id': categoryId,
    'date': toDbDate(date),
    'merchant': merchant,
    'note': note,
    'source': source.name,
    'receipt_path': receiptPath,
    'created_at': createdAt.toIso8601String(),
  };

  factory TransactionRecord.fromMap(Map<String, Object?> m) =>
      TransactionRecord(
        id: m['id'] as int?,
        type: TxType.values.byName(m['type'] as String),
        amount: m['amount'] as int,
        categoryId: m['category_id'] as int,
        date: fromDbDate(m['date'] as String),
        merchant: m['merchant'] as String?,
        note: m['note'] as String?,
        source: TxSource.values.byName(m['source'] as String),
        receiptPath: m['receipt_path'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  TransactionRecord copyWith({
    int? id,
    TxType? type,
    int? amount,
    int? categoryId,
    DateTime? date,
    String? merchant,
    String? note,
    TxSource? source,
    String? receiptPath,
    DateTime? createdAt,
  }) => TransactionRecord(
    id: id ?? this.id,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    categoryId: categoryId ?? this.categoryId,
    date: date ?? this.date,
    merchant: merchant ?? this.merchant,
    note: note ?? this.note,
    source: source ?? this.source,
    receiptPath: receiptPath ?? this.receiptPath,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  bool operator ==(Object other) =>
      other is TransactionRecord &&
      other.id == id &&
      other.type == type &&
      other.amount == amount &&
      other.categoryId == categoryId &&
      other.date == date &&
      other.merchant == merchant &&
      other.note == note &&
      other.source == source &&
      other.receiptPath == receiptPath &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    type,
    amount,
    categoryId,
    date,
    merchant,
    note,
    source,
    receiptPath,
    createdAt,
  );

  @override
  String toString() =>
      'TransactionRecord($id, ${type.name}, $amount, cat=$categoryId, '
      '${toDbDate(date)}, ${source.name})';
}
