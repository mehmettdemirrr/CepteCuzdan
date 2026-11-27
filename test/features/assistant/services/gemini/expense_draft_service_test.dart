import 'dart:async';
import 'dart:io';

import 'package:cepte_cuzdan/core/models/enums.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/expense_draft_service.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/gemini_client.dart';
import 'package:cepte_cuzdan/features/assistant/services/gemini/parsed_expense_draft.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGeminiClient implements GeminiClient {
  _FakeGeminiClient({this.response, this.error});

  final String? response;
  final Object? error;
  String? lastSystemInstruction;
  String? lastUserPrompt;
  int callCount = 0;

  @override
  Future<String> generateDraftJson({
    required String systemInstruction,
    required String userPrompt,
  }) async {
    callCount++;
    lastSystemInstruction = systemInstruction;
    lastUserPrompt = userPrompt;
    if (error != null) throw error!;
    return response ?? '';
  }
}

void main() {
  final today = DateTime(2026, 11, 26);
  const categories = <TxType, List<String>>{
    TxType.expense: ['Market', 'Ulaşım', 'Diğer'],
    TxType.income: ['Maaş', 'Diğer'],
  };

  group('ExpenseDraftService', () {
    test('boş metinde istemciyi çağırmadan emptyInput hatası döner', () async {
      final client = _FakeGeminiClient(response: '{}');
      final service = ExpenseDraftService(client);

      final result = await service.extractDraft(
        rawText: '   \n\t  ',
        today: today,
        categoriesByType: categories,
        source: TxSource.chat,
      );

      expect(client.callCount, 0);
      expect(result, isA<ExpenseDraftFailure>());
      expect(
        (result as ExpenseDraftFailure).error.code,
        ExpenseDraftErrorCode.emptyInput,
      );
    });

    test(
      'prompta tarih, kategori listeleri ve enjeksiyon korumasını ekler',
      () async {
        final client = _FakeGeminiClient(
          response: '''
{"type":"expense","amount":150,"merchant":"Taksi","date":"2026-11-26","category":"Ulaşım","items":[]}
''',
        );
        final service = ExpenseDraftService(client);

        final result = await service.extractDraft(
          rawText: 'Taksiye 150 lira verdim',
          today: today,
          categoriesByType: categories,
          source: TxSource.chat,
        );

        expect(client.callCount, 1);
        expect(client.lastSystemInstruction, contains('talimat'));
        expect(client.lastSystemInstruction, contains('satır toplam'));
        expect(client.lastUserPrompt, contains('2026-11-26'));
        expect(client.lastUserPrompt, contains('Market'));
        expect(client.lastUserPrompt, contains('Ulaşım'));
        expect(client.lastUserPrompt, contains('Maaş'));
        expect(client.lastUserPrompt, contains('<user_input>'));
        expect(client.lastUserPrompt, contains('Taksiye 150 lira verdim'));

        expect(result, isA<ExpenseDraftSuccess>());
        final draft = (result as ExpenseDraftSuccess).draft;
        expect(draft.amountTl, 150.0);
        expect(draft.categoryName, 'Ulaşım');
      },
    );

    test('kota aşımı hatasını quotaExceeded olarak döner', () async {
      final client = _FakeGeminiClient(error: QuotaExceeded('quota'));
      final service = ExpenseDraftService(client);

      final result = await service.extractDraft(
        rawText: 'Kahve 90 TL',
        today: today,
        categoriesByType: categories,
        source: TxSource.chat,
      );

      expect(result, isA<ExpenseDraftFailure>());
      expect(
        (result as ExpenseDraftFailure).error.code,
        ExpenseDraftErrorCode.quotaExceeded,
      );
    });

    test('ağ hatasını networkOrService olarak döner', () async {
      final client = _FakeGeminiClient(
        error: const SocketException('No internet'),
      );
      final service = ExpenseDraftService(client);

      final result = await service.extractDraft(
        rawText: 'Kahve 90 TL',
        today: today,
        categoriesByType: categories,
        source: TxSource.chat,
      );

      expect(result, isA<ExpenseDraftFailure>());
      expect(
        (result as ExpenseDraftFailure).error.code,
        ExpenseDraftErrorCode.networkOrService,
      );
    });

    test('Firebase başlatılmadığında notConfigured hatası döner', () async {
      final client = _FakeGeminiClient(
        error: const FirebaseNotInitializedException(),
      );
      final service = ExpenseDraftService(client);

      final result = await service.extractDraft(
        rawText: 'Kahve 90 TL',
        today: today,
        categoriesByType: categories,
        source: TxSource.chat,
      );

      expect(result, isA<ExpenseDraftFailure>());
      expect(
        (result as ExpenseDraftFailure).error.code,
        ExpenseDraftErrorCode.notConfigured,
      );
    });

    test(
      'yanıt vermeyen istemci zaman aşımına uğrayınca kontrollü hata döner',
      () async {
        final hangingClient = _HangingGeminiClient();
        final service = ExpenseDraftService(
          hangingClient,
          requestTimeout: const Duration(milliseconds: 20),
        );

        final result = await service.extractDraft(
          rawText: 'Kahve 90 TL',
          today: today,
          categoriesByType: categories,
          source: TxSource.chat,
        );

        expect(result, isA<ExpenseDraftFailure>());
        final error = (result as ExpenseDraftFailure).error;
        expect(error.code, ExpenseDraftErrorCode.networkOrService);
        expect(error.userMessage, contains('zaman aşımı'));
      },
    );
  });
}

class _HangingGeminiClient implements GeminiClient {
  @override
  Future<String> generateDraftJson({
    required String systemInstruction,
    required String userPrompt,
  }) => Completer<String>().future;
}
