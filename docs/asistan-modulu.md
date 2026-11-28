# Asistan / AI Modülü (Berkay)

Bu belge CepteCüzdan uygulamasının `lib/features/assistant/` altında yer alan yapay zekâ, fiş OCR, sesli komut ve sohbet modülünün gerçek çalışan kapsamını, mimarisini, test kapsamını ve bilinen kısıtlarını özetler.

## 1. Çalışan Özellikler (Gerçek Android Cihazda Doğrulandı)

- **Tek Taslak Hattı (Yazı / Fiş / Ses):**
  - **Yazılı sohbet:** Doğal Türkçe harcama/gelir cümlelerinden (`"markete 245,50 verdim"`) yapılandırılmış JSON taslağı üretir (`source: chat`).
  - **Fiş fotoğrafı + Cihaz içi OCR:** `image_picker` (kamera / galeri) + `google_mlkit_text_recognition` (Latin). Fiş görseli **cihazda kalır** (`<appDocs>/receipts/`), buluta yalnızca temizlenmiş OCR metni gider (`source: receipt`). Boş/okunamayan fişlerde Gemini çağrılmaz.
  - **Türkçe sesli komut:** `speech_to_text` (`tr_TR`) + `permission_handler` (`RECORD_AUDIO` + Android 11+ `RecognitionService`). Canlı kısmi metin gösterir, son metni aynı Gemini hattından geçirir (`source: voice`).
- **Gemini Entegrasyonu ve İstemci Doğrulaması:**
  - `firebase_core` + `firebase_ai` (`FirebaseAI.googleAI()`, tek model sabiti: `gemini-3.5-flash-lite`).
  - Structured output (`responseSchema`) + istemci doğrulaması (`parseAndValidateDraft`): geçersiz JSON, eksik alan, metin/kötü tutar, bozuk tarih (bugün + uyarı), bilinmeyen veya tür uyumsuz kategori (aynı türdeki `"Diğer"` + uyarı), prompt injection koruması.
- **Onay Kartı ve Güvenli Kayıt:**
  - AI çıktısı **asla otomatik kaydedilmez**; taslak bellek içinde (`PendingDraft`) tutulur.
  - `ConfirmationCard` üzerinde tutar, tür, kaynak, kategori, işletme, tarih, ürün kalemleri ve varsayılan uyarıları görünür.
  - **Düzenle (`DraftEditSheet`):** Tür, tutar (`parseTlToKurus`), kategori, işletme, tarih ve ürün kalemleri düzenlenebilir.
  - **Kaydet:** Yalnızca `TransactionProvider.add(record, items: items)` üzerinden yazar (Ana Sayfa, İşlemler, Raporlar ve bütçe uyarı bildirimleri otomatik güncellenir), TL → kuruş dönüşümü yalnızca kayıt anında `tlToKurus` ile bir kez yapılır, çift tıklama korumalıdır, sohbet mesajını `ChatMessageRepository.linkTransaction` ile bağlar.
  - **İptal:** Veritabanına yazmaz, kaydedilmemiş fiş görselini siler.
- **Yerel Bütçe / Harcama Soruları (`BudgetQueryService`):**
  - `"Bu ay markete ne kadar harcadım?"`, `"Bu ay özetim nasıl?"`, `"Bugün / geçen ay / geçen hafta..."` sorularını `TransactionRepository.summarize` ile **yerelde** hesaplar; modele işlem listesi göndermez ve **çevrimdışı (uçak modunda) çalışır**.
- **Hata, Çevrimdışı ve Veri Sıfırlama Yönetimi:**
  - İnternet yok, kota aşımı, zaman aşımı, kamera/mikrofon izni reddi veya bozuk yanıt durumlarında Türkçe hata + **Tekrar dene** + **Manuel ekle** (`AppShell.selectTab(context, AppShell.transactionsTab)`).
  - Ayarlar → **Verileri sıfırla** sonrasında `TransactionProvider.revision` dinlenerek sohbet geçmişi ve cihazdaki fiş görselleri temizlenir.
- **Ekran Uyumu ve Erişilebilirlik:**
  - 5 ekran durumunda (dikey `360×800`, küçük `320×568`, yatay `800×360` + `SafeArea`, geniş `1280×800` `maxWidth: 840`, `2.0×` büyük yazı) taşmasız çalışır.
  - İkon düğmelerinde `tooltip` ve `≥ 48×48 dp` dokunma alanı; mesaj balonlarında `Semantics` rolü (`"Sen: ..."`, `"Asistan: ..."`); açık/koyu temada WCAG AA (`≥ 4.5:1`) kontrast testi geçer.

## 2. Mimari Yerleşim

- `lib/features/assistant/services/gemini/` — `GeminiClient`, `ExpenseDraftService`, `ExpenseDraftPrompt`, `draft_validator.dart`, `ParsedExpenseDraft`
- `lib/features/assistant/services/ocr/` — `ReceiptScanService`, `ReceiptDraftPipeline`, `LocalReceiptImageStorage`, `receipt_text_cleaner.dart`
- `lib/features/assistant/services/speech/` — `SpeechService`, `DeviceSpeechService`
- `lib/features/assistant/services/query/` — `BudgetQueryService`
- `lib/features/assistant/state/` — `AssistantController`, `PendingDraft`
- `lib/features/assistant/ui/` — `AssistantScreen`, `ConfirmationCard`, `DraftEditSheet`
- `test/features/assistant/` — tüm servis, durum ve widget testleri (ağsız, sahte arayüzlerle + in-memory SQLite entegrasyonu)

## 3. Bilinen Kısıtlar

- **Platform:** Yalnızca Android üzerinde derlenip gerçek cihazda (`SM G990E`, Android 16) test edilmiştir; iOS derlenmemiştir.
- **Firebase App Check:** Firebase AI Logic için App Check zorunluluğu 21 Ocak 2027'ye kadar izleme modunda (unenforced) bırakılmıştır; Play Store dışı APK dağıtımı için bu şekilde çalışır.
- **Çevrimdışı kapsam:** Bütçe soruları ve manuel işlem kaydı çevrimdışı çalışır; yeni metin/fiş/ses taslağı çıkarma Gemini API için internet gerektirir.
- **Termal / soluk fişler:** ML Kit OCR çok soluk veya buruşuk fişlerde hatalı satır okuyabilir; bu nedenle onay kartındaki **Düzenle** akışı her zaman açıktır.
- **Ortak responsive yardımcıları:** Mehmet'in Görev 14–16 (`lib/core/ui/responsive.dart`, `test/helpers/screen_matrix.dart`) çalışmaları `main`'e geldiğinde Asistan ekranının `ConstrainedBox(maxWidth: 840)` ve 5-ekran testleri ortak yardımcılara bağlanabilir.

## 4. Gerçek Fiş Doğruluk Gözlemleri (Örnekler)

| Fiş Kaynağı | Okunan Tutar | Gerçek Tutar | Not |
|---|---|---|---|
| ŞOK Marketler (galeri) | `₺427,42` | `₺427,42` | İşletme, kategori (`Market`) ve tarih (`2024-02-01`) doğru ayrıştırıldı. |
| BİM Birleşik Mağazalar (galeri) | `₺22,00` | `₺22,00` | Ürün kalemi (`ÇİLEKLİ KEFİR 250ML`) doğru çıkarıldı; Düzenle → Kaydet doğrulandı. |
