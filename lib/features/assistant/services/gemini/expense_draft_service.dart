import 'dart:async';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../../core/models/enums.dart';
import 'draft_validator.dart';
import 'expense_draft_prompt.dart';
import 'gemini_client.dart';
import 'parsed_expense_draft.dart';

/// Ham metinden (fiş OCR, ses veya sohbet) gelir/gider taslağı çıkaran servis.
/// UI'dan bağımsızdır; veritabanına yazmaz ve kuruş dönüşümü yapmaz.
class ExpenseDraftService {
  const ExpenseDraftService(
    this._client, {
    this.requestTimeout = geminiRequestTimeout,
  });

  final GeminiClient _client;
  final Duration requestTimeout;

  /// [rawText] içinden doğrulanmış [ParsedExpenseDraft] çıkarır.
  /// [categoriesByType], `CategoryProvider.ofType` ile elde edilen tür bazlı
  /// güncel kategori adlarını içerir.
  Future<ExpenseDraftResult> extractDraft({
    required String rawText,
    required DateTime today,
    required Map<TxType, List<String>> categoriesByType,
    required TxSource source,
  }) async {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      return const ExpenseDraftFailure(
        ExpenseDraftError(
          code: ExpenseDraftErrorCode.emptyInput,
          userMessage: 'Lütfen bir harcama veya gelir metni girin.',
        ),
      );
    }

    final prompt = ExpenseDraftPrompt.build(
      rawText: trimmed,
      today: today,
      categoriesByType: categoriesByType,
      source: source,
    );

    final String rawResponse;
    try {
      rawResponse = await _client
          .generateDraftJson(
            systemInstruction: prompt.systemInstruction,
            userPrompt: prompt.userPrompt,
          )
          .timeout(requestTimeout);
    } on QuotaExceeded {
      debugPrint('ExpenseDraftService: Gemini kotası aşıldı.');
      return const ExpenseDraftFailure(
        ExpenseDraftError(
          code: ExpenseDraftErrorCode.quotaExceeded,
          userMessage: 'AI kullanım kotası doldu. Daha sonra tekrar deneyin veya manuel ekleyin.',
        ),
      );
    } on FirebaseNotInitializedException {
      debugPrint('ExpenseDraftService: Firebase başlatılmamış.');
      return const ExpenseDraftFailure(
        ExpenseDraftError(
          code: ExpenseDraftErrorCode.notConfigured,
          userMessage: 'AI servisi şu an kullanılamıyor. İşleminizi manuel olarak ekleyebilirsiniz.',
        ),
      );
    } on ServiceApiNotEnabled {
      debugPrint('ExpenseDraftService: Firebase AI Logic API etkin değil.');
      return const ExpenseDraftFailure(
        ExpenseDraftError(
          code: ExpenseDraftErrorCode.notConfigured,
          userMessage: 'AI servisi şu an kullanılamıyor. İşleminizi manuel olarak ekleyebilirsiniz.',
        ),
      );
    } on InvalidApiKey {
      debugPrint('ExpenseDraftService: Geçersiz API anahtarı.');
      return const ExpenseDraftFailure(
        ExpenseDraftError(
          code: ExpenseDraftErrorCode.notConfigured,
          userMessage: 'AI servisi şu an kullanılamıyor. İşleminizi manuel olarak ekleyebilirsiniz.',
        ),
      );
    } on FirebaseAIException catch (e) {
      debugPrint('ExpenseDraftService: FirebaseAIException (${e.runtimeType})');
      return const ExpenseDraftFailure(
        ExpenseDraftError(
          code: ExpenseDraftErrorCode.networkOrService,
          userMessage: 'AI servisine şu an ulaşılamıyor. İnternet bağlantınızı kontrol edin veya manuel ekleyin.',
        ),
      );
    } on SocketException {
      debugPrint('ExpenseDraftService: Ağ bağlantısı yok.');
      return const ExpenseDraftFailure(
        ExpenseDraftError(
          code: ExpenseDraftErrorCode.networkOrService,
          userMessage: 'İnternet bağlantısı bulunamadı. Bağlantınızı kontrol edin veya manuel ekleyin.',
        ),
      );
    } on TimeoutException {
      debugPrint('ExpenseDraftService: İstek zaman aşımına uğradı.');
      return const ExpenseDraftFailure(
        ExpenseDraftError(
          code: ExpenseDraftErrorCode.networkOrService,
          userMessage: 'AI yanıtı zaman aşımına uğradı. Tekrar deneyin veya manuel ekleyin.',
        ),
      );
    } catch (e) {
      // Ham fiş metni veya tutar loglanmaz.
      debugPrint('ExpenseDraftService: Beklenmeyen hata (${e.runtimeType})');
      return const ExpenseDraftFailure(
        ExpenseDraftError(
          code: ExpenseDraftErrorCode.unknown,
          userMessage: 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin veya manuel ekleyin.',
        ),
      );
    }

    return parseAndValidateDraft(
      rawResponse: rawResponse,
      today: today,
      categoriesByType: categoriesByType,
      source: source,
    );
  }
}
