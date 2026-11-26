import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../core/models/category.dart';
import '../../core/models/enums.dart';
import '../../core/repositories/category_repository.dart';

/// Kategorilerin bellekteki kopyası. Ekranlar senkron okur ([ofType],
/// [byId]); değişiklikler repository'ye yazılıp liste yeniden yüklenir.
class CategoryProvider extends ChangeNotifier {
  CategoryProvider(this._repo, {this.onDeleted});

  final CategoryRepository _repo;

  /// Kategori silinince çağrılır: işlemleri "Diğer"e taşındığı ve bütçe
  /// limitleri silindiği için işlem ekranlarının yenilenmesi gerekir.
  final void Function()? onDeleted;
  List<Category> _categories = const [];
  bool _loaded = false;

  List<Category> get categories => _categories;
  bool get loaded => _loaded;

  List<Category> ofType(TxType type) =>
      _categories.where((c) => c.type == type).toList();

  Category? byId(int id) {
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> load() async {
    _categories = await _repo.all();
    _loaded = true;
    notifyListeners();
  }

  /// Aynı ad+tip varsa `DuplicateCategoryException` fırlatır.
  Future<void> add(Category c) async {
    await _repo.add(c);
    await load();
  }

  Future<void> update(Category c) async {
    await _repo.update(c);
    await load();
  }

  /// Varsayılan kategoride `StateError` fırlatır.
  Future<void> delete(int id) async {
    await _repo.delete(id);
    await load();
    onDeleted?.call();
  }
}
