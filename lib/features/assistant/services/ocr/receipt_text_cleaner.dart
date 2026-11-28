/// Ham OCR çıktısını Gemini'ye göndermeden önce temizler.
/// Gereksiz boşlukları, yalnızca ayırıcı çizgilerden oluşan satırları ve
/// ardışık yinelenen satırları kaldırır.
String cleanReceiptText(String rawText) {
  final normalized = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalized.split('\n');
  final cleanedLines = <String>[];

  for (final line in lines) {
    final collapsed = line.trim().replaceAll(RegExp(r'[ \t]+'), ' ');
    if (collapsed.isEmpty) continue;
    // Yalnızca ayırıcı / noktalama karakterlerinden oluşan satırları ele.
    if (_isOnlyPunctuation(collapsed)) continue;
    if (cleanedLines.isNotEmpty && cleanedLines.last == collapsed) continue;
    cleanedLines.add(collapsed);
  }

  return cleanedLines.join('\n');
}

/// Temizlenmiş OCR metninin Gemini'ye gönderilmeye değer olup olmadığını kontrol eder.
/// Boş, çok kısa veya anlamsız gürültü metinlerinde `false` döner.
bool isMeaningfulReceiptText(String cleanedText) {
  final trimmed = cleanedText.trim();
  if (trimmed.length < 8) return false;

  final alphaNumCount = RegExp(r'[0-9A-Za-zÇĞİÖŞÜçğıöşü]')
      .allMatches(trimmed)
      .length;
  return alphaNumCount >= 4;
}

bool _isOnlyPunctuation(String line) {
  return !RegExp(r'[0-9A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(line);
}
