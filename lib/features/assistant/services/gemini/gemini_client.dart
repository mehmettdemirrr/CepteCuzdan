import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';

/// Firebase AI Logic üzerinden kullanılan güncel kararlı Flash modeli.
/// Tek sabit: model değiştiğinde yalnızca burası güncellenir.
/// Kaynak: firebase.google.com/docs/ai-logic/models (Kasım 2026).
const String geminiModelName = 'gemini-3.8-flash';

/// Firebase başlatılmadan AI çağrısı yapıldığında fırlatılır.
class FirebaseNotInitializedException implements Exception {
  const FirebaseNotInitializedException();

  @override
  String toString() => 'FirebaseNotInitializedException';
}

/// Gemini çağrılarını soyutlayan arayüz.
/// Testlerde sahte istemci verilir; gerçek ağ çağrısı yapılmaz.
abstract interface class GeminiClient {
  Future<String> generateDraftJson({
    required String systemInstruction,
    required String userPrompt,
  });
}

/// Yapılandırılmış JSON yanıtı için OpenAPI/Gemini şeması.
Schema buildExpenseDraftSchema() {
  return Schema.object(
    properties: {
      'type': Schema.enumString(
        enumValues: const ['expense', 'income'],
        description: 'İşlem türü: gider için expense, gelir için income.',
      ),
      'amount': Schema.number(
        description: 'Toplam işlem tutarı (TL cinsinden pozitif sayı).',
      ),
      'merchant': Schema.string(
        nullable: true,
        description: 'Mağaza, iş yeri veya gelir kaynağı adı.',
      ),
      'date': Schema.string(
        nullable: true,
        description: 'İşlem tarihi (YYYY-MM-DD).',
      ),
      'category': Schema.string(
        description: 'Kullanıcının kategori listesinden seçilen kategori adı.',
      ),
      'items': Schema.array(
        nullable: true,
        description: 'Fiş veya ürün kalemleri.',
        items: Schema.object(
          properties: {
            'name': Schema.string(description: 'Ürün veya hizmet adı.'),
            'quantity': Schema.number(
              nullable: true,
              description: 'Miktar (varsayılan 1).',
            ),
            'price': Schema.number(
              description: 'Satır toplamı (miktar × birim fiyat, TL).',
            ),
          },
          optionalProperties: const ['quantity'],
        ),
      ),
    },
    optionalProperties: const ['merchant', 'date', 'items'],
  );
}

/// Firebase AI Logic (Gemini Developer API sağlayıcısı) istemcisi.
class FirebaseGeminiClient implements GeminiClient {
  FirebaseGeminiClient({this.modelName = geminiModelName});

  final String modelName;

  @override
  Future<String> generateDraftJson({
    required String systemInstruction,
    required String userPrompt,
  }) async {
    if (Firebase.apps.isEmpty) {
      throw const FirebaseNotInitializedException();
    }

    final model = FirebaseAI.googleAI().generativeModel(
      model: modelName,
      systemInstruction: Content.system(systemInstruction),
      generationConfig: GenerationConfig(
        temperature: 0.1,
        responseMimeType: 'application/json',
        responseSchema: buildExpenseDraftSchema(),
      ),
    );

    final response = await model.generateContent([Content.text(userPrompt)]);
    return response.text ?? '';
  }
}
