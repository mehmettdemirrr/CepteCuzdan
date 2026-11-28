# CepteCüzdan – Mehmet'in Kısmı: Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mehmet'e düşen altyapı, SQLite veri katmanı, Manuel İşlem, Dashboard, Raporlama ve Ayarlar modüllerini `mehmet` branch'inde geliştirip 17 Aralık 2026 teslimine hazırlamak.

**Architecture:** Flutter + provider ile üç katman. Ekranlar (`lib/features/*`) yalnızca ChangeNotifier provider'larla konuşur. Provider'lar soyut repository arabirimlerini kullanır, SQLite implementasyonları `lib/core/db` altındadır. Berkay'ın asistan modülü aynı sözleşmeyi (`TransactionProvider.add`, `CategoryRepository.findByName`) kullanarak kayıt yazar.

**Tech Stack:** Flutter (Dart), sqflite, provider, fl_chart, intl + flutter_localizations, flutter_local_notifications, shared_preferences. Testlerde flutter_test ve sqflite_common_ffi (bellek içi SQLite) kullanılır.

**Spec:** `docs/CepteCüzdan – AI Destekli Akıllı Bütçe Asistanı Proje Raporu.pdf` ve `docs/CepteCüzdan – İş Bölümü ve Proje Takvimi.pdf`. İkisi de Task 0'da repoya kopyalanır.

---

## Durum ve sıkıştırılmış takvim

Bugün 25 Kasım Çarşamba, orijinal takvimin 3. haftası. Normalde 1. ve 2. haftanın işleri bitmiş olmalıydı ama proje şimdi başlıyor. Teslime 22 gün, 6 Aralık'taki feature freeze'e 11 gün var. 29 Kasım kilometre taşı (fişten uçtan uca kayıt) Mehmet'in repository'sine bağlı. Bu yüzden sözleşme ve veritabanı **ilk iki günde** main'e girmeli.

| Tarih | Mehmet | Berkay'a etkisi |
|---|---|---|
| 25 Kas Çar | Task 0–2: repo/branch, iskelet, biçim yardımcıları. Akşam Berkay ile sözleşme görüşmesi | İskelet main'e girer, Berkay main'i kendi dalına alır |
| 26 Kas Per | Task 3–4: sözleşme + SQLite → **PR② main** | Onay kartı gerçek repository'ye yazabilir |
| 27–28 Kas | Task 5–7: tema/ortak bileşenler, provider'lar, Manuel İşlem | Ortak bileşenleri kullanır |
| 26–28 Kas | **Ek:** Görev 14–16: ekran durumu testleri, yatay/küçük/geniş ekran uyumu, erişilebilirlik | Asistan ekranları aynı kurallarla yazılır |
| 29 Kas Cmt | **PR③ main** + fişten uçtan uca kayıt denemesi (ortak) | Kilometre taşı 1 |
| 30 Kas Paz | Task 8: bütçe hesapları ve bildirim servisi | — |
| 1–2 Ara | Task 9: Dashboard → **PR④ main** | — |
| 3–4 Ara | Task 10: Raporlar | — |
| 5–6 Ara | Task 11: Ayarlar ve bütçe limitleri → **PR⑤ main**. **Feature freeze** | Kilometre taşı 2 |
| 7–13 Ara | Task 12: entegrasyon, cihaz testleri, hata düzeltme | Ortak |
| 14–17 Ara | Task 13: APK, raporun son hali, demo | Teslim 17 Ara |

**Geride kalınırsa kesme sırası** (en önce kesilecek olan başta):
1. Para birimi görünüm ayarı (sadece ₺ kalır)
2. Raporda özel tarih aralığı (hafta/ay ve kategori filtresi kalır)
3. Kategori ikon seçici (sabit ikon kalır, sadece renk seçilir)
4. Dashboard'daki gelir-gider çubuğu (yerine metin)

Raporlarda yalnızca çubuk grafik var; çizgi grafik vakit kalırsa eklenir.

## Branch stratejisi

- `main`: her zaman derlenen ve ikinizin birleştiği dal. Doğrudan commit atılmaz, değişiklik PR ile girer.
- `mehmet`: Mehmet'in kişisel çalışma dalı (Berkay'ınkine paralel).
- PR noktaları (`mehmet` → `main`): ① iskelet (25 Kas), ② sözleşme + DB (26 Kas), ③ tema + Manuel İşlem (29 Kas), ④ Dashboard (2 Ara), ⑤ Rapor + Ayarlar (6 Ara). Her PR'dan sonra Berkay main'i kendi dalına merge eder.

Her gün başında:

```powershell
git switch mehmet; git pull; git fetch origin; git merge origin/main
```

Gün sonunda:

```powershell
git push
```

PR için GitHub'daki "Compare & pull request" düğmesini ya da `gh pr create --base main --head mehmet` komutunu kullanın.

**Dosya sahipliği** (çakışmayı önlemek için):

| Yol | Sahip |
|---|---|
| `lib/main.dart`, `lib/app/**` | Mehmet. Berkay sadece `app.dart`'taki Asistan sekmesi satırını ve `providers.dart`'a kendi provider satırlarını ekler |
| `lib/core/models/**`, `lib/core/repositories/*_repository.dart` | **Sözleşme.** Mehmet yazar, Berkay PR'da onaylar. Sonradan değişiklik ikisinin onayıyla yapılır |
| `lib/core/db/**`, `lib/core/format/**` | Mehmet |
| `lib/core/ui/**`, `test/fakes/**`, `test/helpers/**` | Ortak (ilk sürümü Mehmet yazar) |
| `lib/features/{transactions,dashboard,budget,reports,settings}/**` | Mehmet |
| `lib/features/assistant/**` | Berkay |
| `pubspec.yaml`, `android/**`, `ios/**` | Herkes kendi paketini ve iznini ekler. Çakışmada iki tarafın satırları da korunur |

## Global Constraints

- Tutarlar her yerde kuruş cinsinden `int`, DB'de `INTEGER`. TL↔kuruş dönüşümü yalnızca `lib/core/format/money.dart` içinde yapılır.
- Arayüz Türkçe, locale `tr_TR`. Tutar biçimi `₺1.234,50`, tarih biçimi `25 Kas 2026` ya da `25.11.2026`.
- İşlem tarihi DB'de `TEXT 'yyyy-MM-dd'` (yerel gün), `created_at` ISO-8601, bütçe ayı `'yyyy-MM'` olarak tutulur.
- Varsayılan gider kategorileri (birebir): Market, Ulaşım, Faturalar, Yeme-İçme, Eğlence, Sağlık, Diğer. **Karar:** Gelir işlemi de kategori istediği için `Maaş` ve `Diğer` adında iki varsayılan gelir kategorisi eklenir.
- `source` değerleri: `manual`, `receipt`, `voice`, `chat`.
- Bildirim eşikleri: harcama ≥ limitin %80'i ise uyarı, harcama > limit ise aşım bildirimi.
- İndeksler: `transactions(date)`, `transactions(category_id)`.
- Ekranlar DB'ye ve repository'ye doğrudan erişmez, yalnızca provider kullanır.
- Mehmet'in modülleri internet olmadan çalışır ve hiç ağ çağrısı yapmaz.
- Kategori ikonu DB'de string anahtar olarak tutulur. `IconData` sabit bir map'ten okunur, çünkü dinamik `IconData(codePoint)` release build'deki icon tree-shaking'i bozar.
- 6 Aralık'tan sonra yeni özellik eklenmez.
- **Ekran uyumu (hoca zorunlu):** her ekran dikey 360×800, küçük 320×568, **yatay 800×360**, geniş 1280×800 ve 2,0× yazı ölçeğinde taşmadan çalışır. Genişlik ≥ 600 dp'de yan gezinme (`NavigationRail`).
- **Erişilebilirlik:** dokunma alanı ≥ 48 dp, ikon düğmelerinde tooltip, grafiklerde `Semantics` özeti, açık/koyu temada kontrast testleri.
- **Geliştirme kuralları:** `docs/gelistirme-kurallari.md` iki geliştirici için bağlayıcıdır; her PR öncesi kontrol listesi geçilir.

## Review Focus

1. **Türkçe tutar girişi:** `1.234,50`, `150`, `150,5`, `12.50`, ` 150 `, `0`, `-5`, `abc` ve boş giriş denenir. İlk beş geçerli sayılmalı, kalanlar reddedilmeli. Testi Task 2'de.
2. **Ay, hafta ve yıl sınırları:** 30 Kasım ve 1 Aralık işlemleri farklı aylara düşmeli. Hafta Pazartesi başlar. Ocak'tan önceki ay, önceki yılın Aralık'ıdır. Testleri Task 2 ve Task 4'te.
3. **Bildirim spam'i:** %80 geçildikten sonra her yeni harcama yeni bildirim üretmemeli. Aynı (ay, kategori, seviye) için tek bildirim gider. Testi Task 8'de.
4. **İşlemi olan kategoriyi silme:** İşlemler kaybolmaz, aynı tipteki "Diğer"e taşınır. Varsayılan kategori silinemez. Testi Task 4'te.
5. **İlk açılış, boş veri:** İşlem ve bütçe yokken Dashboard çökmemeli. Pasta grafiğin yerinde boş durum, kalan bütçe yerinde "Bütçe tanımlanmadı" görünmeli. Testi Task 9'da.

---

### Task 0: Repo, branch ve Berkay'ın dalının kontrolü

Bu adımda kod yazılmaz.

- [ ] **Step 1: Repoyu klonla**

```powershell
git clone https://github.com/<kullanici>/<repo>.git C:\Users\mehmet\CepteCuzdan
```

- [ ] **Step 2: Dalları ve Berkay'ın dalındakileri incele**

```powershell
cd C:\Users\mehmet\CepteCuzdan; git fetch --all; git branch -a; git log --oneline --graph --all -20
```

```powershell
git diff --stat origin/main origin/<berkay-dali>
```

Çıkan sonuca göre karar ver:
- Berkay'ın dalında `pubspec.yaml` **yoksa** iskeleti Task 1'de sen kurarsın (normal yol).
- **Varsa** ikinci bir Flutter projesi kurma. Berkay iskelet commit'ini PR ile main'e alsın, sen main'den dallan. Task 1'de yalnızca eksik olanları ekle (`app/`, shell, locale).

- [ ] **Step 3: Kendi dalını aç ve GitHub'a gönder**

```powershell
git switch main; git pull; git switch -c mehmet; git push -u origin mehmet
```

- [ ] **Step 4:** İki PDF'i `docs/` altına, bu planı `docs/plans/` altına kopyala. Ardından `git add docs; git commit -m "docs: proje raporu, iş bölümü ve Mehmet planı"`.
- [ ] **Step 5:** `flutter doctor` çalıştır. Beklenen sonuç: Flutter ve Android toolchain ✓.

---

### Task 1: Proje iskeleti ve uygulama kabuğu

**Files:**
- Create: `flutter create` çıktısı, `lib/main.dart`, `lib/app/app.dart`, `lib/app/shell.dart`
- Test: `test/app/shell_test.dart`

**Interfaces:**
- Produces: `class CepteCuzdanApp extends StatelessWidget`. Bu bir MaterialApp'tir: `locale: Locale('tr','TR')`, `GlobalMaterialLocalizations` delegeleri ve `home: AppShell(pages: ...)` içerir.
- Produces: `class AppShell extends StatefulWidget { const AppShell({required List<Widget> pages}); }`. 4 sekmeli bir `NavigationBar` gösterir, etiketleri: "Ana Sayfa", "Asistan", "İşlemler", "Raporlar". Sekmeler `IndexedStack` içinde tutulur. Asistan sekmesi Berkay'ın ekranı gelene kadar `Center(child: Text('Asistan yakında'))` gösterir.

- [ ] **Step 1: Projeyi oluştur** (repo kökünde)

```powershell
flutter create --org com.ceptecuzdan --project-name cepte_cuzdan --platforms android,ios .
```

- [ ] **Step 2: Paketleri ekle** (sıra önemli: intl, flutter_localizations'ın sabitlediği sürüme uymalı)

```powershell
flutter pub add flutter_localizations --sdk=flutter
```

```powershell
flutter pub add provider sqflite path fl_chart intl shared_preferences flutter_local_notifications
```

```powershell
flutter pub add --dev sqflite_common_ffi
```

- [ ] **Step 3: Başarısız testi yaz**

```dart
testWidgets('kabuk 4 sekmeyi gösterir ve sekme değiştirir', (t) async {
  await t.pumpWidget(MaterialApp(home: AppShell(pages: [
    for (final k in ['home', 'assistant', 'transactions', 'reports'])
      Placeholder(key: Key('tab-$k')),
  ])));
  for (final l in ['Ana Sayfa', 'Asistan', 'İşlemler', 'Raporlar']) {
    expect(find.text(l), findsOneWidget);
  }
  await t.tap(find.text('Raporlar'));
  await t.pumpAndSettle();
  expect(find.byKey(const Key('tab-reports')).hitTestable(), findsOneWidget);
});
```

- [ ] **Step 4:** `flutter test test/app/shell_test.dart` çalıştır. Beklenen: FAIL (`AppShell` tanımlı değil).
- [ ] **Step 5:** `AppShell`, `CepteCuzdanApp` ve `main.dart`'ı yaz. `main()` sırasıyla `WidgetsFlutterBinding.ensureInitialized()`, `await initializeDateFormatting('tr_TR')` ve `Intl.defaultLocale = 'tr_TR'` çağırır.
- [ ] **Step 6:** `flutter test test/app/shell_test.dart` → PASS. `flutter analyze` → `No issues found!`
- [ ] **Step 7:** Commit (`feat: Flutter iskeleti ve 4 sekmeli kabuk`), push, **PR① → main**. Berkay'a haber ver.

---

### Task 2: Para ve tarih yardımcıları

**Files:**
- Create: `lib/core/format/money.dart`, `lib/core/format/dates.dart`
- Test: `test/core/format/money_test.dart`, `test/core/format/dates_test.dart`

**Interfaces:**
- Produces (Berkay da kullanır):

```dart
enum CurrencyStyle { symbol, code }            // ₺1.234,50 | 1.234,50 TL
String formatKurus(int kurus, {CurrencyStyle style = CurrencyStyle.symbol});
int? parseTlToKurus(String input);             // geçersizse ya da <= 0 ise null
int tlToKurus(num tl);                         // (tl * 100).round(); Gemini'nin 320.00 değeri için

class DateRange {                              // gün bazında, iki uç da dahil; == ve hashCode uygular
  const DateRange(this.start, this.end);
  final DateTime start, end;
  bool contains(DateTime d);
}
DateRange monthOf(DateTime d);
DateRange weekOf(DateTime d);                  // Pazartesi–Pazar
DateRange previousOf(DateRange r);             // takvim ayıysa önceki takvim ayı, değilse aynı uzunlukta hemen önceki aralık
String toDbDate(DateTime d);                   // 'yyyy-MM-dd'
DateTime fromDbDate(String s);
String monthKey(DateTime d);                   // 'yyyy-MM'
```

`parseTlToKurus` kuralı: Önce boşluklar kırpılır. Hem `.` hem `,` varsa `.` binlik ayırıcı, `,` ondalıktır. Sadece `,` varsa `,` ondalıktır. Sadece `.` varsa ve son `.`'dan sonra 1–2 hane kalıyorsa `.` ondalık, aksi halde binlik sayılır. Android'in sayısal klavyesi bazen yalnızca `.` gösterdiği için bu kural gerekli.

- [ ] **Step 1: Başarısız testleri yaz**

```dart
expect(formatKurus(123450), '₺1.234,50');
expect(formatKurus(123450, style: CurrencyStyle.code), '1.234,50 TL');
expect(formatKurus(-5000), '-₺50,00');
expect(parseTlToKurus('1.234,50'), 123450);
expect(parseTlToKurus('150'), 15000);
expect(parseTlToKurus('150,5'), 15050);
expect(parseTlToKurus('12.50'), 1250);
expect(parseTlToKurus('1.234'), 123400);
expect(parseTlToKurus(' 150 '), 15000);
for (final bad in ['0', '-5', 'abc', '', '1,2,3']) {
  expect(parseTlToKurus(bad), isNull, reason: bad);
}
expect(tlToKurus(19.99), 1999);

expect(weekOf(DateTime(2026, 11, 25)), DateRange(DateTime(2026, 11, 23), DateTime(2026, 11, 29)));
expect(monthOf(DateTime(2026, 11, 30)).end, DateTime(2026, 11, 30));
expect(monthOf(DateTime(2026, 11, 30)).contains(DateTime(2026, 12, 1)), isFalse);
expect(previousOf(monthOf(DateTime(2026, 1, 15))), DateRange(DateTime(2025, 12, 1), DateTime(2025, 12, 31)));
expect(previousOf(DateRange(DateTime(2026, 11, 10), DateTime(2026, 11, 16))),
    DateRange(DateTime(2026, 11, 3), DateTime(2026, 11, 9)));
expect(toDbDate(DateTime(2026, 11, 8, 23, 59)), '2026-11-08');
expect(monthKey(DateTime(2026, 1, 3)), '2026-01');
```

- [ ] **Step 2:** `flutter test test/core/format` → FAIL.
- [ ] **Step 3:** Yaz. Biçimlendirme `NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2)` ile yapılır. intl'in çıktısında ₺ önde değilse, testteki `₺1.234,50` biçimine uyacak şekilde düzelt.
- [ ] **Step 4:** `flutter test test/core/format` → PASS.
- [ ] **Step 5:** Commit (`feat(format): TL/kuruş ve tarih aralığı yardımcıları`).

---

### Task 3: Arayüz sözleşmesi – modeller ve repository arabirimleri (Berkay ile birlikte)

**Files:**
- Create: `lib/core/models/{enums,category,transaction_record,receipt_item,budget,chat_message,period_summary,default_categories}.dart`
- Create: `lib/core/repositories/{transaction,category,budget,chat_message}_repository.dart`
- Create: `test/fakes/fake_repositories.dart` (bellek içi; widget testlerinde ikiniz de kullanırsınız)
- Test: `test/core/models/models_test.dart`

**Interfaces:**
- Consumes: Task 2'deki `toDbDate`, `fromDbDate`, `DateRange`.
- Produces (sözleşme; isimler birebir kullanılmalı):

```dart
enum TxType { income, expense }
enum TxSource { manual, receipt, voice, chat }
enum ChatRole { user, assistant }

class Category { int? id; String name; TxType type; int color /*ARGB*/; String icon /*categoryIcons anahtarı*/; bool isDefault; }
class TransactionRecord { int? id; TxType type; int amount /*kuruş, >0*/; int categoryId; DateTime date;
  String? merchant; String? note; TxSource source; String? receiptPath; DateTime createdAt; }
class ReceiptItem { int? id; int? transactionId; String name; double quantity; int price /*satır tutarı, kuruş*/; }
class Budget { int? id; int? categoryId /*null = aylık genel bütçe*/; String month /*'yyyy-MM'*/; int limitAmount /*kuruş*/; }
class ChatMessage { int? id; ChatRole role; String content; int? transactionId; DateTime createdAt; }
class PeriodSummary { int incomeTotal; int expenseTotal; Map<int, int> expenseByCategory; Map<int, int> incomeByCategory; int get balance; }
const List<Category> defaultCategories; // 7 gider + Maaş, Diğer (gelir); icon anahtarları: shopping_cart, directions_bus, receipt_long, restaurant, movie, local_hospital, category, payments, savings
```

Bütün alanlar `final`. Her modelde `toMap()`, `fromMap()`, `copyWith()`, `==` ve `hashCode` bulunur. Map anahtarları rapordaki sütun adlarıdır (`category_id`, `receipt_path`, `created_at`, `limit_amount`...). Enum'lar `.name` ile string olarak saklanır.

```dart
abstract class TransactionRepository {
  Future<int> add(TransactionRecord tx, {List<ReceiptItem> items = const []}); // tek DB transaction'ı
  Future<void> update(TransactionRecord tx);
  Future<void> delete(int id);                                                   // fiş kalemleri de silinir
  Future<TransactionRecord?> getById(int id);
  Future<List<TransactionRecord>> query({DateRange? range, int? categoryId, TxType? type, int? limit}); // date DESC, created_at DESC
  Future<List<ReceiptItem>> itemsOf(int transactionId);
  Future<PeriodSummary> summarize(DateRange range);                              // tek GROUP BY sorgusu
}
abstract class CategoryRepository {
  Future<List<Category>> all({TxType? type});
  Future<Category?> findByName(String name, TxType type); // önce birebir eşleşme, sonra büyük/küçük harf duyarsız
  Future<int> add(Category c);                            // aynı ad+tip varsa DatabaseException
  Future<void> update(Category c);
  Future<void> delete(int id);                            // varsayılan kategoride StateError; işlemleri aynı tipteki 'Diğer'e taşır
}
abstract class BudgetRepository {
  Future<List<Budget>> forMonth(String month);
  Future<void> upsert(Budget b);                          // aynı (categoryId, month) varsa günceller; categoryId null için de tekil
  Future<void> delete(int id);
}
abstract class ChatMessageRepository {
  Future<int> add(ChatMessage m);
  Future<List<ChatMessage>> all({int? limit});            // created_at ASC
  Future<void> linkTransaction(int messageId, int transactionId);
  Future<void> clear();
}
```

**Berkay için kullanım kuralları** (PR açıklamasına da yazılacak):
- Onay kartındaki "Kaydet" `context.read<TransactionProvider>().add(tx, items: items)` çağırır (Task 6). Repository'ye doğrudan yazılmaz; böylece Dashboard yenilenir ve bütçe uyarısı tetiklenir.
- Gemini'den gelen `category` için `findByName(name, type) ?? findByName('Diğer', type)` kullanılır.
- `amount` için `tlToKurus(amount)`, `date` için `fromDbDate(date)`, `items[].price` için satır tutarı (`tlToKurus`) kullanılır.

- [ ] **Step 1: Başarısız testi yaz**

```dart
final tx = TransactionRecord(type: TxType.expense, amount: 32000, categoryId: 1,
    date: DateTime(2026, 11, 8), merchant: 'Migros', source: TxSource.receipt,
    createdAt: DateTime(2026, 11, 8, 14, 30));
expect(tx.toMap()['type'], 'expense');
expect(tx.toMap()['date'], '2026-11-08');
expect(tx.toMap()['source'], 'receipt');
expect(TransactionRecord.fromMap({...tx.toMap(), 'id': 5}), tx.copyWith(id: 5));
expect(Budget(month: '2026-11', limitAmount: 1000000).toMap()['category_id'], isNull);
expect(defaultCategories.where((c) => c.type == TxType.expense).map((c) => c.name),
    ['Market', 'Ulaşım', 'Faturalar', 'Yeme-İçme', 'Eğlence', 'Sağlık', 'Diğer']);
```

- [ ] **Step 2:** `flutter test test/core/models` → FAIL.
- [ ] **Step 3:** Modelleri ve arabirimleri yaz. Ardından `test/fakes/fake_repositories.dart` içine liste tabanlı `FakeTransactionRepository`, `FakeCategoryRepository.seeded()` (defaultCategories, id 1..9), `FakeBudgetRepository` ve `FakeChatMessageRepository` sınıflarını yaz. Fake'ler SQLite implementasyonuyla aynı kuralları uygular (silmede "Diğer"e taşıma, upsert tekilliği).
- [ ] **Step 4:** `flutter test test/core/models` → PASS.
- [ ] **Step 5:** Commit (`feat(core): model ve repository sözleşmesi`). PR②'yi Task 4 ile birlikte aç ve **Berkay'dan review iste.**

---

### Task 4: SQLite veritabanı ve repository implementasyonları

**Files:**
- Create: `lib/core/db/app_database.dart`, `lib/core/db/sqlite_{transaction,category,budget,chat_message}_repository.dart`
- Create: `test/core/db/test_db.dart`
- Test: `test/core/db/{schema,transaction_repository,category_repository,budget_repository,chat_message_repository}_test.dart`

**Interfaces:**
- Consumes: Task 3'teki modeller ve arabirimler, Task 2'deki `toDbDate` ve `DateRange`.
- Produces: `class AppDatabase { static Future<Database> open({DatabaseFactory? factory, String path = 'ceptecuzdan.db'}); }`. `onConfigure` içinde `PRAGMA foreign_keys = ON` çalışır. `onCreate` aşağıdaki şemayı kurar ve `defaultCategories`'i ekler; `version: 1`.
- Produces: `SqliteXRepository(Database db) implements XRepository` (dört repository için).
- Produces (test yardımcısı): `Future<Database> openTestDb()`. Sırasıyla `sqfliteFfiInit()` ve `AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath)` çağırır. Her test `tearDown`'da `db.close()` yapar.

Şema (rapordaki tablolar, eklenen kısıtlar burada sabitlenir):

```sql
CREATE TABLE categories(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
  type TEXT NOT NULL CHECK(type IN ('income','expense')), color INTEGER NOT NULL, icon TEXT NOT NULL,
  is_default INTEGER NOT NULL DEFAULT 0, UNIQUE(name, type));
CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL CHECK(type IN ('income','expense')), amount INTEGER NOT NULL CHECK(amount > 0),
  category_id INTEGER NOT NULL REFERENCES categories(id), date TEXT NOT NULL, merchant TEXT, note TEXT,
  source TEXT NOT NULL CHECK(source IN ('manual','receipt','voice','chat')), receipt_path TEXT,
  created_at TEXT NOT NULL);
CREATE INDEX idx_transactions_date ON transactions(date);
CREATE INDEX idx_transactions_category ON transactions(category_id);
CREATE TABLE receipt_items(id INTEGER PRIMARY KEY AUTOINCREMENT,
  transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  name TEXT NOT NULL, quantity REAL NOT NULL DEFAULT 1, price INTEGER NOT NULL);
CREATE TABLE budgets(id INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id INTEGER REFERENCES categories(id) ON DELETE CASCADE, month TEXT NOT NULL,
  limit_amount INTEGER NOT NULL CHECK(limit_amount > 0));
CREATE TABLE chat_messages(id INTEGER PRIMARY KEY AUTOINCREMENT,
  role TEXT NOT NULL CHECK(role IN ('user','assistant')), content TEXT NOT NULL,
  transaction_id INTEGER REFERENCES transactions(id) ON DELETE SET NULL, created_at TEXT NOT NULL);
```

`summarize` sorgusu: `SELECT type, category_id, SUM(amount) AS total FROM transactions WHERE date BETWEEN ? AND ? GROUP BY type, category_id`.

- [ ] **Step 1: Başarısız testleri yaz** (test adı → beklenti)
  - `açılışta 5 tablo ve 2 indeks oluşur` → `sqlite_master` içinde 5 tablo adı, `idx_transactions_date` ve `idx_transactions_category` bulunur.
  - `varsayılan kategoriler eklenir` → `all(type: expense)` 7 kayıt döner, adları rapordaki sırayla. `all(type: income)` 2 kayıt döner. Hepsinde `isDefault == true`.
  - `foreign key açık` → `category_id: 999` ile `add` çağrısı `throwsA(isA<DatabaseException>())`.
  - `add fiş kalemleriyle kaydeder` → 2 kalemle eklenince `itemsOf(id).length == 2`.
  - `delete fiş kalemlerini de siler` → silindikten sonra `itemsOf(id)` boş, `getById(id)` null.
  - `update tutarı değiştirir` → `getById(id)!.amount == 20000`.
  - `query aralığın iki ucunu da dahil eder` → 30 Kasım ve 1 Aralık tarihli iki işlem var. `query(range: monthOf(DateTime(2026,11,1)))` yalnızca 30 Kasım işlemini döner.
  - `query kategori ve tip filtresi ile en yeni önce sıralar`
  - `summarize toplamları doğru hesaplar` → Maaş 5000000 gelir, Market 32000 + 15000, Ulaşım 15000. Beklenen: `expenseTotal == 62000`, `expenseByCategory[marketId] == 47000`, `balance == 4938000`.
  - `varsayılan kategori silinemez` → `throwsStateError`.
  - `kategori silinince işlemleri Diğer'e taşınır` → işlemin `categoryId`'si gider tipindeki "Diğer"in id'si olur.
  - `findByName büyük küçük harf duyarsız` → `findByName('market', TxType.expense)?.name == 'Market'`, `findByName('Yok', TxType.expense) == null`.
  - `genel bütçe upsert tekrarlanmaz` → `categoryId: null` ile iki kez `upsert` yapılınca `forMonth('2026-11').length == 1` olur ve ikinci limit geçerlidir.
  - `kategori silinince bütçe limiti de silinir`
  - `işlem silinince sohbet mesajının transaction_id'si null olur`
- [ ] **Step 2:** `flutter test test/core/db` → FAIL.
- [ ] **Step 3:** `AppDatabase` ve dört repository'yi yaz. `add` (kalemlerle birlikte) ve kategori silme işlemi `db.transaction` içinde çalışır. Windows'ta "sqlite3.dll bulunamadı" hatası çıkarsa sqflite_common_ffi README'sindeki Windows adımını uygula.
- [ ] **Step 4:** `flutter test test/core/db` → PASS.
- [ ] **Step 5:** Commit (`feat(db): SQLite şeması ve repository'ler`), push, **PR② (Task 3+4) → main. Hedef: 26 Kasım akşamı.** Geliştirme sırasında şema değişirse `version` artırılır ya da emülatördeki uygulama silinip yeniden kurulur.

---

### Task 5: Tema ve ortak bileşenler (Ortak)

**Files:**
- Create: `lib/core/ui/app_theme.dart`, `lib/core/ui/category_icons.dart`, `lib/core/ui/widgets/{amount_text,category_avatar,empty_state}.dart`
- Create: `test/helpers/pump_app.dart`
- Test: `test/core/ui/widgets_test.dart`

**Interfaces:**
- Consumes: `formatKurus`, `TxType`, `Category`, `defaultCategories`.
- Produces:

```dart
class AppTheme { static ThemeData light(); static ThemeData dark(); } // Material 3, ColorScheme.fromSeed(seedColor: Color(0xFF00897B)); renk Berkay ile onaylanır
class MoneyColors extends ThemeExtension<MoneyColors> { final Color income, expense; } // iki temada da tanımlı
const Map<String, IconData> categoryIcons;  // defaultCategories anahtarları + en az 8 ek seçenek
IconData iconFor(String key);               // bilinmeyen anahtar → Icons.category
const List<Color> categoryPalette;          // 10 renk
class AmountText extends StatelessWidget { const AmountText(this.kurus, {this.type, this.style}); } // gider '-' önekli ve expense renginde, gelir '+' önekli ve income renginde
class CategoryAvatar extends StatelessWidget { const CategoryAvatar(this.category, {this.size = 40}); }
class EmptyState extends StatelessWidget { const EmptyState({required this.icon, required this.message, this.action}); }
Future<void> pumpApp(WidgetTester t, Widget child); // MaterialApp + AppTheme.light + tr locale
```

- [ ] **Step 1: Başarısız testleri yaz**
  - `AmountText gideri eksi ve gider renginde gösterir` → `find.text('-₺150,00')` bulunur ve metin rengi `MoneyColors.expense` olur.
  - `bilinmeyen ikon anahtarı varsayılana düşer` → `iconFor('yok') == Icons.category`.
  - `tüm varsayılan kategori ikonları kayıtlı` → `defaultCategories` içindeki her `c.icon` için `categoryIcons.containsKey(c.icon)` true döner.
- [ ] **Step 2:** `flutter test test/core/ui` → FAIL.
- [ ] **Step 3:** Yaz. `app.dart`'ta `theme: AppTheme.light()` ve `darkTheme: AppTheme.dark()` ayarla.
- [ ] **Step 4:** `flutter test test/core/ui` → PASS.
- [ ] **Step 5:** Commit (`feat(ui): tema ve ortak bileşenler`).

---

### Task 6: Provider katmanı ve bağlama

**Files:**
- Create: `lib/features/transactions/transaction_provider.dart`, `lib/features/transactions/category_provider.dart`, `lib/app/providers.dart`
- Modify: `lib/main.dart`, `test/helpers/pump_app.dart`
- Test: `test/features/transactions/transaction_provider_test.dart`

**Interfaces:**
- Consumes: repository arabirimleri, `AppDatabase.open`, Sqlite repository'ler, fake'ler.
- Produces (Berkay onay kartında kullanır):

```dart
class TransactionProvider extends ChangeNotifier {
  TransactionProvider(TransactionRepository repo, {Future<void> Function(DateTime date)? onChanged});
  int get revision;                // her başarılı değişiklikte +1; Dashboard ve Rapor bunu dinler
  Future<int> add(TransactionRecord tx, {List<ReceiptItem> items = const []});
  Future<void> update(TransactionRecord tx);   // tarih ay değiştirirse onChanged hem eski hem yeni tarih için çağrılır
  Future<void> delete(int id);
  Future<List<TransactionRecord>> query({DateRange? range, int? categoryId, TxType? type, int? limit});
  void markChanged();              // dışarıdan veri değişince (bütçe kaydı, sıfırlama) revision++ ve notify
}
class CategoryProvider extends ChangeNotifier {
  CategoryProvider(CategoryRepository repo);
  List<Category> get categories; List<Category> ofType(TxType t); Category? byId(int id);
  Future<void> load(); Future<void> add(Category c); Future<void> update(Category c); Future<void> delete(int id);
}
Widget buildProviders({required Database db, required SharedPreferences prefs, required Widget child});
// Repository'leri Provider<XRepository>, provider'ları ChangeNotifierProvider olarak sağlar; Berkay kendi provider'larını buraya ekler
class TestDeps { TestDeps(); final FakeTransactionRepository txs; final FakeCategoryRepository categories; final FakeBudgetRepository budgets; final FakeChatMessageRepository chats; }
Future<void> pumpApp(WidgetTester t, Widget child, {TestDeps? deps}); // deps verilirse aynı provider ağacını fake'lerle kurar
```

- [ ] **Step 1: Başarısız testleri yaz**
  - `add dinleyicileri bilgilendirir ve revision artar` → dinleyici 1 kez çağrılır, `revision == 1`.
  - `update işlem ayını değiştirince onChanged iki ay için çağrılır` → çağrılan tarihlerin ayları `{'2026-11', '2026-12'}`.
  - `ofType yalnızca o tipi döner` → `ofType(TxType.income).map((c) => c.name)` sonucu `['Maaş', 'Diğer']`.
- [ ] **Step 2:** `flutter test test/features/transactions/transaction_provider_test.dart` → FAIL.
- [ ] **Step 3:** Yaz. `main()` içinde `AppDatabase.open()` ve `SharedPreferences.getInstance()` çağrılır, ardından `runApp(buildProviders(db: db, prefs: prefs, child: const CepteCuzdanApp()))`.
- [ ] **Step 4:** Test → PASS. `flutter run` ile emülatörde uygulama açılır ve 4 sekme görünür.
- [ ] **Step 5:** Commit (`feat: provider katmanı ve bağımlılık ağacı`).

---

### Task 7: Manuel İşlem ekranı ve kategori yönetimi

**Files:**
- Create: `lib/features/transactions/{transactions_screen,transaction_form_screen,category_management_screen,category_editor_sheet}.dart`
- Modify: `lib/app/app.dart` (İşlemler sekmesi)
- Test: `test/features/transactions/{transaction_form,transactions_screen,category_management}_test.dart`

**Interfaces:**
- Consumes: `TransactionProvider`, `CategoryProvider`, `parseTlToKurus`, `AmountText`, `CategoryAvatar`, `EmptyState`, `iconFor`, `categoryPalette`, `pumpApp` + `TestDeps`.
- Produces: `TransactionFormScreen({TransactionRecord? initial})`. `initial?.id` null ise ekleme, değilse güncelleme yapar; `initial.source` korunur. `TransactionsScreen()` ve `CategoryManagementScreen()`.

Ekran kararları:
- **Form alanları:** Gelir/Gider `SegmentedButton`'ı (tip değişince kategori seçimi sıfırlanır), Tutar (`TextInputType.numberWithOptions(decimal: true)`), Tarih (varsayılan bugün; `showDatePicker` Türkçe), Kategori (seçili tipe göre süzülmüş dropdown), İşletme ve Açıklama (ikisi de opsiyonel). Düğme: "Kaydet".
- **Hata metinleri** (birebir): `Tutar giriniz`, `Geçerli bir tutar giriniz`, `Kategori seçiniz`. Kayıt sonrası SnackBar: `İşlem kaydedildi`.
- **Liste:** En yeni işlem en üstte, gün başlıklarıyla gruplu (`25 Kasım 2026 Çarşamba`). Dokununca düzenleme açılır. Kaydırınca `İşlem silinsin mi?` diye sorar, onaylanırsa siler. Boşken `Henüz işlem yok` gösterir. App bar'da "Kategoriler" düğmesi var.
- **Kategoriler:** Gider ve Gelir sekmeleri. Ekleme/düzenleme için bottom sheet: ad, `categoryPalette`'ten renk, `categoryIcons` ızgarasından ikon. Aynı ad ve tipte kategori varsa `Bu adda kategori var` hatası verir. Varsayılan kategorilerde sil düğmesi yok. Diğerlerinde onay metni: `Kategori silinsin mi? İşlemleri "Diğer" kategorisine taşınacak.`

- [ ] **Step 1: Başarısız testleri yaz**
  - `boş tutarla kaydetme hata gösterir` → `Tutar giriniz` görünür, `deps.txs` boş kalır.
  - `0 tutar reddedilir` → `Geçerli bir tutar giriniz` görünür.
  - `geçerli form kuruş cinsinden manual kayıt ekler` → `150,50` girilip Ulaşım seçilir ve Kaydet'e basılır. Beklenen tek kayıt: `amount == 15050`, `source == TxSource.manual`, `type == TxType.expense`.
  - `tip değişince kategori listesi değişir` → Gelir seçilince dropdown'da `Maaş` var, `Market` yok.
  - `düzenleme mevcut değerleri doldurur ve günceller`
  - `boş listede boş durum gösterir` / `kaydırıp onaylayınca siler`
  - `varsayılan kategoride sil düğmesi yok` / `aynı ad ve tipte kategori eklenemez`
- [ ] **Step 2:** `flutter test test/features/transactions` → FAIL.
- [ ] **Step 3:** Ekranları yaz.
- [ ] **Step 4:** `flutter test` → hepsi PASS. `flutter analyze` temiz.
- [ ] **Step 5:** Commit (`feat(transactions): manuel işlem ve kategori yönetimi`), push, **PR③ (Task 5–7) → main, 29 Kasım.** Berkay ile birlikte kontrol edin: fişten yapılan kayıt İşlemler listesinde `receipt` kaynağıyla görünüyor mu?

---

### Task 8: Bütçe hesapları ve uyarı servisi

**Files:**
- Create: `lib/features/budget/{budget_status,budget_alert_service,alert_notifier}.dart`
- Modify: `lib/app/providers.dart` (`onChanged: alerts.checkMonth` bağlantısı), `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`
- Modify: `test/fakes/fake_repositories.dart` (`FakeAlertNotifier` eklenir)
- Test: `test/features/budget/{budget_status,budget_alert_service}_test.dart`

**Interfaces:**
- Consumes: `BudgetRepository`, `TransactionRepository.summarize`, `CategoryRepository`, `monthOf`, `monthKey`, `formatKurus`.
- Produces:

```dart
enum BudgetLevel { ok, warning, exceeded }
BudgetLevel levelFor({required int spent, required int limit}); // spent > limit → exceeded; spent*100 >= limit*80 → warning
class BudgetLine { final Budget budget; final int spent; int get remaining; double get ratio; BudgetLevel get level; }
Future<List<BudgetLine>> budgetLinesFor(String month, {required BudgetRepository budgets, required TransactionRepository txs});
// genel bütçede spent = ayın toplam gideri; gelir sayılmaz
abstract class AlertNotifier { Future<void> init(); Future<void> show({required int id, required String title, required String body}); }
class LocalAlertNotifier implements AlertNotifier { } // flutter_local_notifications
class BudgetAlertService {
  BudgetAlertService({required BudgetRepository budgets, required TransactionRepository txs,
      required CategoryRepository categories, required AlertNotifier notifier, required SharedPreferences prefs});
  Future<void> checkMonth(DateTime anyDayInMonth);
}
```

Tekrar bildirimi önleme: SharedPreferences anahtarı `alert_<yyyy-MM>_<categoryId|all>_<warning|exceeded>`. Harcama eşiğin altına inerse (silme ya da düzenleme) anahtar silinir ve eşik yeniden geçilince yeni bildirim gider.

Bildirim metinleri:
- Uyarı: başlık `Bütçe uyarısı`, gövde `<Kategori adı | Aylık bütçe> limitinin %80'ine ulaştın: ₺X / ₺Y`
- Aşım: başlık `Bütçe aşıldı`, gövde `<Kategori adı | Aylık bütçe> limitini ₺Z aştın`

- [ ] **Step 1: Başarısız testleri yaz** (`SharedPreferences.setMockInitialValues({})`)
  - `levelFor eşikleri` → `(7999,10000)` ok, `(8000,10000)` warning, `(10000,10000)` warning, `(10001,10000)` exceeded.
  - `genel bütçe giderleri sayar gelirleri saymaz`
  - `eşik geçilince bir kez bildirir` → Market limiti 100000. 85000 harcanıp kontrol edilince 1 bildirim gelir (`Bütçe uyarısı`). +1000 harcanıp tekrar kontrol edilince hâlâ 1 bildirim vardır.
  - `aşımda ayrıca bildirir` → toplam 101000 olunca 2 bildirim olur, ikincisinin başlığı `Bütçe aşıldı`.
  - `eşiğin altına düşüp tekrar geçince yeniden bildirir`
  - `limit yoksa bildirim yok`
- [ ] **Step 2:** `flutter test test/features/budget` → FAIL.
- [ ] **Step 3:** Yaz.
  - Android tarafı: manifest'e `POST_NOTIFICATIONS` iznini, `build.gradle.kts`'e paketin README'sindeki core library desugaring ayarını ekle.
  - İlk açılışta `requestNotificationsPermission()` çağrılır; iOS'ta Darwin izinleri istenir.
  - `providers.dart` içinde `TransactionProvider(onChanged: alerts.checkMonth)` bağlantısını kur.
- [ ] **Step 4:** Test → PASS. Emülatörde limit koyup harcama ekleyerek bildirimin geldiğini gör.
- [ ] **Step 5:** Commit (`feat(budget): limit hesapları ve aşım bildirimleri`).

---

### Task 9: Dashboard

**Files:**
- Create: `lib/features/dashboard/{dashboard_provider,dashboard_screen}.dart`, `lib/features/dashboard/widgets/{summary_cards,category_pie_chart,balance_bar,recent_transactions,budget_badges}.dart`
- Modify: `lib/app/app.dart`, `lib/app/providers.dart`
- Test: `test/features/dashboard/{dashboard_provider,dashboard_screen}_test.dart`

**Interfaces:**
- Consumes: `summarize`, `query(limit: 5)`, `budgetLinesFor`, `TransactionProvider.revision`, `CategoryProvider.byId`, ortak bileşenler.
- Produces:

```dart
class DashboardData { final PeriodSummary summary; final List<BudgetLine> budgetLines; final List<TransactionRecord> recent;
  BudgetLine? get overall; int? get remaining; } // genel bütçe yoksa null
class DashboardProvider extends ChangeNotifier {
  DashboardProvider({required TransactionRepository txs, required BudgetRepository budgets,
      required TransactionProvider events, DateTime Function() clock = DateTime.now}); // events değişince load()
  DashboardData? get data; bool get loading; Future<void> load();
}
```

Ekran içeriği:
- Üç kart: `Gelir`, `Gider`, `Kalan Bütçe`. Kalan bütçe negatifse expense renginde gösterilir. Genel bütçe yoksa kartta `Bütçe tanımlanmadı` yazar.
- Kategori pasta grafiği (fl_chart): renkler kategori renginden gelir, dilimlerde yüzde yazar. Gider 0 ise grafik çizilmez, yerine `EmptyState('Bu ay henüz harcama yok')` gösterilir.
- Gelir-gider çubuğu: `Gelirinin %X'ini harcadın` yazar. Gelir 0 ise gizlenir.
- Son 5 işlem ve "Tümü" düğmesi (İşlemler sekmesine geçer).
- Limit rozetleri: seviyesi `warning` olanlar turuncu, `exceeded` olanlar kırmızı Chip.

- [ ] **Step 1: Başarısız testleri yaz**
  - `ayın özetini ve son 5 işlemi yükler` → clock 25 Kasım 2026, biri 31 Ekim tarihli 7 işlem var. Toplamlar yalnızca Kasım'ı içerir, `recent.length == 5`.
  - `işlem eklenince yeniden yüklenir`
  - `kartlar toplamları gösterir` → `₺5.000,00` ve `₺620,00` görünür.
  - `boş veride çökmez ve boş durum gösterir` → `Bu ay henüz harcama yok` ve `Bütçe tanımlanmadı` görünür, `find.byType(PieChart)` sonucu `findsNothing`.
  - `limiti %80 geçen kategori için rozet gösterir`
- [ ] **Step 2:** `flutter test test/features/dashboard` → FAIL.
- [ ] **Step 3:** Yaz.
- [ ] **Step 4:** Test → PASS. Emülatörde açık ve koyu temada göz kontrolü yap.
- [ ] **Step 5:** Commit (`feat(dashboard): özet kartlar, pasta grafik, son işlemler`), push, **PR④ → main, 2 Aralık.**

---

### Task 10: Raporlama ekranı

**Files:**
- Create: `lib/features/reports/{report_math,report_provider,report_screen}.dart`, `lib/features/reports/widgets/{comparison_bar_chart,category_breakdown_list}.dart`
- Modify: `lib/app/app.dart`, `lib/app/providers.dart`
- Test: `test/features/reports/{report_math,report_provider,report_screen}_test.dart`

**Interfaces:**
- Consumes: `weekOf`, `monthOf`, `previousOf`, `summarize`, `query`, `TransactionProvider.revision`.
- Produces:

```dart
enum ReportPeriod { week, month, custom }
int? changePercent({required int previous, required int current}); // previous == 0 → null ("Yeni"); tam sayıya yuvarlanır
class ReportData { final DateRange range, previousRange; final PeriodSummary current, previous; final List<TransactionRecord> transactions; }
class ReportProvider extends ChangeNotifier {
  ReportProvider({required TransactionRepository txs, required TransactionProvider events, DateTime Function() clock = DateTime.now});
  ReportPeriod get period; DateRange get range; int? get categoryId; ReportData? get data;
  void setPeriod(ReportPeriod p); void shift(int delta); void setCustomRange(DateRange r); void setCategory(int? id); // her biri load() tetikler
}
```

Ekran içeriği:
- `Haftalık / Aylık / Özel` SegmentedButton.
- Aralık etiketi ve ◀ ▶ düğmeleri. Özel aralık `showDateRangePicker` ile seçilir.
- Kategori dropdown'ı (`Tüm kategoriler` + gider kategorileri).
- Gruplu çubuk grafik: her kategori için bu dönem ve önceki dönem yan yana.
- Kategori döküm listesi: tutar ve değişim rozeti (`▲ %12`, `▼ %5`, `Yeni`), en altta toplam satırı.
- Altta dönemin işlem dökümü.
- App bar'da Ayarlar düğmesi (Task 11).

- [ ] **Step 1: Başarısız testleri yaz**
  - `changePercent` → `(10000,12000)` 20, `(10000,9500)` -5, `(0,5000)` null, `(5000,0)` -100.
  - `haftalık dönem Pazartesi başlar` → clock 25 Kasım 2026 iken aralık 23–29 Kasım, önceki aralık 16–22 Kasım.
  - `shift(-1) Ocak'tan önceki yılın Aralık'ına geçer` → clock 10 Ocak 2026, dönem aylık.
  - `kategori filtresi işlemleri ve toplamları süzer`
  - `önceki dönemde harcama yoksa Yeni gösterir`
- [ ] **Step 2:** `flutter test test/features/reports` → FAIL.
- [ ] **Step 3:** Yaz.
- [ ] **Step 4:** Test → PASS.
- [ ] **Step 5:** Commit (`feat(reports): haftalık/aylık döküm, filtre ve önceki dönem kıyası`).

---

### Task 11: Ayarlar ve bütçe limitleri

**Files:**
- Create: `lib/features/settings/{settings_provider,settings_screen,budget_settings_screen}.dart`
- Modify: `lib/core/db/app_database.dart` (`resetAll`), `lib/core/ui/widgets/amount_text.dart` (para birimi stili), `lib/app/app.dart` (`themeMode`), `lib/app/providers.dart`
- Test: `test/features/settings/{settings_provider,budget_settings}_test.dart`, `test/core/db/reset_test.dart`

**Interfaces:**
- Consumes: `BudgetRepository.upsert/delete`, `BudgetAlertService.checkMonth`, `TransactionProvider.markChanged`, `CategoryProvider.load`, `CategoryManagementScreen`.
- Produces:

```dart
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(SharedPreferences prefs);           // anahtarlar: 'theme_mode', 'currency_style'
  ThemeMode get themeMode; CurrencyStyle get currencyStyle;
  Future<void> setThemeMode(ThemeMode m); Future<void> setCurrencyStyle(CurrencyStyle s);
}
// AppDatabase içinde:
static Future<void> resetAll(Database db); // transactions, receipt_items, budgets, chat_messages ve kullanıcı kategorileri silinir; varsayılanlar kalır
```

Ekran içeriği:
- **Ayarlar:** Tema (`Sistem / Açık / Koyu`), Para birimi görünümü (`₺1.234,50 / 1.234,50 TL`), `Bütçe limitleri`, `Kategoriler` ve kırmızı `Verileri sıfırla` düğmesi.
- **Sıfırlama onay metni:** `Tüm işlemler, bütçeler ve sohbet geçmişi silinecek. Bu işlem geri alınamaz.` Düğmeler: `Sıfırla` / `Vazgeç`. Sıfırlamadan sonra `alert_*` anahtarları silinir, `markChanged()` ve `CategoryProvider.load()` çağrılır. Berkay'ın sohbet provider'ı da yeniden yüklenmeli; bunu Berkay'a bildir.
- **Bütçe limitleri:** Ay seçici (varsayılan bu ay), `Aylık genel bütçe` alanı ve her gider kategorisi için limit alanı. Kaydedince `upsert` yapılır, boş bırakılan alanın limiti silinir. Ardından `checkMonth(ay)` ve `markChanged()` çağrılır.
- `AmountText` para birimi stilini `context.select<SettingsProvider, CurrencyStyle>` ile okur. `pumpApp`'e `SettingsProvider` da eklenir.

- [ ] **Step 1: Başarısız testleri yaz**
  - `tema tercihi kalıcıdır` → `setThemeMode(ThemeMode.dark)` çağrıldıktan sonra aynı prefs ile yeni bir provider `dark` döner.
  - `resetAll işlemleri siler, varsayılan kategorileri korur` (ffi DB) → işlem, kullanıcı kategorisi ve bütçe eklenip sıfırlanınca sayılar 0 olur, kategori sayısı 9 kalır.
  - `bütçe alanını boşaltmak limiti siler`
  - `AmountText code stilinde 1.234,50 TL gösterir`
- [ ] **Step 2:** `flutter test test/features/settings test/core/db/reset_test.dart` → FAIL.
- [ ] **Step 3:** Yaz.
- [ ] **Step 4:** `flutter test` → hepsi PASS. `flutter analyze` temiz.
- [ ] **Step 5:** Commit (`feat(settings): tema, bütçe limitleri, veri sıfırlama`), push, **PR⑤ → main, 6 Aralık. Feature freeze.**

---

### Task 12: Entegrasyon, cihaz testleri ve hata düzeltme (7–13 Aralık, ortak)

- [ ] **Step 1:** `git fetch origin; git merge origin/main`. Ardından `flutter test` (beklenen: hepsi PASS) ve `flutter analyze` (beklenen: `No issues found!`).
- [ ] **Step 2: Cihaz kontrol listesi** (gerçek Android cihazda `flutter run --release`). Her maddenin sonucu not edilir:
  1. İlk açılışta Dashboard boş görünür ve bildirim izni istenir.
  2. Manuel gider eklenince Dashboard ve Rapor anında güncellenir.
  3. Market limiti 100 TL iken 85 TL harcanınca tek bildirim gelir; +20 TL harcanınca aşım bildirimi gelir.
  4. Uçak modunda Dashboard, İşlemler ve Raporlar çalışır; Asistan manuel ekrana yönlendirir (Berkay).
  5. Koyu temada grafik ve tutar renkleri okunur.
  6. Fişle yapılan kayıt (Berkay) İşlemler'de `receipt` kaynağı ve fiş kalemleriyle görünür.
  7. Uygulama kapatılıp açılınca veriler yerinde durur.
  8. "Verileri sıfırla" doğru çalışır.
  9. Her ekran yatay çevrilince kullanılabilir; form klavye açıkken de kaydedilebilir.
  10. Telefon yazı boyutu en büyükteyken metin kesilmez; TalkBack Ana Sayfa'yı ve grafikleri anlamlı okur.
  11. Asistan ekranı (Berkay) da 9 ve 10'u geçer.
- [ ] **Step 3:** Her hatayı GitHub Issue olarak aç. Düzeltirken önce hatayı yakalayan testi yaz, sonra düzelt. Commit: `fix: ...`.

### Task 13: Teslim (14–17 Aralık, ortak)

- [ ] **Step 1:** `flutter build apk --release` çalıştır. Beklenen çıktı: `build/app/outputs/flutter-apk/app-release.apk`.
- [ ] **Step 2:** Raporun son haline Task 4'teki şemayı, ekran görüntülerini, test özetini ve Berkay'ın saha denemesi tablosunu ekle.
- [ ] **Step 3:** Son PR (`mehmet` → `main`) merge edildikten sonra `git tag v1.0.0; git push --tags`.
- [ ] **Step 4:** Demo akışı: fiş → onay kartı → Dashboard → Rapor → limit bildirimi.

---

## Ek gereksinimler (25 Kasım akşamı)

Hoca **yatay ekran uyumunu** zorunlu tutuyor. Buna ek olarak **erişilebilirlik** (dokunma alanı, ekran okuyucu etiketleri, kontrast, büyük yazı) ve **küçük ekran** desteği de istendi. Görev 1–11'de yazılan ekranlar telefon dikey (360 × 800) için test edildi; Görev 14–16 onları bu gereksinimlere göre düzenler. Berkay'ın asistan ekranları da aynı kurallara ve testlere uyar.

Kurallar ve bugün yaşanan hatalardan çıkarılan dersler: **`docs/gelistirme-kurallari.md`**. İki geliştirici ve ajanları için bağlayıcıdır; her PR'dan önce oradaki kontrol listesi geçilir.

**Takvim:** Görev 14 → 26 Kas, Görev 15 → 27 Kas, Görev 16 → 28 Kas (Mehmet). 29 Kasım entegrasyonundan önce bitmeli, böylece Berkay'ın ekranları baştan bu kurallarla yazılır.

### Task 14: Ekran durumu test altyapısı ve responsive yardımcılar (26 Kas)

**Files:**
- Create: `lib/core/ui/responsive.dart`, `test/helpers/screen_matrix.dart`
- Modify: `test/helpers/pump_app.dart` (ekran boyutu, yazı ölçeği, tema parametreleri)
- Test: `test/core/ui/responsive_test.dart`

**Interfaces:**
- Produces (iki geliştirici de kullanır). **Uygulamada:** `TestScreen` + yazı ölçeği + sistem payı tek bir `ScreenCase` nesnesinde birleşti; `testScreens` gövdesi `(t, screen)` alır ve `pumpApp(t, w, screen: screen)` çağırır.



```dart
// lib/core/ui/responsive.dart
const double kWideBreakpoint = 600;     // ≥ 600 dp: yan gezinme, iki sütun
const double kMaxContentWidth = 840;    // geniş ekranda içerik ortalanır
const double kMaxFormWidth = 600;
bool isWide(BuildContext context);      // MediaQuery.sizeOf(context).width >= kWideBreakpoint
double chartHeight(BuildContext context, {double max = 200, double min = 120});
// = (ekranYüksekliği * 0.4).clamp(min, max)  → yatay 360 dp'de 144, dikey 800 dp'de 200
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = kMaxContentWidth});
} // Center + ConstrainedBox(maxWidth)

// test/helpers/screen_matrix.dart
enum TestScreen {
  phone(Size(360, 800)), small(Size(320, 568)), landscape(Size(800, 360)), tablet(Size(1280, 800));
  const TestScreen(this.size);
  final Size size;
}
/// [body]'yi beş durumda çalıştırır: phone, small, landscape, tablet (yazı 1,0×) ve phone (yazı 2,0×).
/// Test adına "[yatay]", "[küçük]", "[geniş]", "[büyük yazı]" eklenir.
void testScreens(String description, Future<void> Function(WidgetTester t) body, {TestDeps Function()? deps});
// pump_app.dart:
Future<void> pumpApp(WidgetTester t, Widget child,
    {TestDeps? deps, TestScreen screen = TestScreen.phone, double textScale = 1.0,
     ThemeMode themeMode = ThemeMode.light});
// textScale → t.platformDispatcher.textScaleFactorTestValue; tearDown'da sıfırlanır
```

- [ ] **Step 1: Başarısız testleri yaz**
  - `chartHeight dikeyde 200, yatayda 144, çok kısa ekranda 120` → 360×800'de 200, 800×360'ta 144, 800×250'de 120.
  - `isWide 600 dp ve üstünde true` → 599 false, 600 true.
  - `ContentWidth tablette içeriği 840 dp ile sınırlar ve ortalar` → 1280 genişlikte çocuğun genişliği 840, sol kenarı 220.
  - `testScreens beş varyasyon üretir` → gövde 5 kez çağrılır; ekran boyutları ve yazı ölçeği doğru.
- [ ] **Step 2:** `flutter test test/core/ui/responsive_test.dart` → FAIL.
- [ ] **Step 3:** Yaz.
- [ ] **Step 4:** Test → PASS; `flutter test` → hepsi PASS.
- [ ] **Step 5:** Commit (`test(ui): ekran durumu matrisi ve responsive yardımcılar`).

### Task 15: Mevcut ekranları yatay, küçük ve geniş ekrana uyarlama (27 Kas)

**Files:**
- Modify: `lib/app/shell.dart` (genişlik ≥ 600 → `NavigationRail`, değilse `NavigationBar`)
- Modify: `lib/features/dashboard/dashboard_screen.dart` ve `widgets/*` (geniş ekranda iki sütun: sol Kalan Bütçe + Gelir/Gider + rozetler + denge; sağ pasta grafik + son işlemler), `widgets/category_pie_card.dart` (`chartHeight`)
- Modify: `lib/features/reports/report_screen.dart` ve `widgets/*` (geniş ekranda grafik ve döküm yan yana, `chartHeight`)
- Modify: `lib/features/transactions/transaction_form_screen.dart`, `lib/features/settings/budget_settings_screen.dart`, `lib/features/settings/settings_screen.dart` (`ContentWidth(maxWidth: kMaxFormWidth)`), `transactions_screen.dart` ve `category_management_screen.dart` (`ContentWidth`)
- Test: `test/responsive/screens_matrix_test.dart`

**Interfaces:**
- Consumes: Görev 14'teki `isWide`, `chartHeight`, `ContentWidth`, `testScreens`.
- Produces: `AppShell` geniş ekranda `NavigationRail` gösterir; `AppShell.selectTab` iki düzende de çalışır.

Kararlar:
- Yatay telefon (800 × 360) da "geniş" sayılır: yan gezinme dikey alanı korur.
- Grafik yüksekliği her zaman `chartHeight(context)`; sabit 180/200 dp kalmaz.
- Form ekranlarında "Kaydet", klavye açıkken (`viewInsets.bottom = 300`) yatay ekranda kaydırılarak erişilebilir olmalı.

- [ ] **Step 1: Başarısız testleri yaz** (hepsi `testScreens` ile beş durumda)
  - `Ana Sayfa dolu veriyle taşmaz` → gelir, üç kategoride gider, genel bütçe ve %90 rozet; istisna yok; "Kalan Bütçe", "Harcama dağılımı", "Son işlemler" kaydırarak bulunur.
  - `İşlemler listesi taşmaz`, `İşlem formu taşmaz ve Kaydet erişilebilir` (klavye açıkken de), `Raporlar taşmaz` (grafik + döküm), `Ayarlar ve Bütçe limitleri taşmaz`, `Kategori yönetimi ve kategori sayfası taşmaz`.
  - `geniş ekranda yan gezinme, dar ekranda alt gezinme` → tablet ve yatayda `NavigationRail`, dikey telefonda `NavigationBar`; iki düzende de sekme değişimi çalışır.
  - `geniş ekranda Ana Sayfa iki sütun` → "Kalan Bütçe" ile "Harcama dağılımı" başlıklarının üst kenarları aynı hizada, sol kenarları farklı.
  - `yatayda grafik yüksekliği sınırlı` → `PieChart` ve `BarChart` yükseklikleri ≤ 144.
- [ ] **Step 2:** `flutter test test/responsive` → FAIL (taşmalar ve eksik düzenler).
- [ ] **Step 3:** Ekranları düzenle. Mevcut testlerin (telefon dikey) hepsi geçmeye devam etmeli.
- [ ] **Step 4:** `flutter test` → hepsi PASS. Telefonda yatay çevirerek göz kontrolü.
- [ ] **Step 5:** Commit (`feat(ui): yatay, küçük ve geniş ekran uyumu`).

### Task 16: Erişilebilirlik (28 Kas)

**Files:**
- Modify: `lib/features/transactions/category_editor_sheet.dart` (renk noktaları 48 dp dokunma alanı + `Semantics(label: 'Renk N', selected: ...)`; ikon düğmelerine tooltip), `lib/features/dashboard/widgets/category_pie_card.dart` ve `lib/features/reports/widgets/comparison_chart.dart` (`Semantics` özet etiketi), `lib/core/ui/widgets/amount_text.dart` (`semanticsLabel`)
- Test: `test/accessibility/a11y_test.dart`

**Interfaces:**
- Produces: `String spokenAmount(int kurus, {TxType? type})` (`lib/core/format/money.dart`) → `150,00 lira gider`, `5.000,00 lira gelir`, `eksi 500,00 lira`. `AmountText` bunu `semanticsLabel` olarak kullanır.
- Pasta grafik etiketi: `Harcama dağılımı: Market yüzde 47, Ulaşım yüzde 24, …`; çubuk grafik etiketi: `Bu dönem ve önceki dönem: Market 120,00 lira, önceki 100,00 lira; …`.

- [ ] **Step 1: Başarısız testleri yaz**
  - Her ana ekran için (Ana Sayfa dolu, İşlemler, İşlem formu, Raporlar dolu, Ayarlar, Bütçe limitleri, Kategoriler, kategori sayfası açık): `meetsGuideline(androidTapTargetGuideline)` ve `meetsGuideline(labeledTapTargetGuideline)`.
  - Aynı ekranlar açık ve koyu temada: `meetsGuideline(textContrastGuideline)`.
  - `spokenAmount` → `(15000, expense)` "150,00 lira gider", `(500000, income)` "5.000,00 lira gelir", `(-50000)` "eksi 500,00 lira".
  - `pasta grafik ekran okuyucuya özetlenir` → `find.bySemanticsLabel(RegExp(r'^Harcama dağılımı: Market yüzde \d+'))`.
  - `çubuk grafik ekran okuyucuya özetlenir` → `find.bySemanticsLabel(RegExp(r'^Bu dönem ve önceki dönem: '))`.
  - `renk seçimi ekran okuyucuda seçili durumunu söyler` → seçili renk noktası `isSelected` semantiğine sahip.
- [ ] **Step 2:** `flutter test test/accessibility` → FAIL.
- [ ] **Step 3:** Düzelt (dokunma alanları, etiketler, kontrast sorunları).
- [ ] **Step 4:** `flutter test` → hepsi PASS. Telefonda TalkBack açıkken Ana Sayfa ve form kısa bir deneme.
- [ ] **Step 5:** Commit (`feat(a11y): dokunma alanı, ekran okuyucu etiketleri, kontrast`).

**Berkay için:** Asistan ekranı (sohbet, onay kartı, kamera ve mikrofon düğmeleri) da `testScreens` ve `a11y_test.dart`'taki aynı kontrollerden geçmeli. Onay kartı yatay ekranda kaydırılabilir olmalı. Mikrofon ve kamera düğmelerinde tooltip olmalı. Kaydet / Düzenle / İptal düğmeleri en az 48 dp olmalı.

### Task 17: Berkay'ın Mehmet tarafı için notları (28 Kas)

Berkay PR #2'nin ikinci turunda Mehmet'in kodu için altı not bıraktı; hepsi doğrulandı. Görev 15–16 ile aynı dalda yapılır.

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml` (`android:allowBackup="false"`, `android:fullBackupContent="false"`)
- Modify: `lib/features/transactions/transaction_form_screen.dart`, `lib/features/reports/report_screen.dart` (tarih seçici aralığı)
- Modify: `lib/features/transactions/transaction_form_screen.dart`, `lib/features/settings/budget_settings_screen.dart` (kayıt hatası)
- Modify: `lib/features/transactions/transactions_screen.dart` (yükleme hatası, silme hatası)
- Modify: `lib/core/db/sqlite_category_repository.dart`, `test/fakes/fake_repositories.dart` (varsayılan kategori koruması)
- Test: `test/review_berkay_notes_test.dart`, `test/core/repositories/repository_contract.dart`

Kararlar:
- **Yedekleme kapalı.** Bütçe ve fiş verisi kişisel; Google Drive yedeğine gitmez.
- **Tarih seçici aralığı:** `firstDate` = bugünden 5 yıl önce, `lastDate` = bugünden 1 yıl sonra (asistandaki tarih penceresiyle uyumlu). Kaydın tarihi bu aralığın dışındaysa aralık onu kapsayacak şekilde genişler (`pickerRange`); kayıt değiştirilmez, eski kaydı açmak çökmez.
- **Kayıt hatası:** `_save` `catch` ile hatayı yakalar, `if (!mounted) return;` sonra "Kaydedilemedi" SnackBar'ı gösterir, ekran açık kalır, girilen değerler kaybolmaz.
- **İşlem listesi hatası:** `snap.hasError` ve önceki veri yoksa "İşlemler yüklenemedi" + "Tekrar dene". Kaydırarak silme başarısız olursa satır geri gelir ve "İşlem silinemedi" gösterilir.
- **Varsayılan kategori:** adı ve türü repository düzeyinde de değiştirilemez (`ArgumentError`); arayüz zaten yalnızca renk/ikon değiştiriyor.
- **SafeArea / 48 dp:** Görev 15–16 kapsamında (yatay ekranda sistem çubuğu ve çentik, kategori sayfası, renk noktaları).

- [ ] **Step 1:** Her not için başarısız test yaz (manifest için dosya içeriği testi).
- [ ] **Step 2:** `flutter test test/review_berkay_notes_test.dart` → FAIL.
- [ ] **Step 3:** Düzelt.
- [ ] **Step 4:** `flutter test` → hepsi PASS.
- [ ] **Step 5:** Commit (`fix: Berkay'ın notları (yedekleme, tarih aralığı, kayıt/silme hataları, varsayılan kategori)`).
