import '../models/category.dart';
import '../models/enums.dart';

/// Aynı ad ve tipte bir kategori zaten varsa fırlatılır.
class DuplicateCategoryException implements Exception {
  const DuplicateCategoryException(this.name);
  final String name;

  @override
  String toString() => 'DuplicateCategoryException($name)';
}

/// [CategoryRepository.update] kuralı: varsayılan kategorinin adı, türü ve
/// varsayılanlığı değişmez. İki implementasyon da bunu çağırır.
void checkDefaultCategoryUpdate(Category stored, Category updated) {
  if (!stored.isDefault) return;
  if (updated.name != stored.name ||
      updated.type != stored.type ||
      !updated.isDefault) {
    throw ArgumentError.value(
      updated.name,
      'category',
      'Varsayılan kategorinin adı ve türü değiştirilemez',
    );
  }
}

abstract class CategoryRepository {
  /// Kategoriler, eklenme sırasıyla (varsayılanlar önce).
  Future<List<Category>> all({TxType? type});

  /// Önce birebir, sonra büyük/küçük harf duyarsız eşleşme. Yoksa `null`.
  /// Gemini'nin döndürdüğü kategori adını id'ye çevirmek için.
  Future<Category?> findByName(String name, TxType type);

  /// Aynı ad+tip varsa [DuplicateCategoryException].
  Future<int> add(Category c);

  /// Aynı ad+tip başka kategoride varsa [DuplicateCategoryException].
  /// Varsayılan kategoride ad, tür veya varsayılanlık değişirse
  /// [ArgumentError] ("Diğer" yedek kategori olarak adıyla bulunur); renk ve
  /// ikon değişebilir.
  Future<void> update(Category c);

  /// Varsayılan kategoride [StateError]. İşlemleri aynı tipteki "Diğer"e
  /// taşır; kategorinin bütçe limitleri silinir.
  Future<void> delete(int id);
}
