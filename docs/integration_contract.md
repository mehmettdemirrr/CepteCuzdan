# Entegrasyon Sözleşmesi (Mehmet ↔ Berkay)

Bu dosya modeller, repository arabirimleri ve asistan modülünün veri katmanına nasıl yazacağını tanımlar. Kod `lib/core/models/` ve `lib/core/repositories/` altında; buradaki her değişiklik iki tarafın onayıyla yapılır. Değişiklik önerisi bu dosyanın sonundaki **Öneriler** bölümüne yazılır.

## Veri kuralları

- Tüm tutarlar **kuruş cinsinden `int`** (DB'de `INTEGER`). 320,00 TL = `32000`.
- TL → kuruş dönüşümü tek noktada: `lib/core/format/money.dart`
  - `tlToKurus(num tl)` – Gemini'nin `320.00` değeri için (`(tl * 100).round()`)
  - `parseTlToKurus(String)` – kullanıcının yazdığı `1.234,50` gibi girişler için
  - `formatKurus(int)` – ekranda `₺1.234,50`
- Tarih: `TransactionRecord.date` günü temsil eder; DB'de `yyyy-MM-dd`. `fromDbDate("2026-11-08")` ile Gemini tarihini `DateTime`'a çevir.
- `TxSource`: `manual`, `receipt`, `voice`, `chat`.
- `TxType`: `income`, `expense` — Gemini JSON'undaki `type` ile birebir (`TxType.values.byName(json['type'])`).

## Modeller (`lib/core/models/`)

| Sınıf | Alanlar |
|---|---|
| `Category` | `id, name, type, color (ARGB int), icon (string anahtar), isDefault` |
| `TransactionRecord` | `id, type, amount (kuruş), categoryId, date, merchant?, note?, source, receiptPath?, createdAt` |
| `ReceiptItem` | `id, transactionId, name, quantity (double), price (satır tutarı, kuruş)` |
| `Budget` | `id, categoryId? (null = aylık genel bütçe), month ('yyyy-MM'), limitAmount` |
| `ChatMessage` | `id, role (user/assistant), content, transactionId?, createdAt` |
| `PeriodSummary` | `incomeTotal, expenseTotal, expenseByCategory, incomeByCategory, balance` |

Hepsinde `toMap()`, `fromMap()`, `copyWith()`, `==` var. Varsayılan kategoriler `defaultCategories` içinde: gider için Market, Ulaşım, Faturalar, Yeme-İçme, Eğlence, Sağlık, Diğer; gelir için Maaş, Diğer.

## Repository arabirimleri (`lib/core/repositories/`)

```dart
abstract class TransactionRepository {
  Future<int> add(TransactionRecord tx, {List<ReceiptItem> items = const []}); // işlem + kalemler tek DB transaction'ı
  Future<void> update(TransactionRecord tx);
  Future<void> delete(int id);              // kalemler silinir, bağlı sohbet mesajının transactionId'si null olur
  Future<TransactionRecord?> getById(int id);
  Future<List<TransactionRecord>> query({DateRange? range, int? categoryId, TxType? type, int? limit}); // en yeni önce
  Future<List<ReceiptItem>> itemsOf(int transactionId);
  Future<PeriodSummary> summarize(DateRange range);   // "Bu ay markete ne kadar harcadım?" buradan
}

abstract class CategoryRepository {
  Future<List<Category>> all({TxType? type});
  Future<Category?> findByName(String name, TxType type); // birebir, sonra büyük/küçük harf duyarsız
  Future<int> add(Category c);       // aynı ad+tip → DuplicateCategoryException
  Future<void> update(Category c);
  Future<void> delete(int id);       // varsayılan → StateError; işlemler aynı tipteki "Diğer"e taşınır
}

abstract class BudgetRepository {
  Future<List<Budget>> forMonth(String month);
  Future<void> upsert(Budget b);     // (categoryId, month) başına tek kayıt
  Future<void> delete(int id);
}

abstract class ChatMessageRepository {
  Future<int> add(ChatMessage m);
  Future<List<ChatMessage>> all({int? limit});  // eskiden yeniye; limit = son N mesaj
  Future<void> linkTransaction(int messageId, int transactionId);
  Future<void> clear();
}
```

Tarih aralıkları için `DateRange`, `monthOf`, `weekOf` (`lib/core/format/dates.dart`). Örnek: bu ayki market harcaması:

```dart
final market = await categories.findByName('Market', TxType.expense);
final s = await txs.summarize(monthOf(DateTime.now()));
final kurus = s.expenseByCategory[market!.id] ?? 0;
```

## Asistan modülü kayıt akışı

1. Gemini JSON'u doğrulanır (Berkay).
2. Kategori: `await categories.findByName(json['category'], type) ?? await categories.findByName('Diğer', type)`.
3. Kayıt nesnesi: `amount: tlToKurus(json['amount'])`, `date: fromDbDate(json['date'])`, `source: TxSource.receipt / voice / chat`, kalemler `ReceiptItem(name, quantity, price: tlToKurus(satırTutarı))`.
4. Onay kartında **Kaydet**: `context.read<TransactionProvider>().add(tx, items: items)`.
   `TransactionProvider` (`lib/features/transactions/transaction_provider.dart`) repository'yi sarar; kayıttan sonra Dashboard/Rapor yenilenir ve bütçe uyarısı kontrol edilir. Repository'ye doğrudan yazmayın.
5. Onay kartındaki **Düzenle** için istersen `TransactionFormScreen(initial: taslak)` açılabilir: `id`'si olmayan bir taslak verilirse form yeni kayıt ekler ve `source`'u korur. Fiş kalemlerini form taşımaz; kalemli kayıtlar için kendi düzenleme akışın gerekir.

## Bağımlılık ağacı

- `lib/app/providers.dart` → `buildProviders(deps: AppDeps, child: ...)`. Repository'ler `Provider<XRepository>`, `TransactionProvider` ve `CategoryProvider` `ChangeNotifierProvider` olarak sağlanır. Asistan provider'larını listenin sonuna ekle; `context.read<ChatMessageRepository>()` ile sohbet repository'sine ulaşılır.
- Asistan sekmesi: `lib/app/app.dart` içindeki `_ComingSoon('Asistan')` satırı.

## Dikkat: `Category` ad çakışması

`package:flutter/foundation.dart` da `Category` adında bir annotation dışa aktarıyor. `foundation.dart`'ı tamamen içe aktaran bir dosyada modeldeki `Category` ile çakışır. Çözüm: `import 'package:flutter/foundation.dart' show ChangeNotifier;` gibi `show` ile içe aktar. `material.dart` çakışmaz.

## Testler

- `test/fakes/fake_repositories.dart`: `FakeRepos()` dört repository'nin bellek içi sürümünü verir (varsayılan kategoriler id 1–9).
- `test/helpers/pump_app.dart`: `pumpApp(tester, widget, deps: TestDeps())` uygulamanın tema, Türkçe yerelleştirme ve provider ağacını fake'lerle kurar (360×800 telefon ekranı).
- Fake'ler ve SQLite implementasyonu aynı sözleşme testinden geçer: `test/core/repositories/repository_contract.dart`.

## Açık kararlar (Berkay onayı bekleniyor)

- [ ] Gelir için varsayılan kategoriler `Maaş` ve `Diğer`.
- [ ] `ReceiptItem.price` = satır tutarı (miktar × birim fiyat), kuruş.
- [ ] Tema tohum rengi `#00897B`.

## Öneriler

_(Sözleşme değişikliği önerileri buraya: tarih, öneren, gerekçe.)_
