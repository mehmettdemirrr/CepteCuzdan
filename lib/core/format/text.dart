/// Türkçe büyük/küçük harf duyarsız karşılaştırma için katlama.
/// Dart'ın `toLowerCase`'i Türkçe değildir (`I` → `i`, `İ` → `i̇`); burada
/// `I` → `ı`, `İ` → `i` çevrilir: `SAĞLIK` ile `Sağlık` eşleşir.
String foldTr(String s) =>
    s.trim().replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
