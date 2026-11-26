import 'package:cepte_cuzdan/core/models/budget.dart';
import 'package:cepte_cuzdan/core/models/category.dart';
import 'package:cepte_cuzdan/core/models/chat_message.dart';
import 'package:cepte_cuzdan/core/models/default_categories.dart';
import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/core/models/period_summary.dart';
import 'package:cepte_cuzdan/core/models/receipt_item.dart';
import 'package:cepte_cuzdan/core/models/transaction_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final tx = TransactionRecord(
    type: TxType.expense,
    amount: 32000,
    categoryId: 1,
    date: DateTime(2026, 11, 8),
    merchant: 'Migros',
    source: TxSource.receipt,
    receiptPath: '/data/fis.jpg',
    createdAt: DateTime(2026, 11, 8, 14, 30),
  );

  test('TransactionRecord DB sütun adları ve string enum ile map\'lenir', () {
    final m = tx.toMap();
    expect(m['type'], 'expense');
    expect(m['amount'], 32000);
    expect(m['category_id'], 1);
    expect(m['date'], '2026-11-08');
    expect(m['source'], 'receipt');
    expect(m['receipt_path'], '/data/fis.jpg');
    expect(m['created_at'], '2026-11-08T14:30:00.000');
    expect(m.containsKey('id'), isFalse, reason: 'id null ise map\'e yazılmaz');
  });

  test('TransactionRecord map round-trip', () {
    expect(
      TransactionRecord.fromMap({...tx.toMap(), 'id': 5}),
      tx.copyWith(id: 5),
    );
  });

  test('copyWith yalnızca verilen alanı değiştirir', () {
    final c = tx.copyWith(amount: 100);
    expect(c.amount, 100);
    expect(c.merchant, 'Migros');
    expect(c, isNot(tx));
  });

  test('Category round-trip ve is_default 0/1', () {
    const c = Category(
      name: 'Kahve',
      type: TxType.expense,
      color: 0xFF795548,
      icon: 'local_cafe',
    );
    expect(c.toMap()['is_default'], 0);
    expect(c.toMap()['type'], 'expense');
    expect(Category.fromMap({...c.toMap(), 'id': 3}), c.copyWith(id: 3));
  });

  test('ReceiptItem round-trip', () {
    const i = ReceiptItem(
      transactionId: 1,
      name: 'Süt',
      quantity: 2,
      price: 7990,
    );
    expect(ReceiptItem.fromMap({...i.toMap(), 'id': 1}), i.copyWith(id: 1));
    expect(i.toMap()['transaction_id'], 1);
  });

  test('genel bütçe category_id null olarak saklanır', () {
    const b = Budget(month: '2026-11', limitAmount: 1000000);
    expect(b.toMap()['category_id'], isNull);
    expect(b.toMap()['limit_amount'], 1000000);
    expect(Budget.fromMap({...b.toMap(), 'id': 2}), b.copyWith(id: 2));
  });

  test('ChatMessage round-trip', () {
    final m = ChatMessage(
      role: ChatRole.assistant,
      content: 'Kaydedeyim mi?',
      createdAt: DateTime(2026, 11, 8, 9),
    );
    expect(m.toMap()['role'], 'assistant');
    expect(m.toMap()['transaction_id'], isNull);
    expect(ChatMessage.fromMap({...m.toMap(), 'id': 7}), m.copyWith(id: 7));
  });

  test('PeriodSummary bakiye ve boş özet', () {
    const s = PeriodSummary(incomeTotal: 5000000, expenseTotal: 62000);
    expect(s.balance, 4938000);
    expect(PeriodSummary.empty.expenseByCategory, isEmpty);
  });

  test('varsayılan kategoriler rapordaki sırayla', () {
    expect(
      defaultCategories
          .where((c) => c.type == TxType.expense)
          .map((c) => c.name),
      [
        'Market',
        'Ulaşım',
        'Faturalar',
        'Yeme-İçme',
        'Eğlence',
        'Sağlık',
        'Diğer',
      ],
    );
    expect(
      defaultCategories
          .where((c) => c.type == TxType.income)
          .map((c) => c.name),
      ['Maaş', 'Diğer'],
    );
    expect(defaultCategories.every((c) => c.isDefault), isTrue);
  });
}
