import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;

import '../../../core/format/money.dart';
import '../../../core/format/text.dart';
import '../../../core/models/category.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/receipt_item.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/repositories/chat_message_repository.dart';
import '../../transactions/category_provider.dart';
import '../../transactions/transaction_provider.dart';
import '../services/gemini/expense_draft_service.dart';
import '../services/gemini/parsed_expense_draft.dart';
import '../services/ocr/ocr_service.dart';
import '../services/query/budget_query_service.dart';
import '../services/speech/speech_service.dart';

/// Onay bekleyen bellek içi işlem taslağı.
/// Kullanıcı onaylamadan veritabanına yazılmaz ve sohbet mesajına JSON olarak gömülmez.
class PendingDraft {
  const PendingDraft({
    required this.draftId,
    required this.draft,
    this.assistantMessageId,
    this.receiptPath,
    this.isSaved = false,
  });

  final String draftId;
  final ParsedExpenseDraft draft;
  final int? assistantMessageId;
  final String? receiptPath;
  final bool isSaved;

  PendingDraft copyWith({
    ParsedExpenseDraft? draft,
    int? assistantMessageId,
    bool? isSaved,
  }) => PendingDraft(
    draftId: draftId,
    draft: draft ?? this.draft,
    assistantMessageId: assistantMessageId ?? this.assistantMessageId,
    receiptPath: receiptPath,
    isSaved: isSaved ?? this.isSaved,
  );
}

/// Asistan sohbet ekranının durum yöneticisi.
/// UI'dan bağımsızdır; SQL çalıştırmaz, tüm dış servisleri arayüzler üzerinden çağırır.
class AssistantController extends ChangeNotifier {
  AssistantController({
    required this.chats,
    required this.transactions,
    required this.categories,
    required this.draftService,
    required this.receiptPipeline,
    this.speechService,
    this.budgetQueryService,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _lastKnownRevision = transactions.revision;
    transactions.addListener(_onTransactionsChanged);
  }

  final ChatMessageRepository chats;
  final TransactionProvider transactions;
  final CategoryProvider categories;
  final ExpenseDraftService draftService;
  final ReceiptDraftPipeline receiptPipeline;
  final SpeechService? speechService;
  final BudgetQueryService? budgetQueryService;
  final DateTime Function() _now;

  List<ChatMessage> _messages = const [];
  bool _isLoadingHistory = false;
  bool _isBusy = false;
  bool _isListening = false;
  String _partialSpeechText = '';
  bool _isSavingDraft = false;
  String? _errorMessage;
  String? _saveErrorMessage;
  PendingDraft? _pendingDraft;
  String? _lastFailedText;
  TxSource _lastFailedTextSource = TxSource.chat;
  ReceiptImageSource? _lastFailedReceiptSource;
  int _lastKnownRevision = 0;
  int _draftSeq = 0;
  bool _disposed = false;

  List<ChatMessage> get messages => _messages;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isBusy => _isBusy;
  bool get isListening => _isListening;
  String get partialSpeechText => _partialSpeechText;
  bool get hasVoiceSupport => speechService != null;
  bool get isSavingDraft => _isSavingDraft;
  String? get errorMessage => _errorMessage;
  String? get saveErrorMessage => _saveErrorMessage;
  PendingDraft? get pendingDraft => _pendingDraft;
  bool get canRetry =>
      _lastFailedText != null || _lastFailedReceiptSource != null;

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _onTransactionsChanged() {
    if (transactions.revision == _lastKnownRevision) return;
    _lastKnownRevision = transactions.revision;
    _reloadAfterExternalChange();
  }

  Future<void> _reloadAfterExternalChange() async {
    try {
      final loaded = await chats.all();
      if (_disposed) return;
      _messages = loaded;
      // "Verileri sıfırla" sohbet geçmişini temizler; bekleyen taslak ve
      // cihazdaki fiş dosyaları da buna paralel temizlenir.
      if (loaded.isEmpty) {
        _pendingDraft = null;
        _errorMessage = null;
        try {
          await receiptPipeline.scanService.storage.deleteAllReceipts();
        } catch (e) {
          debugPrint(
            'AssistantController: Fiş dosyaları temizlenemedi (${e.runtimeType})',
          );
        }
      }
      _safeNotify();
    } catch (e) {
      debugPrint('AssistantController: Geçmiş yenilenemedi (${e.runtimeType})');
    }
  }

  /// Sohbet geçmişini `ChatMessageRepository`'den yükler.
  Future<void> loadHistory() async {
    _isLoadingHistory = true;
    _safeNotify();
    try {
      _messages = await chats.all();
    } catch (e) {
      debugPrint('AssistantController: Geçmiş yüklenemedi (${e.runtimeType})');
      _errorMessage = 'Sohbet geçmişi yüklenemedi.';
    } finally {
      _isLoadingHistory = false;
      _safeNotify();
    }
  }

  Map<TxType, List<String>> _categoriesByType() => {
    TxType.expense: categories
        .ofType(TxType.expense)
        .map((c) => c.name)
        .toList(),
    TxType.income: categories.ofType(TxType.income).map((c) => c.name).toList(),
  };

  /// Yazılı veya sesli metin gönderir ve Gemini üzerinden bellek içi taslak üretir.
  /// Aynı anda yalnızca tek istek çalışır.
  Future<void> sendText(
    String rawText, {
    TxSource source = TxSource.chat,
  }) async {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty || _isBusy) return;

    _isBusy = true;
    _errorMessage = null;
    _lastFailedText = null;
    _lastFailedReceiptSource = null;
    _safeNotify();

    try {
      await chats.add(
        ChatMessage(role: ChatRole.user, content: trimmed, createdAt: _now()),
      );
      _messages = await chats.all();
      _safeNotify();

      // Bütçe/harcama sorusuysa yerelde hesapla; Gemini'yi çağırma.
      final localAnswer = await budgetQueryService?.tryAnswer(
        trimmed,
        now: _now(),
      );
      if (localAnswer != null) {
        await chats.add(
          ChatMessage(
            role: ChatRole.assistant,
            content: localAnswer,
            createdAt: _now(),
          ),
        );
        _messages = await chats.all();
        return;
      }

      final result = await draftService.extractDraft(
        rawText: trimmed,
        today: _now(),
        categoriesByType: _categoriesByType(),
        source: source,
      );

      switch (result) {
        case ExpenseDraftSuccess(:final draft):
          await _replacePendingDraft(draft, receiptPath: null);
        case ExpenseDraftFailure(:final error):
          _errorMessage = error.userMessage;
          _lastFailedText = trimmed;
          _lastFailedTextSource = source;
      }
    } catch (e) {
      debugPrint(
        'AssistantController: Mesaj gönderme hatası (${e.runtimeType})',
      );
      _errorMessage = 'İşlem sırasında bir hata oluştu. Tekrar deneyebilir veya manuel ekleyebilirsiniz.';
      _lastFailedText = trimmed;
      _lastFailedTextSource = source;
    } finally {
      _isBusy = false;
      _safeNotify();
    }
  }

  /// Türkçe sesli komut dinlemesini başlatır veya durdurur.
  /// Sonuç metni aynı Gemini hattından (`source: TxSource.voice`) geçirilir.
  Future<void> toggleVoiceInput() async {
    final service = speechService;
    if (service == null || _isBusy || _isSavingDraft) return;

    if (_isListening) {
      await service.stopListening();
      _isListening = false;
      _partialSpeechText = '';
      _safeNotify();
      return;
    }

    _errorMessage = null;
    _partialSpeechText = '';
    _safeNotify();

    final startError = await service.startListening(
      onPartial: (partial) {
        _partialSpeechText = partial;
        _safeNotify();
      },
      onFinal: (finalText) {
        _isListening = false;
        _partialSpeechText = '';
        _safeNotify();
        sendText(finalText, source: TxSource.voice);
      },
      onError: (error) {
        _isListening = false;
        _partialSpeechText = '';
        _errorMessage = error.userMessage;
        _safeNotify();
      },
    );

    if (startError != null) {
      _isListening = false;
      _partialSpeechText = '';
      _errorMessage = startError.userMessage;
      _safeNotify();
      return;
    }

    _isListening = true;
    _safeNotify();
  }

  /// Devam eden ses dinlemesini iptal eder; Gemini çağrılmaz.
  Future<void> cancelVoiceInput() async {
    final service = speechService;
    if (service == null) return;
    await service.cancelListening();
    _isListening = false;
    _partialSpeechText = '';
    _safeNotify();
  }

  /// Kamera veya galeriden fiş seçip cihaz içi OCR + Gemini ile taslak üretir.
  Future<void> scanReceipt(ReceiptImageSource source) async {
    if (_isBusy) return;

    _isBusy = true;
    _errorMessage = null;
    _lastFailedText = null;
    _lastFailedReceiptSource = null;
    _safeNotify();

    try {
      final result = await receiptPipeline.scanReceiptToDraft(
        source: source,
        today: _now(),
        categoriesByType: _categoriesByType(),
      );

      switch (result) {
        case ReceiptDraftOcrFailure(:final error):
          if (error.code != OcrErrorCode.cancelled) {
            _errorMessage = error.userMessage;
            _lastFailedReceiptSource = source;
          }
        case ReceiptDraftAiFailure(:final error):
          _errorMessage = error.userMessage;
          _lastFailedReceiptSource = source;
        case ReceiptDraftSuccess(:final draft, :final receiptPath):
          await chats.add(
            ChatMessage(
              role: ChatRole.user,
              content: source == ReceiptImageSource.camera
                  ? 'Fiş fotoğrafı çekildi'
                  : 'Galeriden fiş seçildi',
              createdAt: _now(),
            ),
          );
          await _replacePendingDraft(draft, receiptPath: receiptPath);
      }
    } catch (e) {
      debugPrint('AssistantController: Fiş tarama hatası (${e.runtimeType})');
      _errorMessage = 'Fiş işlenirken bir hata oluştu. Tekrar deneyebilir veya manuel ekleyebilirsiniz.';
      _lastFailedReceiptSource = source;
    } finally {
      _isBusy = false;
      _safeNotify();
    }
  }

  Future<void> _replacePendingDraft(
    ParsedExpenseDraft draft, {
    required String? receiptPath,
  }) async {
    final previous = _pendingDraft;
    if (previous != null &&
        !previous.isSaved &&
        previous.receiptPath != null &&
        previous.receiptPath != receiptPath) {
      try {
        await receiptPipeline.scanService.storage.deleteReceipt(
          previous.receiptPath!,
        );
      } catch (e) {
        debugPrint(
          'AssistantController: Önceki fiş temizlenemedi (${e.runtimeType})',
        );
      }
    }

    final summary = _formatDraftSummary(draft);
    final msgId = await chats.add(
      ChatMessage(
        role: ChatRole.assistant,
        content: summary,
        createdAt: _now(),
      ),
    );
    _messages = await chats.all();
    _saveErrorMessage = null;
    _pendingDraft = PendingDraft(
      draftId: 'draft_${++_draftSeq}',
      draft: draft,
      assistantMessageId: msgId,
      receiptPath: receiptPath,
    );
  }

  /// Düzenle alt sayfasından gelen güncel taslağı bellekte günceller.
  void updatePendingDraft(ParsedExpenseDraft updated) {
    final current = _pendingDraft;
    if (current == null || current.isSaved) return;
    _pendingDraft = current.copyWith(draft: updated);
    _saveErrorMessage = null;
    _safeNotify();
  }

  Category? _resolveCategory(String categoryName, TxType type) {
    final list = categories.ofType(type);
    if (list.isEmpty) return null;
    final target = foldTr(categoryName);
    for (final c in list) {
      if (foldTr(c.name) == target) return c;
    }
    final other = foldTr('Diğer');
    for (final c in list) {
      if (foldTr(c.name) == other) return c;
    }
    return list.first;
  }

  /// Onay kartındaki taslağı yalnızca [TransactionProvider.add] üzerinden
  /// güvenli biçimde kaydeder. Çift tıklama ve mükerrer kayda karşı korumalıdır.
  Future<bool> confirmAndSavePendingDraft() async {
    final pending = _pendingDraft;
    if (pending == null || pending.isSaved || _isSavingDraft) return false;

    _isSavingDraft = true;
    _saveErrorMessage = null;
    _safeNotify();

    try {
      if (!categories.loaded) {
        await categories.load();
      }
      final draft = pending.draft;
      final amountKurus = tlToKurus(draft.amountTl);
      if (amountKurus <= 0) {
        _saveErrorMessage = 'Tutar sıfırdan büyük olmalıdır.';
        return false;
      }

      final category = _resolveCategory(draft.categoryName, draft.type);
      if (category?.id == null) {
        _saveErrorMessage =
            'Kategori bulunamadı. Lütfen düzenleyip tekrar deneyin.';
        return false;
      }

      final record = TransactionRecord(
        type: draft.type,
        amount: amountKurus,
        categoryId: category!.id!,
        date: draft.date,
        merchant: draft.merchant,
        source: draft.source,
        receiptPath: pending.receiptPath,
        createdAt: _now(),
      );

      final items = draft.items
          .map(
            (i) => ReceiptItem(
              name: i.name,
              quantity: i.quantity,
              price: tlToKurus(i.priceTl),
            ),
          )
          .where((i) => i.price > 0)
          .toList();

      final txId = await transactions.add(record, items: items);

      if (pending.assistantMessageId != null) {
        try {
          await chats.linkTransaction(pending.assistantMessageId!, txId);
        } catch (e) {
          debugPrint(
            'AssistantController: Mesaj işleme bağlanamadı (${e.runtimeType})',
          );
        }
      }

      _messages = await chats.all();
      if (_pendingDraft?.draftId == pending.draftId) {
        _pendingDraft = pending.copyWith(isSaved: true);
      }
      return true;
    } catch (e) {
      debugPrint('AssistantController: Kayıt hatası (${e.runtimeType})');
      _saveErrorMessage = 'İşlem kaydedilemedi. Tekrar deneyebilirsiniz.';
      return false;
    } finally {
      _isSavingDraft = false;
      _safeNotify();
    }
  }

  String _formatDraftSummary(ParsedExpenseDraft draft) {
    final typeLabel = draft.type == TxType.income ? 'Gelir' : 'Gider';
    final amountText = formatKurus(tlToKurus(draft.amountTl));
    final merchantPart =
        draft.merchant != null && draft.merchant!.trim().isNotEmpty
        ? ' · ${draft.merchant}'
        : '';
    return 'Taslak hazır: $amountText · ${draft.categoryName} ($typeLabel)$merchantPart';
  }

  /// Son başarısız isteği tekrar dener.
  Future<void> retryLast() async {
    if (_isBusy) return;
    final failedText = _lastFailedText;
    final failedSource = _lastFailedReceiptSource;
    if (failedText != null) {
      await sendText(failedText, source: _lastFailedTextSource);
    } else if (failedSource != null) {
      await scanReceipt(failedSource);
    }
  }

  /// Bellek içi bekleyen taslağı iptal eder (kaydedilmemiş fiş görselini de siler).
  Future<void> clearPendingDraft() async {
    final current = _pendingDraft;
    _pendingDraft = null;
    _saveErrorMessage = null;
    _safeNotify();
    if (current != null && !current.isSaved && current.receiptPath != null) {
      try {
        await receiptPipeline.scanService.storage.deleteReceipt(
          current.receiptPath!,
        );
      } catch (e) {
        debugPrint(
          'AssistantController: İptal edilen fiş silinemedi (${e.runtimeType})',
        );
      }
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_isListening) {
      speechService?.cancelListening();
    }
    transactions.removeListener(_onTransactionsChanged);
    super.dispose();
  }
}
