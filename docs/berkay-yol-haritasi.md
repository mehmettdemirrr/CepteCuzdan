# Berkay için yol haritası

*Mehmet'ten, 25 Kasım 2026 akşamı*

Selam Berkay. Bugün benim kısmımı bitirdim ve PR #1'e koydum. Bu belgede durumu, senin sıradaki adımlarını ve ikimizin de uyacağı kuralları özetliyorum. Hepsi repoda: bu dosya, `docs/integration_contract.md` (veri sözleşmesi), `docs/gelistirme-kurallari.md` (kurallar ve dikkat edilecekler) ve `docs/plans/` (görev planı). Kodlama ajanına bu dört dosyayı okutabilirsin.

## Durum

- **Hazır olanlar** (`mehmet` dalı, PR #1):
  - Flutter iskeleti ve SQLite veri katmanı.
  - İşlemler, Ana Sayfa, Raporlar ve Ayarlar ekranları.
  - Bütçe bildirimleri.
  - 185 otomatik test; telefonda denendi.
- **Asistan sekmesi:** Şu an yer tutucu; senin ekranın gelecek.
- **Hocanın yeni isteği:** Uygulama **yatay ekranda** da düzgün çalışmalı. Ayrıca erişilebilirlik ve küçük ekran desteği istendi. Benim ekranlarımı 26–28 Kasım'da buna göre düzenleyeceğim. Senin ekranların da baştan bu kurallarla yazılmalı.

## Senin adımların

### 26 Kasım – başlangıç

1. PR #1'i incele: https://github.com/mehmettdemirrr/CepteCuzdan/pull/1. Özellikle `docs/integration_contract.md` sonundaki üç kararı onayla ya da itiraz et:
   - Gelir için varsayılan kategoriler `Maaş` ve `Diğer`.
   - `ReceiptItem.price` satır tutarı (miktar × birim fiyat), kuruş cinsinden.
   - Tema rengi `#00897B`.
2. Uygunsa PR'ı `main`'e merge et, sonra kendi dalına al:
   ```
   git switch feature/berkay-ai-assistant
   git fetch origin
   git merge origin/main
   ```
   Çakışma çıkmaz; senin dalında yalnızca `AGENTS.md` var.
3. Firebase projesini kur, `firebase_core` ve `firebase_ai` paketlerini ekle, ilk Gemini çağrısını yap. Model adını tek bir sabitte tut. `firebase_options.dart` ve `google-services.json` commit edilecek mi, birlikte karar verelim.
4. Prompt'u ve JSON şemasını yaz: `type, amount, merchant, date, category, items[]`. Model "yapılandırılmış çıktı" (structured output) verse bile yanıtı istemci tarafında yine doğrula.

### 27–28 Kasım – fiş ve sohbet

5. `image_picker` ile fiş fotoğrafını al, `google_mlkit_text_recognition` ile metne çevir. Bu servisi bir arabirimin arkasına koy; testlerde sentetik fiş metni kullan.
6. Sohbet ekranını ve onay kartını (Kaydet / Düzenle / İptal) yap.
   - Kaydet tek satır: `context.read<TransactionProvider>().add(tx, items: items)`.
   - Sohbet geçmişi `ChatMessageRepository`'de hazır.
7. Ekranını uygulamaya bağla:
   - `lib/app/app.dart` içindeki `_ComingSoon('Asistan')` satırını kendi ekranınla değiştir.
   - Provider'larını `lib/app/providers.dart` listesinin sonuna ekle.

### 29 Kasım – kilometre taşı

8. Telefonda birlikte deneyelim: fiş çek → onay kartı → Kaydet. Kayıt İşlemler listesinde "Fiş" etiketiyle görünmeli, Ana Sayfa güncellenmeli, limit varsa bildirim gelmeli.

### 30 Kasım – 6 Aralık

9. Sesli komut için `speech_to_text` (tr_TR) ekle, mikrofon iznini `permission_handler` ile iste.
10. "Bu ay markete ne kadar harcadım?" gibi soruları yanıtla:
    - Hesabı `summarize(monthOf(now))` ile yerelde yap.
    - Modele işlem listesi gönderme, hesap da yaptırma.
11. Hata ve çevrimdışı durumlar:
    - İnternet yoksa ya da kota dolduysa Türkçe bir mesaj göster ve "Manuel ekle" seçeneği sun: `AppShell.selectTab(context, AppShell.transactionsTab)`.
    - Fiş okunamazsa yeniden çekim iste.
12. Ayarlar'daki "Verileri sıfırla" sohbet geçmişini de siler. Sohbet ekranın `TransactionProvider.revision` değişince geçmişi yeniden yüklemeli.
13. **6 Aralık feature freeze:** bu tarihten sonra yeni özellik eklenmiyor.

### 7–13 Aralık

14. Widget testleri:
    - Mevcut testler için `pumpApp(tester, widget, deps: TestDeps())` hazır.
    - Görev 14'ten sonra beş ekran durumunu tek seferde deneyen `testScreens(...)` da gelecek.
15. Farklı marketlerden gerçek fişlerle doğruluk tablosu hazırla: fiş türü, okunan tutar, gerçek tutar, hata nedeni. Gerçek fiş fotoğraflarını repoya koyma.

Zaman daralırsa önce **fiş/yazı → onay kartı → kayıt** hattını bitir; senin `AGENTS.md`'n de bunu söylüyor.

## Ekranların için zorunlu olanlar

Bunları hoca istiyor; ayrıntılar `docs/gelistirme-kurallari.md` 1. ve 2. bölümde.

- **Beş ekran durumu:** dikey 360×800, küçük 320×568, **yatay 800×360**, geniş 1280×800 ve 2× yazı boyutunda taşma olmamalı.
- **Onay kartı:** yatay ekranda kaydırılabilir olmalı. Kaydet / Düzenle / İptal düğmeleri en az 48 dp olmalı.
- **Sohbet:** klavye açıkken giriş alanı ve son mesaj görünmeli. Yatay ekranda yükseklik yalnızca 360 dp; sabit yükseklik kullanma.
- **Ekran okuyucu:**
  - Kamera ve mikrofon düğmelerinde `tooltip` olmalı (ekran okuyucu bunu okur).
  - Mesaj balonlarında rol okunmalı: "Asistan: …", "Sen: …".
- **Renkler:** temadan alınmalı (`Theme.of(context).colorScheme`, `MoneyColors.of(context)`); açık ve koyu temada kontrast testi geçmeli.

## En çok dikkat etmen gerekenler

Bunların çoğunu bugün ben yaşadım; tam liste `docs/gelistirme-kurallari.md`'de.

1. **Release'te INTERNET izni.** Debug derlemede otomatik var, release manifest'te yok. Eklenmezse Gemini teslim APK'sında sessizce çalışmaz.
2. **Ses tanıma izni.** `RECORD_AUDIO` yetmez; Android 11+ için manifest'e `<queries>` içinde `android.speech.RecognitionService` da gerekir.
3. **Para.** Tutar bir kez `tlToKurus` ile kuruşa çevrilir. Gemini tutarı metin (`"320,00"`), sayı olmayan bir değer, ≤ 0 ya da NaN döndürebilir; bunları kayda çevirme.
4. **Tarih.** `fromDbDate` bozuk tarihte hata verir. Yakala, bugünün tarihini kullan ve kartta "tarih okunamadı" diye göster.
5. **Kategori.** Gemini'ye kullanıcının güncel kategori listesini gönder (`CategoryProvider.ofType(...)`). Gelen adı `findByName` ile ara, bulunamazsa "Diğer" kullan. Türkçe büyük harf zaten eşleşiyor.
6. **Kayıt yolu.** Kayıt yalnızca `TransactionProvider.add(...)` ile yapılır. Repository'ye doğrudan yazarsan Ana Sayfa yenilenmez, bildirim gelmez. `source` alanına `receipt`, `voice` ya da `chat` ver.
7. **Fiş görseli.** `image_picker`'ın dosyası geçici olabilir; `receiptPath` için görseli uygulama klasörüne kopyala. Görseli asla buluta gönderme; Gemini'ye yalnızca metin gider.
8. **Kota.** Aynı anda tek istek olsun: istek sürerken gönder düğmesi kapalı kalsın, yükleniyor göstergesi görünsün.
9. **`await` sonrası `context`.** `context.read`, `ScaffoldMessenger.of` ve `Navigator.of` await'ten **önce** alınmalı; `setState`'ten önce `mounted` kontrol edilmeli.
10. **Çift dokunma.** Kaydet basılınca kayıt bitene kadar kapalı kalmalı; yoksa çift kayıt olur.
11. **`Category` ad çakışması.** `package:flutter/foundation.dart`'ı tamamen içe aktarırsan modeldeki `Category` ile çakışır. `show ChangeNotifier` gibi seçerek içe aktar.
12. **Ortak dosyalar.** `pubspec.yaml`, `AndroidManifest.xml`, `main.dart`, `app.dart`, `providers.dart`'a yalnızca ekleme yap, mevcut satırları biçimlendirme. Sözleşme değişikliği gerekirse kodu değiştirme; `integration_contract.md`'nin "Öneriler" bölümüne yaz.
13. **Testler.** Gemini, ML Kit ve ses tanıma servisleri testte sahteyle çalışmalı; testte gerçek API çağrısı olmamalı. Taşma (overflow) testte hata sayılır.

## PR göndermeden önce

`docs/gelistirme-kurallari.md` sonundaki kontrol listesi. Kısacası:
- `flutter analyze` temiz, `flutter test` yeşil.
- Beş ekran durumu ve erişilebilirlik testlerin var.
- Kayıt yalnızca `TransactionProvider` üzerinden yapılıyor.
- Yeni izinler manifest'te; gizli dosya commit'e girmedi.

Takıldığın ya da sözleşmede eksik gördüğün bir şey olursa yaz, birlikte bakalım.
