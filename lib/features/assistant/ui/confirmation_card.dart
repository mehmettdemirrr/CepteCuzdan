import 'package:flutter/material.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/models/enums.dart';
import '../state/assistant_controller.dart';

/// AI tarafından üretilen işlem taslağının onay kartı.
/// Kullanıcı "Kaydet" demeden veritabanına hiçbir şey yazılmaz.
/// Yatay ekranda kaydırılabilir; Kaydet/Düzenle/İptal düğmeleri ≥ 48×48 dp.
class ConfirmationCard extends StatelessWidget {
  const ConfirmationCard({
    super.key,
    required this.pending,
    required this.isSaving,
    required this.onSave,
    required this.onEdit,
    required this.onCancel,
    this.saveErrorMessage,
  });

  final PendingDraft pending;
  final bool isSaving;
  final String? saveErrorMessage;
  final VoidCallback onSave;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final draft = pending.draft;
    final amountText = formatKurus(tlToKurus(draft.amountTl));
    final typeLabel = draft.type == TxType.income ? 'Gelir' : 'Gider';
    final sourceLabel = switch (draft.source) {
      TxSource.receipt => 'Fiş',
      TxSource.voice => 'Ses',
      TxSource.chat => 'Sohbet',
      TxSource.manual => 'Manuel',
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: pending.isSaved
          ? scheme.tertiaryContainer
          : scheme.surfaceContainerHigh,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  pending.isSaved
                      ? Icons.check_circle_outline
                      : Icons.receipt_long_outlined,
                  color: pending.isSaved
                      ? scheme.onTertiaryContainer
                      : scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pending.isSaved
                        ? 'Kaydedildi'
                        : 'Onay bekleyen $typeLabel ($sourceLabel)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: pending.isSaved
                          ? scheme.onTertiaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                ),
                if (pending.isSaved)
                  IconButton(
                    tooltip: 'Kartı kapat',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: onCancel,
                    icon: Icon(Icons.close, color: scheme.onTertiaryContainer),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              amountText,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: pending.isSaved
                    ? scheme.onTertiaryContainer
                    : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _InfoChip(
                  icon: Icons.category_outlined,
                  label: draft.categoryName,
                ),
                _InfoChip(
                  icon: Icons.calendar_today_outlined,
                  label: toDbDate(draft.date),
                ),
                if (draft.merchant != null && draft.merchant!.trim().isNotEmpty)
                  _InfoChip(
                    icon: Icons.storefront_outlined,
                    label: draft.merchant!,
                  ),
              ],
            ),
            if (draft.usedDefaultDate || draft.usedFallbackCategory) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (draft.usedDefaultDate)
                    _WarningNote(
                      text: 'Tarih okunamadı, bugün seçildi.',
                      color: scheme.onSurfaceVariant,
                    ),
                  if (draft.usedFallbackCategory)
                    _WarningNote(
                      text: 'Kategori eşleşmedi, Diğer seçildi.',
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
            ],
            if (draft.items.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 6),
              Text(
                'Ürün kalemleri (${draft.items.length})',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              for (final item in draft.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.quantity == 1
                              ? item.name
                              : '${item.name} ×${item.quantity}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatKurus(tlToKurus(item.priceTl)),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
            ],
            if (saveErrorMessage != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.error_outline, size: 18, color: scheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      saveErrorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (!pending.isSaved) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: isSaving ? null : onSave,
                    icon: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(isSaving ? 'Kaydediliyor…' : 'Kaydet'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: isSaving ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Düzenle'),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: isSaving ? null : onCancel,
                    icon: const Icon(Icons.close),
                    label: const Text('İptal'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningNote extends StatelessWidget {
  const _WarningNote({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.info_outline, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
