import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;

import '../../../core/format/money.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/enums.dart';
import '../../../core/repositories/chat_message_repository.dart';
import '../../transactions/category_provider.dart';
import '../../transactions/transaction_provider.dart';
import '../services/gemini/expense_draft_service.dart';
import '../services/gemini/parsed_expense_draft.dart';
import '../services/ocr/ocr_service.dart';

/// Onay bekleyen bellek içi işlem taslağı.
/// Kullanıcı onaylamadan veritabanına yazılmaz ve sohbet mesajına JSON olarak gömülmez.
class PendingDraft {
  const PendingDraft({
    required this.draft,
    this.assistantMessageId,
    this.receiptPath,
  });

  final ParsedExpenseDraft draft;
  final int? assistantMessageId;
  final String? receiptPath;
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
  final DateTime Function() _now;

  List<ChatMessage> _messages = const [];
  bool _isLoadingHistory = false;
  bool _isBusy = false;
  String? _errorMessage;
  PendingDraft? _pendingDraft;
  String? _lastFailedText;
  ReceiptImageSource? _lastFailedReceiptSource;
  int _lastKnownRevision = 0;
  bool _disposed = false;

  List<ChatMessage> get messages => _messages;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
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

  /// Yazılı mesaj gönderir ve Gemini üzerinden bellek içi taslak üretir.
  /// Aynı anda yalnızca tek istek çalışır.
  Future<void> sendText(String rawText) async {
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

      final result = await draftService.extractDraft(
        rawText: trimmed,
        today: _now(),
        categoriesByType: _categoriesByType(),
        source: TxSource.chat,
      );

      switch (result) {
        case ExpenseDraftSuccess(:final draft):
          await _replacePendingDraft(draft, receiptPath: null);
        case ExpenseDraftFailure(:final error):
          _errorMessage = error.userMessage;
          _lastFailedText = trimmed;
      }
    } catch (e) {
      debugPrint(
        'AssistantController: Mesaj gönderme hatası (${e.runtimeType})',
      );
      _errorMessage = 'İşlem sırasında bir hata oluştu. Tekrar deneyebilir veya manuel ekleyebilirsiniz.';
      _lastFailedText = trimmed;
    } finally {
      _isBusy = false;
      _safeNotify();
    }
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
    final previousPath = _pendingDraft?.receiptPath;
    if (previousPath != null && previousPath != receiptPath) {
      try {
        await receiptPipeline.scanService.storage.deleteReceipt(previousPath);
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
    _pendingDraft = PendingDraft(
      draft: draft,
      assistantMessageId: msgId,
      receiptPath: receiptPath,
    );
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
      await sendText(failedText);
    } else if (failedSource != null) {
      await scanReceipt(failedSource);
    }
  }

  /// Bellek içi bekleyen taslağı iptal eder (kaydedilmemiş fiş görselini de siler).
  Future<void> clearPendingDraft() async {
    final path = _pendingDraft?.receiptPath;
    _pendingDraft = null;
    _safeNotify();
    if (path != null) {
      try {
        await receiptPipeline.scanService.storage.deleteReceipt(path);
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
    transactions.removeListener(_onTransactionsChanged);
    super.dispose();
  }
}
