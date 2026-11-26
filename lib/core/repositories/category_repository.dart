import '../models/category.dart';
import '../models/enums.dart';

/// Aynı ad ve tipte bir kategori zaten varsa fırlatılır.
class DuplicateCategoryException implements Exception {
  const DuplicateCategoryException(this.name);
  final String name;

  @override
  String toString() => 'DuplicateCategoryException($name)';
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
  Future<void> update(Category c);

  /// Varsayılan kategoride [StateError]. İşlemleri aynı tipteki "Diğer"e
  /// taşır; kategorinin bütçe limitleri silinir.
  Future<void> delete(int id);
}
