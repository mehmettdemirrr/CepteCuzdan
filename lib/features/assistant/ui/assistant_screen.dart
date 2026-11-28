import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/shell.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/enums.dart';
import '../../transactions/category_provider.dart';
import '../services/ocr/ocr_service.dart';
import '../state/assistant_controller.dart';
import 'confirmation_card.dart';
import 'draft_edit_sheet.dart';

/// Asistan sohbet ekranı.
/// 5 ekran durumunda (dikey, küçük, yatay 800×360, geniş, 2× yazı) taşmadan çalışır.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final controller = context.read<AssistantController>();
    if (controller.isBusy) return;
    _inputController.clear();
    await controller.sendText(text);
  }

  Future<void> _showReceiptSourceSheet() async {
    final controller = context.read<AssistantController>();
    if (controller.isBusy) return;

    final selected = await showModalBottomSheet<ReceiptImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                minTileHeight: 52,
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Kamera ile çek'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ReceiptImageSource.camera),
              ),
              ListTile(
                minTileHeight: 52,
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galeriden seç'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ReceiptImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    await controller.scanReceipt(selected);
  }

  Future<void> _handleEditPendingDraft() async {
    final controller = context.read<AssistantController>();
    final categories = context.read<CategoryProvider>();
    final pending = controller.pendingDraft;
    if (pending == null || pending.isSaved || controller.isSavingDraft) return;

    final categoriesByType = {
      TxType.expense: categories
          .ofType(TxType.expense)
          .map((c) => c.name)
          .toList(),
      TxType.income: categories
          .ofType(TxType.income)
          .map((c) => c.name)
          .toList(),
    };

    final editedDraftId = pending.draftId;
    final updated = await showDraftEditSheet(
      context,
      initial: pending.draft,
      categoriesByType: categoriesByType,
    );
    if (updated == null || !mounted) return;
    controller.updatePendingDraft(updated, expectedDraftId: editedDraftId);
  }

  Future<void> _handleSavePendingDraft() async {
    final controller = context.read<AssistantController>();
    final messenger = ScaffoldMessenger.of(context);
    final saved = await controller.confirmAndSavePendingDraft();
    if (!saved || !mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('İşlem kaydedildi.')));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AssistantController>();
    final messages = controller.messages;

    if (messages.length != _lastMessageCount) {
      _lastMessageCount = messages.length;
      if (messages.isNotEmpty) {
        _scrollToBottom();
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Asistan')),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            // Gövdenin gerçek yüksekliği: yatay ekran + büyük yazıda hata
            // bandı bu yüksekliğe göre sınırlanır (bant kendi içinde kayar).
            child: LayoutBuilder(
              builder: (context, body) => Column(
                children: [
                  if (controller.isBusy) const LinearProgressIndicator(),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final messageArea =
                            controller.isLoadingHistory && messages.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : messages.isEmpty
                            ? const _EmptyAssistantView()
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                itemCount: messages.length,
                                itemBuilder: (context, index) =>
                                    _MessageBubble(message: messages[index]),
                              );

                        final pending = controller.pendingDraft;
                        if (pending == null) return messageArea;

                        final avail = constraints.maxHeight;
                        // Yatay/küçük ekranda onay kartı kullanılabilir alanın
                        // üst sınırını aşmaz; mesaj alanı kalan yüksekliği alır.
                        final cardMaxHeight = avail < 140
                            ? avail
                            : (avail * (avail < 280 ? 0.72 : 0.62)).clamp(
                                0.0,
                                360.0,
                              );

                        return Column(
                          children: [
                            if (avail >= 140) Expanded(child: messageArea),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: cardMaxHeight,
                              ),
                              child: ConfirmationCard(
                                pending: pending,
                                isSaving: controller.isSavingDraft,
                                saveErrorMessage: controller.saveErrorMessage,
                                currencyStyle: controller.currencyStyle,
                                onSave: _handleSavePendingDraft,
                                onEdit: _handleEditPendingDraft,
                                onCancel: controller.clearPendingDraft,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (controller.isListening)
                    _VoiceListeningBanner(
                      partialText: controller.partialSpeechText,
                      onStop: controller.toggleVoiceInput,
                      onCancel: controller.cancelVoiceInput,
                    ),
                  if (controller.errorMessage != null)
                    _ErrorBanner(
                      message: controller.errorMessage!,
                      canRetry: controller.canRetry && !controller.isBusy,
                      onRetry: controller.retryLast,
                      onManualAdd: () =>
                          AppShell.selectTab(context, AppShell.transactionsTab),
                      onDismiss: controller.clearError,
                      availableHeight: body.maxHeight,
                    ),
                  _InputBar(
                    controller: _inputController,
                    isBusy: controller.isBusy,
                    isListening: controller.isListening,
                    hasVoiceSupport: controller.hasVoiceSupport,
                    onSend: _handleSend,
                    onCameraTap: _showReceiptSourceSheet,
                    onMicTap: controller.toggleVoiceInput,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyAssistantView extends StatelessWidget {
  const _EmptyAssistantView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 40,
                  color: scheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Harcama veya gelirinizi yazın ya da fiş fotoğrafı ekleyin.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Örnek: "Taksiye 150 lira verdim" veya kamera simgesinden fiş çekin. Onayınız olmadan kayıt yapılmaz.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isUser = message.role == ChatRole.user;
    final rolePrefix = isUser ? 'Sen' : 'Asistan';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Semantics(
          label: '$rolePrefix: ${message.content}',
          excludeSemantics: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isUser
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rolePrefix,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isUser
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isUser
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.canRetry,
    required this.onRetry,
    required this.onManualAdd,
    required this.onDismiss,
    this.availableHeight,
  });

  final String message;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onManualAdd;
  final VoidCallback onDismiss;

  /// Asistan gövdesinin yüksekliği; mesaj metni bunun en fazla beşte birini alır.
  final double? availableHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Yalnızca mesaj metni kayar; eylem düğmeleri (Tekrar dene, Manuel ekle,
    // kapat) her zaman görünür kalır. Mesaj, gövde yüksekliğinin en fazla
    // beşte birini alır (yatay + büyük yazıda taşmasın diye).
    final defaultMax = MediaQuery.sizeOf(context).height < 480 ? 64.0 : 124.0;
    final available = availableHeight;
    final maxMessageHeight = available == null || !available.isFinite
        ? defaultMax
        : (available * 0.2).clamp(32.0, defaultMax);

    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Icon(Icons.error_outline, color: scheme.onErrorContainer),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxMessageHeight),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Text(
                        message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (canRetry)
                        TextButton(
                          onPressed: onRetry,
                          child: const Text('Tekrar dene'),
                        ),
                      TextButton(
                        onPressed: onManualAdd,
                        child: const Text('Manuel ekle'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Hata mesajını kapat',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: onDismiss,
              icon: Icon(Icons.close, color: scheme.onErrorContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceListeningBanner extends StatelessWidget {
  const _VoiceListeningBanner({
    required this.partialText,
    required this.onStop,
    required this.onCancel,
  });

  final String partialText;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.mic, color: scheme.onPrimaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                partialText.isEmpty
                    ? 'Dinleniyor… Türkçe konuşabilirsiniz.'
                    : partialText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            TextButton(onPressed: onStop, child: const Text('Bitir')),
            IconButton(
              tooltip: 'Dinlemeyi iptal et',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: onCancel,
              icon: Icon(Icons.close, color: scheme.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isBusy,
    required this.isListening,
    required this.hasVoiceSupport,
    required this.onSend,
    required this.onCameraTap,
    required this.onMicTap,
  });

  final TextEditingController controller;
  final bool isBusy;
  final bool isListening;
  final bool hasVoiceSupport;
  final VoidCallback onSend;
  final VoidCallback onCameraTap;
  final VoidCallback onMicTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Fiş fotoğrafı ekle',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: isBusy || isListening ? null : onCameraTap,
                icon: const Icon(Icons.photo_camera_outlined),
              ),
              IconButton(
                tooltip: !hasVoiceSupport
                    ? 'Sesli komut (yakında)'
                    : isListening
                    ? 'Dinlemeyi durdur'
                    : 'Sesli komut',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: !hasVoiceSupport || isBusy ? null : onMicTap,
                icon: Icon(
                  isListening ? Icons.mic : Icons.mic_none_outlined,
                  color: isListening ? scheme.error : null,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !isBusy && !isListening,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 1000,
                  buildCounter: (
                    _, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) => null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: 'Harcama veya gelir yazın…',
                    // Dar alanda (yatay + büyük yazı) ipucu tek satırda kalsın.
                    hintMaxLines: 1,
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final canSend =
                      !isBusy && !isListening && value.text.trim().isNotEmpty;
                  return IconButton(
                    tooltip: 'Gönder',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: canSend ? onSend : null,
                    icon: const Icon(Icons.send),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
