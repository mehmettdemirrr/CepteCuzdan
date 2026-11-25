# AGENTS.md — CepteCüzdan

Bu dosya, bu repoda çalışan tüm AI kodlama ajanları (Antigravity vb.) için **bağlayıcıdır**. Çelişki durumunda bu dosya, sohbetteki gevşek ifadelerden önce gelir. Emin olmadığın bir durumda varsayım yapma; dur ve sor.

## 1. Proje
CepteCüzdan; fiş fotoğrafı, Türkçe sesli komut veya yazılı sohbetten gelir/gider **taslağı** çıkaran, kullanıcı onayı olmadan kayıt yapmayan, Flutter tabanlı, verileri cihazda SQLite'ta tutan bir bütçe asistanıdır. Mobil Programlama dersi projesidir; teslim 17 Aralık 2026.

Üç giriş (fiş, ses, yazı) tek bir metin işleme hattında birleşir: metin → Gemini (JSON) → doğrulama → onay kartı → kullanıcı Kaydet derse repository'ye yazma.

## 2. Ekip ve alan sınırları
- **Berkay (bu repoda çalışan geliştirici):** Firebase + firebase_ai/Gemini, prompt ve JSON şeması, yanıt doğrulama, image_picker + ML Kit OCR, speech_to_text (tr_TR), Chatbot ekranı, sohbet geçmişi arayüzü, onay kartı (Kaydet/Düzenle/İptal), bütçe sorusu niyet ayrımı, AI hata/çevrimdışı senaryoları, bu modüllerin testleri.
- **Mehmet:** Proje iskeleti, SQLite şeması, model sınıfları, repository implementasyonları, Manuel İşlem, Dashboard, Raporlama, Ayarlar, bütçe/bildirim ekranları, tema/ortak bileşenler.
- **Kural:** Mehmet'in dosyalarını yeniden yazma, taşıma, biçim değiştirme (format-only dahil) yapma. Ortak model/repository imzası değişmesi gerekiyorsa önce `docs/integration_contract.md` içine **öneri** yaz, kodu değiştirme.

## 3. Teknoloji
Flutter/Dart, provider, sqflite, firebase_core, firebase_ai, image_picker, google_mlkit_text_recognition, speech_to_text, permission_handler, intl, fl_chart, flutter_local_notifications.
- `google_generative_ai` **kullanma** (kullanımdan kaldırıldı).
- Paket sürümlerini ve API imzalarını kurulu Flutter/SDK sürümü ve resmi güncel dokümanla doğrula; hafızandan yazma.
- Hedef platform: **Android** (geliştirme ortamı Windows; iOS derlenemez). iOS için sadece izin metinlerini hazır tut, test edildi deme.

## 4. Mimari
Üç katman: sunum (ekranlar) → iş mantığı (provider/servisler) → veri/cihaz servisleri. Ekranlar SQL çalıştırmaz, doğrudan Gemini/ML Kit çağırmaz.
Mehmet'in kurduğu klasör yapısına uy. Yapı henüz yoksa Berkay alanı için öneri:
```
lib/features/assistant/      # chatbot ekranı, onay kartı, provider
lib/services/ai/             # gemini servisi (arayüz + adapter), prompt, doğrulama, draft modeli
lib/services/ocr/            # ML Kit adapter
lib/services/speech/         # speech_to_text adapter
test/features/assistant/ ve test/services/...
```
AI, OCR ve STT servisleri **arayüz arkasında** olmalı; testlerde mock/fake ile çalışmalı.

## 5. Veri kuralları (değişmez)
- Tüm parasal DB alanları **INTEGER kuruş**: 320,00 TL = 32000.
- TL → kuruş dönüşümü **tek bir mapper/sınır noktasında, bir kez** yapılır. Kuruş değeri tekrar 100 ile çarpılmaz.
- AI taslağındaki tutar TL (double/decimal) olarak taşınır; DB'ye yazılırken tek noktada kuruşa çevrilir.
- `transactions.source` değerleri: `manual`, `receipt`, `voice`, `chat` (Mehmet'in sözleşmesiyle teyit et).
- Tablolar: categories, transactions, receipt_items, budgets, chat_messages. Alan adlarını mevcut koddan doğrula; uydurma.
- İşlem + fiş kalemleri mümkünse **tek DB transaction** içinde atomik kaydedilir (repository metodu gerekiyorsa sözleşmede öner).

## 6. AI kuralları
- AI çıktısı **asla** otomatik kaydedilmez. Kaydet'e basılınca repository üzerinden yazılır.
- Fiş görseli buluta gönderilmez. Gemini'ye yalnızca OCR/konuşma/yazı **metni** gider.
- Bütçe/rapor sayıları SQLite sorgusundan hesaplanır; modele tüm işlem listesi gönderilmez, modelden matematik istenmez.
- Beklenen JSON: `type, amount, merchant, date, category, items[]`. Structured output/response schema kullan ve **yine de** istemci tarafında doğrula (geçersiz JSON, eksik alan, bilinmeyen kategori, ≤0/NaN/sonsuz tutar, bozuk tarih → kontrollü hata).
- Varsayılanlar: tarih okunamazsa bugün, kategori belirsizse "Diğer". Varsayılan uygulanmışsa onay kartında görünür olmalı.
- Model adı tek bir sabitte/konfigürasyonda tutulur (kolay değiştirilsin).
- Hatalar kullanıcıya Türkçe ve anlaşılır gösterilir; AI çalışmasa da manuel kayıt yolu erişilebilir kalır.
- Loglara ham fiş metni veya finansal veri yazma.

## 7. Güvenlik ve gizlilik
- API anahtarı, service account JSON, `.env`, keystore, kişisel fiş/veri **Git'e eklenmez**. `.gitignore`'u kontrol et.
- `lib/firebase_options.dart` ve `android/app/google-services.json` istemci tanımlayıcılarıdır; commit edilip edilmeyeceği ekip kararıdır (bkz. docs). Karar verilmeden bu dosyaları stage etme; sor.
- Gerçek fiş fotoğrafı test verisi olarak commit edilmez; sentetik metin fixture kullan.

## 8. Git kuralları
- Çalışma branch'i: **`feature/berkay-ai-assistant`**. `main` üzerinde kod değiştirme/commit yok. Başka branch'e izinsiz geçme.
- Her işe başlamadan: `git status --short --branch`, `git branch --show-current`.
- Yalnızca ilgili pakete ait dosyaları stage et (`git add <dosya>`); `git add .` yok.
- Conventional Commit: `feat(ai): ...`, `feat(ocr): ...`, `feat(chat): ...`, `fix(...)`, `test(...)`, `docs(...)`, `chore(deps): ...`.
- **Ortak dosyalar** (`pubspec.yaml`, `AndroidManifest.xml`, `main.dart`, `build.gradle*`, `app` router/provider kayıt noktaları): değişiklik minimum, yalnızca ekleme olsun, mümkünse ayrı küçük commit; raporda açıkça belirt. Mevcut satırları yeniden sıralama/biçimlendirme.
- Yasak: `git reset --hard`, `git clean`, force push, history rewrite, kullanıcının değişikliğini silme, başarısız testi silme/atlama.
- `origin/main` ile senkron: `git fetch origin` sonra `git merge origin/main`. Çatışmayı otomatik ezme; dosya bazında raporla ve onay iste.

## 9. Kalite kapısı (her paket sonunda)
```
dart format <değişen dosyalar>
flutter analyze
flutter test
```
Gerçek çıktıyı raporla. Çalıştırılamayan komutu "geçti" diye yazma. Gerçek Firebase/cihaz gerektiren şeyi test edemediysen açıkça "doğrulanmadı" de.

## 10. Rapor formatı (her paket sonunda)
1) Yapılan iş 2) Değişen dosyalar 3) Test/analiz çıktısı 4) Commit hash 5) Mehmet'e sorulacaklar / blokajlar 6) Kullanıcının elle yapacağı adımlar 7) Sıradaki en küçük iş.

## 11. Kapsam ve takvim
- 29 Kasım: fiş fotoğrafından onaylı kayda uçtan uca akış.
- 6 Aralık: kapsam dondurma; sonrası yalnızca test, hata düzeltme, dokümantasyon.
- 17 Aralık: teslim.
- Zaman daralırsa önce **fiş/yazı → onay kartı → güvenli kayıt** hattını koru; süsleme ve ikincil özellikleri ertele.
- Kapsam dışı: banka entegrasyonu, bulut senkronizasyonu, kullanıcı hesabı, çoklu para birimi, web/masaüstü.
