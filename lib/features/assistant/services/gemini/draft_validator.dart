import 'dart:convert';

import '../../../../core/format/dates.dart';
import '../../../../core/format/text.dart';
import '../../../../core/models/default_categories.dart';
import '../../../../core/models/enums.dart';
import 'parsed_expense_draft.dart';

final _isoDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _digitsOnly = RegExp(r'^\d+$');
final _trGrouped = RegExp(r'^\d{1,3}(\.\d{3})+$');
final _enGrouped = RegExp(r'^\d{1,3}(,\d{3})+$');
final _maxAmountTl = 999999999999.99;

/// Gemini ham metin yanıtını çözümler ve sıkı istemci doğrulamasından geçirir.
/// Ağ/servis çağrısından bağımsız saf fonksiyondur.
ExpenseDraftResult parseAndValidateDraft({
  required String rawResponse,
  required DateTime today,
  required Map<TxType, List<String>> categoriesByType,
  required TxSource source,
}) {
  final cleaned = stripMarkdownCodeFence(rawResponse);
  if (cleaned.isEmpty) {
    return const ExpenseDraftFailure(
      ExpenseDraftError(
        code: ExpenseDraftErrorCode.invalidJson,
        userMessage:
            'AI yanıtı okunamadı. Lütfen tekrar deneyin veya manuel ekleyin.',
        debugDetail: 'Boş yanıt',
      ),
    );
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(cleaned);
  } on FormatException {
    return const ExpenseDraftFailure(
      ExpenseDraftError(
        code: ExpenseDraftErrorCode.invalidJson,
        userMessage:
            'AI yanıtı okunamadı. Lütfen tekrar deneyin veya manuel ekleyin.',
        debugDetail: 'JSON çözümleme hatası',
      ),
    );
  }

  if (decoded is! Map<String, dynamic>) {
    return const ExpenseDraftFailure(
      ExpenseDraftError(
        code: ExpenseDraftErrorCode.invalidJson,
        userMessage: 'AI yanıtı beklenen biçimde değil. Lütfen tekrar deneyin veya manuel ekleyin.',
        debugDetail: 'Kök JSON nesne değil',
      ),
    );
  }

  return validateDraftMap(
    map: decoded,
    today: today,
    categoriesByType: categoriesByType,
    source: source,
  );
}

/// Çözümlenmiş JSON haritasını doğrular. Kuruş dönüşümü yapmaz; tutarlar TL kalır.
ExpenseDraftResult validateDraftMap({
  required Map<String, Object?> map,
  required DateTime today,
  required Map<TxType, List<String>> categoriesByType,
  required TxSource source,
}) {
  final rawType = map['type'];
  if (rawType == null || (rawType is String && rawType.trim().isEmpty)) {
    return const ExpenseDraftFailure(
      ExpenseDraftError(
        code: ExpenseDraftErrorCode.missingField,
        userMessage:
            'İşlem türü bulunamadı. Lütfen tekrar deneyin veya manuel ekleyin.',
        debugDetail: 'type alanı eksik',
      ),
    );
  }

  final type = _parseType(rawType);
  if (type == null) {
    return const ExpenseDraftFailure(
      ExpenseDraftError(
        code: ExpenseDraftErrorCode.invalidType,
        userMessage: 'İşlem türü (gelir/gider) anlaşılamadı. Lütfen tekrar deneyin veya manuel ekleyin.',
        debugDetail: 'Geçersiz type alanı',
      ),
    );
  }

  if (!map.containsKey('amount') || map['amount'] == null) {
    return const ExpenseDraftFailure(
      ExpenseDraftError(
        code: ExpenseDraftErrorCode.missingField,
        userMessage: 'Tutar bilgisi bulunamadı. Lütfen tutarı belirtin veya manuel ekleyin.',
        debugDetail: 'amount alanı eksik',
      ),
    );
  }

  final amountTl = parsePositiveTlAmount(map['amount']);
  if (amountTl == null) {
    return const ExpenseDraftFailure(
      ExpenseDraftError(
        code: ExpenseDraftErrorCode.invalidAmount,
        userMessage: 'Geçerli bir tutar bulunamadı. Lütfen tutarı kontrol edin veya manuel ekleyin.',
        debugDetail: 'Geçersiz veya pozitif olmayan tutar',
      ),
    );
  }

  final merchant = _parseOptionalString(map['merchant']);
  final normalizedToday = DateTime(today.year, today.month, today.day);
  final (date, usedDefaultDate) = _parseDate(map['date'], normalizedToday);

  final allowedCategories = categoriesByType[type] ?? const <String>[];
  final (categoryName, usedFallbackCategory) = _matchCategory(
    rawCategory: map['category'],
    allowedCategories: allowedCategories,
  );

  final items = _parseItems(map['items']);

  return ExpenseDraftSuccess(
    ParsedExpenseDraft(
      type: type,
      amountTl: amountTl,
      merchant: merchant,
      date: date,
      categoryName: categoryName,
      source: source,
      items: items,
      usedDefaultDate: usedDefaultDate,
      usedFallbackCategory: usedFallbackCategory,
    ),
  );
}

/// ```json ... ``` veya ``` ... ``` markdown kod çitlerini temizler.
String stripMarkdownCodeFence(String input) {
  final trimmed = input.trim();
  if (!trimmed.startsWith('```')) return trimmed;

  final firstNewline = trimmed.indexOf('\n');
  if (firstNewline == -1) return trimmed;

  final afterOpening = trimmed.substring(firstNewline + 1);
  final closingIndex = afterOpening.lastIndexOf('```');
  if (closingIndex == -1) return afterOpening.trim();

  return afterOpening.substring(0, closingIndex).trim();
}

/// Sayı veya Türkçe/standart metin ("320,00", "1.234,50", "320.50") olarak gelen
/// tutarı pozitif, sonlu TL `double` değerine çevirir. Geçersizse `null` döner.
double? parsePositiveTlAmount(Object? raw) {
  double? value;
  if (raw is num) {
    value = raw.toDouble();
  } else if (raw is String) {
    value = _parseTlString(raw);
  } else {
    return null;
  }

  if (value == null || value.isNaN || value.isInfinite) return null;
  if (value <= 0 || value > _maxAmountTl) return null;
  return value;
}

final _currencyEdgePattern = RegExp(
  r'^(?:₺|tl|try)\s*|\s*(?:₺|tl|try)$',
  caseSensitive: false,
);

double? _parseTlString(String raw) {
  var s = raw.trim();
  // Başta/sonda para simgesi varsa ("₺150,00", "150,00 TL", "TRY 1.234,50") temizle.
  while (_currencyEdgePattern.hasMatch(s)) {
    s = s.replaceAll(_currencyEdgePattern, '').trim();
  }
  if (s.isEmpty) return null;

  final commaCount = ','.allMatches(s).length;
  final dotCount = '.'.allMatches(s).length;

  String normalized;
  if (commaCount == 1 && dotCount == 0) {
    // Örn: "320,00" veya "12,5"
    final parts = s.split(',');
    if (!_digitsOnly.hasMatch(parts[0]) ||
        parts[1].isEmpty ||
        !_digitsOnly.hasMatch(parts[1])) {
      return null;
    }
    normalized = '${parts[0]}.${parts[1]}';
  } else if (commaCount == 1 && dotCount >= 1) {
    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');
    if (lastComma > lastDot) {
      // Türkçe biçim: "1.234,50"
      final intPart = s.substring(0, lastComma);
      final fracPart = s.substring(lastComma + 1);
      if (!_trGrouped.hasMatch(intPart) ||
          fracPart.isEmpty ||
          !_digitsOnly.hasMatch(fracPart)) {
        return null;
      }
      normalized = '${intPart.replaceAll('.', '')}.$fracPart';
    } else {
      // İngilizce biçim: "1,234.50"
      final intPart = s.substring(0, lastDot);
      final fracPart = s.substring(lastDot + 1);
      if (!_enGrouped.hasMatch(intPart) ||
          fracPart.isEmpty ||
          !_digitsOnly.hasMatch(fracPart)) {
        return null;
      }
      normalized = '${intPart.replaceAll(',', '')}.$fracPart';
    }
  } else if (commaCount == 0 && dotCount == 1) {
    // "320.50" veya binlik "1.000"
    if (_trGrouped.hasMatch(s)) {
      normalized = s.replaceAll('.', '');
    } else {
      final parts = s.split('.');
      if (!_digitsOnly.hasMatch(parts[0]) ||
          parts[1].isEmpty ||
          !_digitsOnly.hasMatch(parts[1])) {
        return null;
      }
      normalized = s;
    }
  } else if (commaCount == 0 && dotCount > 1) {
    // "1.234.567"
    if (!_trGrouped.hasMatch(s)) return null;
    normalized = s.replaceAll('.', '');
  } else if (commaCount == 0 && dotCount == 0) {
    if (!_digitsOnly.hasMatch(s)) return null;
    normalized = s;
  } else {
    return null;
  }

  return double.tryParse(normalized);
}

TxType? _parseType(Object? raw) {
  if (raw is! String) return null;
  final folded = raw.trim().toLowerCase();
  for (final t in TxType.values) {
    if (t.name == folded) return t;
  }
  return null;
}

String? _parseOptionalString(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

(DateTime, bool) _parseDate(Object? raw, DateTime normalizedToday) {
  if (raw is! String) return (normalizedToday, true);
  final s = raw.trim();
  if (!_isoDatePattern.hasMatch(s)) return (normalizedToday, true);
  try {
    final parsed = fromDbDate(s);
    final date = DateTime(parsed.year, parsed.month, parsed.day);
    // OCR yanlış okuması ("2062", "2019") makul aralık dışındaysa bugün
    // kullanılır ve kartta uyarı gösterilir: en fazla 5 yıl önce, en geç yarın.
    final earliest = DateTime(
      normalizedToday.year - 5,
      normalizedToday.month,
      normalizedToday.day,
    );
    final latest = DateTime(
      normalizedToday.year,
      normalizedToday.month,
      normalizedToday.day + 1,
    );
    if (date.isBefore(earliest) || date.isAfter(latest)) {
      return (normalizedToday, true);
    }
    return (date, false);
  } on FormatException {
    return (normalizedToday, true);
  }
}

(String, bool) _matchCategory({
  required Object? rawCategory,
  required List<String> allowedCategories,
}) {
  final candidate = rawCategory is String ? rawCategory.trim() : '';
  if (candidate.isNotEmpty) {
    final foldedCandidate = foldTr(candidate);
    for (final name in allowedCategories) {
      if (foldTr(name) == foldedCandidate) {
        return (name, false);
      }
    }
  }

  final fallbackFolded = foldTr(fallbackCategoryName);
  for (final name in allowedCategories) {
    if (foldTr(name) == fallbackFolded) {
      return (name, true);
    }
  }
  return (fallbackCategoryName, true);
}

List<ParsedReceiptItem> _parseItems(Object? rawItems) {
  if (rawItems is! List) return const [];
  final result = <ParsedReceiptItem>[];
  for (final entry in rawItems) {
    if (entry is! Map) continue;
    final name = _parseOptionalString(entry['name']);
    if (name == null) continue;
    final priceTl = parsePositiveTlAmount(entry['price']);
    if (priceTl == null) continue;
    final quantity = parsePositiveTlAmount(entry['quantity']) ?? 1.0;
    result.add(
      ParsedReceiptItem(name: name, quantity: quantity, priceTl: priceTl),
    );
  }
  return List.unmodifiable(result);
}
