import 'package:flutter/material.dart';

/// Kategori ikonları. DB'de anahtar (string) tutulur; `IconData` her zaman bu
/// sabit map'ten gelir. Dinamik `IconData(codePoint)` release build'deki
/// icon tree-shaking'i bozduğu için kullanılmaz.
const Map<String, IconData> categoryIcons = {
  // Varsayılan kategoriler
  'shopping_cart': Icons.shopping_cart,
  'directions_bus': Icons.directions_bus,
  'receipt_long': Icons.receipt_long,
  'restaurant': Icons.restaurant,
  'movie': Icons.movie,
  'local_hospital': Icons.local_hospital,
  'category': Icons.category,
  'payments': Icons.payments,
  'savings': Icons.savings,
  // Kullanıcının seçebileceği ek ikonlar
  'local_cafe': Icons.local_cafe,
  'shopping_bag': Icons.shopping_bag,
  'home': Icons.home,
  'school': Icons.school,
  'pets': Icons.pets,
  'fitness_center': Icons.fitness_center,
  'flight': Icons.flight,
  'card_giftcard': Icons.card_giftcard,
  'phone_android': Icons.phone_android,
  'checkroom': Icons.checkroom,
  'work': Icons.work,
  'sports_esports': Icons.sports_esports,
};

IconData iconFor(String key) => categoryIcons[key] ?? Icons.category;

/// İkon seçicide ekran okuyucunun ve ipucunun söyleyeceği adlar.
const Map<String, String> categoryIconLabels = {
  'shopping_cart': 'Alışveriş arabası',
  'directions_bus': 'Otobüs',
  'receipt_long': 'Fatura',
  'restaurant': 'Restoran',
  'movie': 'Sinema',
  'local_hospital': 'Hastane',
  'category': 'Genel',
  'payments': 'Ödeme',
  'savings': 'Birikim',
  'local_cafe': 'Kafe',
  'shopping_bag': 'Alışveriş çantası',
  'home': 'Ev',
  'school': 'Okul',
  'pets': 'Evcil hayvan',
  'fitness_center': 'Spor',
  'flight': 'Seyahat',
  'card_giftcard': 'Hediye',
  'phone_android': 'Telefon',
  'checkroom': 'Giyim',
  'work': 'İş',
  'sports_esports': 'Oyun',
};

/// Kategori rengi seçenekleri (ARGB).
const List<Color> categoryPalette = [
  Color(0xFF2E7D32),
  Color(0xFF1565C0),
  Color(0xFFF9A825),
  Color(0xFFE65100),
  Color(0xFF6A1B9A),
  Color(0xFFC62828),
  Color(0xFF00897B),
  Color(0xFFAD1457),
  Color(0xFF5D4037),
  Color(0xFF546E7A),
];
