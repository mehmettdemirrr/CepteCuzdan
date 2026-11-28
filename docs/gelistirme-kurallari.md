# CepteCüzdan – Geliştirme Kuralları ve Dikkat Edilecekler

Bu belge Mehmet ve Berkay için (ve ikisinin kullandığı kodlama ajanları için) bağlayıcıdır. Maddelerin çoğu, 25 Kasım'daki geliştirme ve kod incelemesinde gerçekten karşılaşılan hatalardan çıkarıldı. Her PR'dan önce sondaki **kontrol listesi** geçilmeli.

İlgili belgeler: `docs/integration_contract.md` (modeller, repository'ler, kayıt akışı) ve `docs/plans/2026-11-25-mehmet-uygulama-plani.md` (görevler ve takvim).

---

## 1. Ekran uyumu (hocanın zorunlu tuttuğu gereksinimler)

Uygulama aşağıdaki **beş durumun her birinde** taşma olmadan ve kullanılabilir şekilde çalışmalı:

| Durum | Test boyutu (mantıksal piksel) | Ne kontrol edilir |
|---|---|---|
| Telefon, dikey | 360 × 800 | Varsayılan durum |
| Küçük telefon | 320 × 568 | Satırlar sığıyor mu, düğmeler kesiliyor mu |
| Telefon, **yatay** | 800 × 360 | Ekran yüksekliği çok az; her şey kaydırılabilir mi |
| Tablet / geniş | 1280 × 800 | İçerik uzayıp boş görünüyor mu |
| Büyük yazı | 360 × 800, yazı 1,3× ve 2,0× | Metin kesilmiyor, taşmıyor mu |

Kurallar:
- **Sabit genişlik yok.** Satırlarda `Expanded` / `Flexible`, sığmayabilecek gruplarda `Wrap` kullan. Ekran genişliğinden hesaplanan sabit sayılar kullanma.
- **Sabit yükseklik yalnızca grafiklerde** ve onda da ekran yüksekliğine bağlı bir üst sınırla (ör. `min(200, ekranYüksekliği * 0.4)`). Yatay ekranda yükseklik 360 dp'dir.
- **Her ekran kaydırılabilir olmalı** (`ListView`, `SingleChildScrollView`). Yatay ekranda formun alt kısmı ve "Kaydet" düğmesi klavye açıkken de erişilebilir olmalı.
- **Geniş ekranda düzen değişir:** genişlik ≥ 600 dp ise alt gezinme yerine yan gezinme (`NavigationRail`) kullanılır. İçerik en fazla ~840 dp genişlikte ortalanır; uygun yerlerde iki sütun olur. Ortak yardımcılar `lib/core/ui/responsive.dart`'ta (Görev 14).
- **Tutarlar ve uzun metinler:** kartlardaki büyük tutarlar `FittedBox(fit: BoxFit.scaleDown)` ile küçülür. Liste satırlarında `maxLines` + `TextOverflow.ellipsis` kullanılır.
- **Alt sayfa (bottom sheet)** yatay ekranda kaydırılabilir olmalı (`isScrollControlled: true` + `SingleChildScrollView`) ve klavye boşluğunu (`MediaQuery.viewInsetsOf`) hesaba katmalı.

## 2. Erişilebilirlik

- **Dokunma alanı en az 48 × 48 dp.** Renk noktası, ikon seçici gibi küçük öğeleri `InkWell` + yeterli `padding` ya da `SizedBox(48, 48)` ile büyüt.
- **Yalnızca ikon olan her düğmede `tooltip` olmalı.** Tooltip ekran okuyucu etiketi olarak da kullanılır.
- **Grafiklerin metin karşılığı olmalı.** Pasta ve çubuk grafik `Semantics(label: ...)` ile özetlenir, ör. "Harcama dağılımı: Market yüzde 47, Ulaşım yüzde 24".
- **Bilgi yalnızca renkle verilmemeli.** Gelir/gider tutarlarında `+` / `-` işareti var; limit rozetlerinde "%90" ya da "aşıldı" yazısı var. Yeni ekranlarda da böyle olmalı.
- **Kontrast:** renkler temadan alınır (`Theme.of(context).colorScheme`, `MoneyColors.of(context)`); sabit renk kullanma. Açık ve koyu temada `textContrastGuideline` testi geçmeli.
- **Yazı boyutu:** sistem yazı boyutu büyütülünce (2,0×) metin kesilmemeli, taşmamalı.

Testlerde Flutter'ın hazır kontrolleri kullanılır:

```dart
await expectLater(t, meetsGuideline(androidTapTargetGuideline));
await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
await expectLater(t, meetsGuideline(textContrastGuideline));
```

## 3. Veri ve para

- Tutarlar her yerde **kuruş cinsinden `int`**. TL'den kuruşa çeviri yalnızca `lib/core/format/money.dart` ile ve **bir kez** yapılır: kullanıcı girişi için `parseTlToKurus`, model çıktısı için `tlToKurus`. Kuruş değeri tekrar 100 ile çarpılmaz.
- Kullanıcı girişi 12 haneyle sınırlı (`parseTlToKurus`). Model çıktısındaki tutar sayı değilse, ≤ 0, NaN ya da sonsuzsa kayda dönüşmez.
- Tarih `fromDbDate` ile okunur. Bozuk tarih hata verir; yakala ve bugünün tarihini kullan, kullanıcıya da göster.
- **Türkçe harf:** Dart'ın `toLowerCase`'i Türkçe değildir (`I` → `i`). Ad karşılaştırmada `foldTr` (`lib/core/format/text.dart`) kullan.
- **Yüzdeli Türkçe metin:** "%12'sini" gibi ekler sayıya göre değişir (`%10'unu`). Eki sayıya bağlama: "%12 kadarını", "yüzde 12".
- **Veritabanı şeması değişirse** `AppDatabase.version` artırılır ve `_upgrade` içine geçiş adımı eklenir; telefonlardaki mevcut veriler silinmemeli. Şema değişikliği önerisi `integration_contract.md` "Öneriler" bölümüne yazılır.

## 4. Mimari ve sözleşme

- **Ekranlar veritabanına ya da repository'ye doğrudan yazmaz.** İşlem yazmanın tek yolu `TransactionProvider.add / update / delete`. Repository'ye doğrudan yazılırsa Ana Sayfa yenilenmez ve bütçe bildirimi gelmez.
- Veri dışarıdan değiştiyse (bütçe kaydı, sıfırlama, kategori silme) `TransactionProvider.markChanged()` çağrılır. Veri gösteren ekranlar `revision` değişince yeniden yükler.
- **Veri sıfırlamayı** anlamak için `revision` değil `DataResetter.resets` dinlenir; `revision` her kayıtta değişir.
- Gemini, ML Kit, ses tanıma ve bildirim servisleri **bir arabirimin arkasında** durur. Testlerde sahteleri kullanılır; testlerde gerçek API çağrılmaz.
- Sahte repository'yi (`test/fakes/fake_repositories.dart`) değiştirirsen sözleşme testi (`repository_contract.dart`) hem sahte hem SQLite için geçmeye devam etmeli.
- `package:flutter/foundation.dart`'ı tamamen içe aktaran dosyada modeldeki `Category` ile ad çakışması olur. `show ChangeNotifier, debugPrint` gibi seçerek içe aktar.

## 5. Flutter tuzakları (bunları yaşadık)

| Tuzak | Belirti | Doğrusu |
|---|---|---|
| `await`'ten sonra `context` kullanmak | Ekran kapanmışsa hata | `context.read`, `ScaffoldMessenger.of`, `Navigator.of` **await'ten önce** alınır; `setState`'ten önce `if (!mounted) return;` |
| Çift dokunma | Aynı kayıt iki kez yazılır | Kaydet basılınca `_saving = true`; bitene kadar düğme kapalı |
| `DropdownButtonFormField(initialValue: ...)` | Değer dışarıdan değişince alan güncellenmez; listede olmayan değerde assert ile çöker | Değeri listede olup olmadığını kontrol ederek ver; dışarıdan değişiyorsa `key: ValueKey(değer)` |
| `IndexedStack` | Görünmeyen sekmeler de çizilir; oradaki hata başka sekmeyi bozar | Her sekme kendi hatasını yakalar ve boş durum gösterir |
| `SegmentedButton` | Seçili segmente tekrar basınca `onSelectionChanged` çağrılmaz | Tekrar seçim gerekiyorsa ayrı bir dokunma alanı (ör. etiket) |
| `Dismissible` + async silme | "dismissed Dismissible is still part of the tree" | `onDismissed` içinde satırı hemen listeden çıkar, sonra sil |
| `ChangeNotifierProvider` tembel oluşturur | Açılışta yüklenmesi gereken veri ilk kullanıma kadar yüklenmez | `lazy: false` |
| Provider'da async yükleme | Eski sonuç yenisinin üstüne yazılır; dispose sonrası `notifyListeners` | Nesil sayacı (`_generation`) + `_disposed` kontrolü + `try/catch` ile hata durumu |
| Yükleme hatası | Sonsuz yükleniyor göstergesi | Hata durumunda "Veriler yüklenemedi" + "Tekrar dene" |
| Uygulamaya geri dönüş | Ay değişse de eski ay gösterilir | `AppLifecycleListener(onResume: ...)` ile yeniden yükle |
| Bildirim/Firebase başlatma | Hata verirse uygulama hiç açılmaz | `main()` içinde `try/catch`; uygulama yine açılır |
| Kayıt sonrası yan iş hata verirse | Kullanıcı tekrar kaydeder, çift kayıt olur | Kayıt yazıldıysa yan işlerin hatası yakalanır, kayıt başarılı sayılır |
| Kayıt hatası yakalanmıyor | Düğme kapalı kalır ya da ekran sessizce kapanır | `_save` içinde `catch` → `if (!mounted) return;` → "Kaydedilemedi" SnackBar'ı; form açık, değerler yerinde |
| `Dismissible` silme başarısız | Satır kaybolur ya da aynı anahtarla geri eklenince "still part of the tree" | Satırı geri ekle **ve anahtarını değiştir** (`tx-<id>-<sürüm>`) |
| `setState(() => _x = future)` | "setState() callback argument returned a Future" | Ok fonksiyonu atanan değeri döndürür; `setState(() { _x = future; })` |
| `showDatePicker(firstDate: DateTime(2020))` | Daha eski bir kayıt açılınca assert ile çöker | `pickerRange(bugün, start: kayıtTarihi)`: aralık kaydı kapsayacak şekilde genişler |
| `DropdownButtonFormField` dar ekranda / büyük yazıda | İç satır sağdan taşar | `isExpanded: true` + öğe metninde `Flexible` + `ellipsis` |
| `ListTile.trailing` büyük yazıda | İki satırlı tutar sığmaz, satır bozulur | Yazı ölçeği ≥ 1,5 ise tutarı `subtitle`'a al, `trailing: null` |
| `Semantics(label:)` kart içinde | Etiket komşu metinlerle birleşir, ekran okuyucu ayrı okumaz | `container: true` + `excludeSemantics: true` |
| Hata bandında düğmeler kayan alanda | Uzun mesajda "Manuel ekle" görünmez | Yalnızca mesaj kayar; eylem düğmeleri kaymayan kısımda (`Wrap`) |

## 6. Android ve izinler

- `compileSdk 37`, AGP 9.1.1 ve desugaring ayarlı (bildirim paketi bunları istiyor). AGP 9 Kotlin'i kendi içinde getirir; `kotlin-android` eklentisi uygulanmaz.
- **`INTERNET` izni** release manifest'te olmalı (debug'da otomatik var; release'te eksik olursa Gemini sessizce çalışmaz).
- **Ses tanıma:** `RECORD_AUDIO` + Android 11+ için `<queries>` içinde `android.speech.RecognitionService`.
- **Kamera:** `CAMERA`. İzin reddedilirse neden gerektiğini açıkla; yazılı sohbet ve manuel giriş açık kalsın.
- `POST_NOTIFICATIONS` (Android 13+) eklendi; izin ilk açılışta, ilk kareden sonra isteniyor.
- Manifest ve `build.gradle.kts`'te yalnızca **ekleme** yapılır; mevcut satırlar yeniden sıralanmaz.

## 7. Gizlilik ve güvenlik

- Fiş görseli buluta gönderilmez; Gemini'ye yalnızca OCR, konuşma ya da yazı **metni** gider.
- Bütçe hesapları SQLite'tan yapılır; modele işlem listesi gönderilmez, modele hesap yaptırılmaz.
- API anahtarı, `.env`, keystore ve gerçek fiş fotoğrafları Git'e girmez (`.gitignore` hazır). `firebase_options.dart` ve `google-services.json` için karar ortak verilir.
- Loglara ham fiş metni ya da tutar yazılmaz.

## 8. Git

- Herkes kendi dalında çalışır (`mehmet`, `feature/berkay-ai-assistant`); `main`'e yalnızca PR ile girilir.
- Her gün başında `git fetch origin; git merge origin/main`. Çakışmayı otomatik ezme; dosya bazında konuş.
- Başkasının dosyalarını yeniden biçimlendirme veya taşıma (sahiplik tablosu planda).
- Yalnızca ilgili dosyaları `git add <dosya>` ile ekle; `pubspec.yaml` değişince `pubspec.lock` da commit'lenir.
- Conventional Commit: `feat(...)`, `fix(...)`, `test(...)`, `docs(...)`, `chore(...)`.

## 9. Test

- Önce test, sonra kod: testi yaz, başarısız olduğunu gör, sonra kodu yaz.
- Widget testlerinde `pumpApp(tester, widget, deps: TestDeps())` kullanılır (`test/helpers/pump_app.dart`). Varsayılan ekran 360 × 800, üstte 24 dp durum çubuğu payı var (gerçek telefondaki gibi).
- Beş ekran durumu için `testScreens('...', (t, screen) async { await pumpApp(t, w, screen: screen); ... })` (`test/helpers/screen_matrix.dart`). Yatay durumda solda 32 dp çentik payı var; içerik bu alanın altında kalmamalı. Koyu tema: `pumpApp(..., themeMode: ThemeMode.dark)`.
- Liste tembel çizilir: ilk ekranın altındaki öğeyi aramadan önce `scrollUntilVisible` ile kaydır.
- Taşma (overflow) testte hata sayılır; "testte taşıyor ama telefonda sorun yok" diye geçiştirme.
- Her yeni ekran: beş ekran durumu + açık/koyu tema kontrast + dokunma alanı testleri.

---

## PR öncesi kontrol listesi

- [ ] `dart format` (yalnızca kendi değiştirdiğin dosyalar), `flutter analyze` temiz, `flutter test` hepsi geçiyor.
- [ ] Yeni ekran 5 ekran durumunda (dikey, küçük, yatay, geniş, büyük yazı) taşmadan çalışıyor; testi var.
- [ ] Dokunma alanı ≥ 48 dp, ikon düğmelerinde tooltip, grafiklerde `Semantics` etiketi var.
- [ ] Kayıt yalnızca `TransactionProvider` üzerinden; `await` sonrası `context` yok; çift dokunmaya karşı kilit var.
- [ ] Yeni izin varsa manifest'te; reddedilince uygulama çalışmaya devam ediyor.
- [ ] Ortak dosyalarda yalnızca ekleme var; sözleşme değiştiyse `integration_contract.md` güncel.
- [ ] Gizli dosya, API anahtarı ya da gerçek fiş görseli commit'e girmedi.
