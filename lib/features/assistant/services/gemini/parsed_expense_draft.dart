import 'package:flutter/foundation.dart' show listEquals;

import '../../../../core/models/enums.dart';

/// Gemini çıktısından ayrıştırılmış fiş kalemi taslağı.
/// [priceTl] satır toplamıdır (miktar × birim fiyat), TL cinsindendir.
/// Kuruş dönüşümü yalnızca kayıt anında `tlToKurus` ile yapılır.
class ParsedReceiptItem {
  const ParsedReceiptItem({
    required this.name,
    this.quantity = 1.0,
    required this.priceTl,
  });

  final String name;
  final double quantity;

  /// Satır toplamı (TL).
  final double priceTl;

  @override
  bool operator ==(Object other) =>
      other is ParsedReceiptItem &&
      other.name == name &&
      other.quantity == quantity &&
      other.priceTl == priceTl;

  @override
  int get hashCode => Object.hash(name, quantity, priceTl);

  @override
  String toString() =>
      'ParsedReceiptItem(name: $name, quantity: $quantity, priceTl: $priceTl)';
}

/// Gemini çıktısından doğrulanmış, bellek içi gelir/gider taslağı.
/// Tutarlar TL cinsindendir; kuruş dönüşümü yalnızca kayıt anında yapılır.
class ParsedExpenseDraft {
  const ParsedExpenseDraft({
    required this.type,
    required this.amountTl,
    required this.merchant,
    required this.date,
    required this.categoryName,
    required this.source,
    required this.items,
    required this.usedDefaultDate,
    required this.usedFallbackCategory,
  });

  final TxType type;

  /// Toplam tutar (TL, kesinlikle > 0 ve sonlu).
  final double amountTl;
  final String? merchant;
  final DateTime date;

  /// Kullanıcının ilgili türdeki kategori listesinden eşleşen ad ya da "Diğer".
  final String categoryName;
  final TxSource source;
  final List<ParsedReceiptItem> items;

  /// Tarih okunamadığı veya eksik olduğu için bugünün tarihi atandıysa `true`.
  final bool usedDefaultDate;

  /// Kategori bilinmediği veya türle uyuşmadığı için "Diğer" atandıysa `true`.
  final bool usedFallbackCategory;

  @override
  bool operator ==(Object other) =>
      other is ParsedExpenseDraft &&
      other.type == type &&
      other.amountTl == amountTl &&
      other.merchant == merchant &&
      other.date == date &&
      other.categoryName == categoryName &&
      other.source == source &&
      listEquals(other.items, items) &&
      other.usedDefaultDate == usedDefaultDate &&
      other.usedFallbackCategory == usedFallbackCategory;

  @override
  int get hashCode => Object.hash(
    type,
    amountTl,
    merchant,
    date,
    categoryName,
    source,
    Object.hashAll(items),
    usedDefaultDate,
    usedFallbackCategory,
  );
}

enum ExpenseDraftErrorCode {
  emptyInput,
  invalidJson,
  missingField,
  invalidType,
  invalidAmount,
  networkOrService,
  quotaExceeded,
  notConfigured,
  unknown,
}

/// Kullanıcıya güvenle gösterilebilecek tipli taslak çıkarma hatası.
/// Ham fiş metni veya tutar içermez.
class ExpenseDraftError {
  const ExpenseDraftError({
    required this.code,
    required this.userMessage,
    this.debugDetail,
  });

  final ExpenseDraftErrorCode code;
  final String userMessage;
  final String? debugDetail;

  @override
  String toString() => 'ExpenseDraftError($code: $userMessage)';
}

/// Taslak çıkarma işleminin sonucu: ya doğrulanmış taslak ya da tipli hata.
sealed class ExpenseDraftResult {
  const ExpenseDraftResult();
}

final class ExpenseDraftSuccess extends ExpenseDraftResult {
  const ExpenseDraftSuccess(this.draft);

  final ParsedExpenseDraft draft;
}

final class ExpenseDraftFailure extends ExpenseDraftResult {
  const ExpenseDraftFailure(this.error);

  final ExpenseDraftError error;
}
