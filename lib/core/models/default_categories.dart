import 'category.dart';
import 'enums.dart';

/// İlk açılışta eklenen kategoriler. Gider listesi rapordaki sırayla;
/// gelir için `Maaş` ve `Diğer` (plan kararı).
const List<Category> defaultCategories = [
  Category(
    name: 'Market',
    type: TxType.expense,
    color: 0xFF2E7D32,
    icon: 'shopping_cart',
    isDefault: true,
  ),
  Category(
    name: 'Ulaşım',
    type: TxType.expense,
    color: 0xFF1565C0,
    icon: 'directions_bus',
    isDefault: true,
  ),
  Category(
    name: 'Faturalar',
    type: TxType.expense,
    color: 0xFFF9A825,
    icon: 'receipt_long',
    isDefault: true,
  ),
  Category(
    name: 'Yeme-İçme',
    type: TxType.expense,
    color: 0xFFE65100,
    icon: 'restaurant',
    isDefault: true,
  ),
  Category(
    name: 'Eğlence',
    type: TxType.expense,
    color: 0xFF6A1B9A,
    icon: 'movie',
    isDefault: true,
  ),
  Category(
    name: 'Sağlık',
    type: TxType.expense,
    color: 0xFFC62828,
    icon: 'local_hospital',
    isDefault: true,
  ),
  Category(
    name: 'Diğer',
    type: TxType.expense,
    color: 0xFF546E7A,
    icon: 'category',
    isDefault: true,
  ),
  Category(
    name: 'Maaş',
    type: TxType.income,
    color: 0xFF00897B,
    icon: 'payments',
    isDefault: true,
  ),
  Category(
    name: 'Diğer',
    type: TxType.income,
    color: 0xFF78909C,
    icon: 'savings',
    isDefault: true,
  ),
];

/// "Kategori belirsizse Diğer" kuralı için kategori adı.
const String fallbackCategoryName = 'Diğer';
