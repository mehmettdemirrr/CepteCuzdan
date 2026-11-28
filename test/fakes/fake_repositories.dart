// Widget testleri için bellek içi repository'ler. Davranışları
// test/core/repositories/repository_contract.dart ile SQLite
// implementasyonuna eşitlenmiştir (fake_repositories_test.dart).
import 'package:cepte_cuzdan/core/format/dates.dart';
import 'package:cepte_cuzdan/core/format/text.dart';
import 'package:cepte_cuzdan/core/models/budget.dart';
import 'package:cepte_cuzdan/core/models/category.dart';
import 'package:cepte_cuzdan/core/models/chat_message.dart';
import 'package:cepte_cuzdan/core/models/default_categories.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/period_summary.dart';
import 'package:cepte_cuzdan/core/models/receipt_item.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:cepte_cuzdan/core/repositories/budget_repository.dart';
import 'package:cepte_cuzdan/core/repositories/category_repository.dart';
import 'package:cepte_cuzdan/core/repositories/chat_message_repository.dart';
import 'package:cepte_cuzdan/core/repositories/transaction_repository.dart';

/// Dört fake repository'yi ortak bir bellek deposu üzerinde kurar.
/// Varsayılan kategoriler `defaultCategories` sırasıyla 1..9 id'lerini alır.
class FakeRepos {
  FakeRepos() {
    for (final c in defaultCategories) {
      _store.categories.add(c.copyWith(id: _store.nextId()));
    }
  }

  final _store = _Store();

  late final FakeTransactionRepository txs = FakeTransactionRepository._(
    _store,
  );
  late final FakeCategoryRepository categories = FakeCategoryRepository._(
    _store,
  );
  late final FakeBudgetRepository budgets = FakeBudgetRepository._(_store);
  late final FakeChatMessageRepository chats = FakeChatMessageRepository._(
    _store,
  );

  /// `AppDatabase.resetAll` ile aynı: varsayılan kategoriler dışında her şeyi
  /// siler.
  Future<void> reset() async {
    _store.chats.clear();
    _store.items.clear();
    _store.transactions.clear();
    _store.budgets.clear();
    _store.categories.removeWhere((c) => !c.isDefault);
  }
}

class _Store {
  int _id = 0;
  int nextId() => ++_id;

  final categories = <Category>[];
  final transactions = <TransactionRecord>[];
  final items = <ReceiptItem>[];
  final budgets = <Budget>[];
  final chats = <ChatMessage>[];
}

class FakeTransactionRepository implements TransactionRepository {
  FakeTransactionRepository._(this._s);
  final _Store _s;

  /// Testlerde doğrudan bakmak için tüm kayıtlar (eklenme sırasıyla).
  List<TransactionRecord> get records => List.unmodifiable(_s.transactions);

  @override
  Future<int> add(
    TransactionRecord tx, {
    List<ReceiptItem> items = const [],
  }) async {
    _checkCategory(tx);
    final id = _s.nextId();
    _s.transactions.add(tx.copyWith(id: id));
    for (final i in items) {
      _s.items.add(i.copyWith(id: _s.nextId(), transactionId: id));
    }
    return id;
  }

  @override
  Future<void> update(TransactionRecord tx) async {
    _checkCategory(tx);
    final i = _s.transactions.indexWhere((t) => t.id == tx.id);
    if (i >= 0) _s.transactions[i] = tx;
  }

  /// SQLite ile aynı: kategori yoksa ya da türü uyuşmuyorsa ArgumentError.
  void _checkCategory(TransactionRecord tx) {
    final c = _s.categories.where((c) => c.id == tx.categoryId).firstOrNull;
    if (c == null) {
      throw ArgumentError.value(tx.categoryId, 'categoryId', 'kategori yok');
    }
    if (c.type != tx.type) {
      throw ArgumentError.value(
        tx.categoryId,
        'categoryId',
        'kategori türü işlem türüyle (${tx.type.name}) uyuşmuyor',
      );
    }
  }

  @override
  Future<void> delete(int id) async {
    _s.transactions.removeWhere((t) => t.id == id);
    _s.items.removeWhere((i) => i.transactionId == id);
    for (var i = 0; i < _s.chats.length; i++) {
      final m = _s.chats[i];
      if (m.transactionId == id) {
        _s.chats[i] = ChatMessage(
          id: m.id,
          role: m.role,
          content: m.content,
          createdAt: m.createdAt,
        );
      }
    }
  }

  @override
  Future<TransactionRecord?> getById(int id) async =>
      _s.transactions.where((t) => t.id == id).firstOrNull;

  @override
  Future<List<TransactionRecord>> query({
    DateRange? range,
    int? categoryId,
    TxType? type,
    int? limit,
  }) async {
    final list =
        _s.transactions
            .where((t) => range == null || range.contains(t.date))
            .where((t) => categoryId == null || t.categoryId == categoryId)
            .where((t) => type == null || t.type == type)
            .toList()
          ..sort((a, b) {
            final byDate = b.date.compareTo(a.date);
            if (byDate != 0) return byDate;
            final byCreated = b.createdAt.compareTo(a.createdAt);
            if (byCreated != 0) return byCreated;
            return b.id!.compareTo(a.id!);
          });
    return limit == null ? list : list.take(limit).toList();
  }

  @override
  Future<List<ReceiptItem>> itemsOf(int transactionId) async =>
      _s.items.where((i) => i.transactionId == transactionId).toList();

  @override
  Future<PeriodSummary> summarize(DateRange range) async {
    var income = 0, expense = 0;
    final byExpense = <int, int>{}, byIncome = <int, int>{};
    for (final t in _s.transactions.where((t) => range.contains(t.date))) {
      if (t.type == TxType.income) {
        income += t.amount;
        byIncome.update(
          t.categoryId,
          (v) => v + t.amount,
          ifAbsent: () => t.amount,
        );
      } else {
        expense += t.amount;
        byExpense.update(
          t.categoryId,
          (v) => v + t.amount,
          ifAbsent: () => t.amount,
        );
      }
    }
    return PeriodSummary(
      incomeTotal: income,
      expenseTotal: expense,
      expenseByCategory: byExpense,
      incomeByCategory: byIncome,
    );
  }
}

class FakeCategoryRepository implements CategoryRepository {
  FakeCategoryRepository._(this._s);
  final _Store _s;

  @override
  Future<List<Category>> all({TxType? type}) async =>
      _s.categories.where((c) => type == null || c.type == type).toList();

  @override
  Future<Category?> findByName(String name, TxType type) async {
    final ofType = _s.categories.where((c) => c.type == type);
    return ofType.where((c) => c.name == name).firstOrNull ??
        ofType.where((c) => foldTr(c.name) == foldTr(name)).firstOrNull;
  }

  bool _taken(String name, TxType type, {int? exceptId}) => _s.categories.any(
    (c) => foldTr(c.name) == foldTr(name) && c.type == type && c.id != exceptId,
  );

  @override
  Future<int> add(Category c) async {
    if (_taken(c.name, c.type)) throw DuplicateCategoryException(c.name);
    final id = _s.nextId();
    _s.categories.add(c.copyWith(id: id));
    return id;
  }

  @override
  Future<void> update(Category c) async {
    final stored = _s.categories.where((x) => x.id == c.id).firstOrNull;
    if (stored != null) checkDefaultCategoryUpdate(stored, c);
    if (_taken(c.name, c.type, exceptId: c.id)) {
      throw DuplicateCategoryException(c.name);
    }
    final i = _s.categories.indexWhere((x) => x.id == c.id);
    if (i >= 0) _s.categories[i] = c;
  }

  @override
  Future<void> delete(int id) async {
    final c = _s.categories.where((x) => x.id == id).firstOrNull;
    if (c == null) return;
    if (c.isDefault) {
      throw StateError('Varsayılan kategori silinemez: ${c.name}');
    }
    final fallback = _s.categories.firstWhere(
      (x) => x.isDefault && x.type == c.type && x.name == fallbackCategoryName,
    );
    for (var i = 0; i < _s.transactions.length; i++) {
      if (_s.transactions[i].categoryId == id) {
        _s.transactions[i] = _s.transactions[i].copyWith(
          categoryId: fallback.id,
        );
      }
    }
    _s.budgets.removeWhere((b) => b.categoryId == id);
    _s.categories.removeWhere((x) => x.id == id);
  }
}

class FakeBudgetRepository implements BudgetRepository {
  FakeBudgetRepository._(this._s);
  final _Store _s;

  @override
  Future<List<Budget>> forMonth(String month) async =>
      _s.budgets.where((b) => b.month == month).toList();

  @override
  Future<void> upsert(Budget b) async {
    final i = _s.budgets.indexWhere(
      (x) => x.month == b.month && x.categoryId == b.categoryId,
    );
    if (i >= 0) {
      _s.budgets[i] = _s.budgets[i].copyWith(limitAmount: b.limitAmount);
    } else {
      _s.budgets.add(b.copyWith(id: _s.nextId()));
    }
  }

  @override
  Future<void> delete(int id) async =>
      _s.budgets.removeWhere((b) => b.id == id);
}

class FakeChatMessageRepository implements ChatMessageRepository {
  FakeChatMessageRepository._(this._s);
  final _Store _s;

  @override
  Future<int> add(ChatMessage m) async {
    final id = _s.nextId();
    _s.chats.add(m.copyWith(id: id));
    return id;
  }

  @override
  Future<List<ChatMessage>> all({int? limit}) async {
    final list = [..._s.chats]
      ..sort((a, b) {
        final c = a.createdAt.compareTo(b.createdAt);
        return c != 0 ? c : a.id!.compareTo(b.id!);
      });
    if (limit == null || list.length <= limit) return list;
    return list.sublist(list.length - limit);
  }

  @override
  Future<void> linkTransaction(int messageId, int transactionId) async {
    final i = _s.chats.indexWhere((m) => m.id == messageId);
    if (i >= 0) {
      _s.chats[i] = _s.chats[i].copyWith(transactionId: transactionId);
    }
  }

  @override
  Future<void> clear() async => _s.chats.clear();
}
