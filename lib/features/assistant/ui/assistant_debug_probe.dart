import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format/dates.dart';
import '../../../core/models/enums.dart';
import '../../transactions/category_provider.dart';
import '../services/gemini/expense_draft_service.dart';
import '../services/gemini/gemini_client.dart';
import '../services/gemini/parsed_expense_draft.dart';

/// GEÇİCİ (yalnızca debug): Gerçek Firebase AI Logic / Gemini çağrısını
/// telefonda doğrulamak için kullanılır. Aşama 3'te sohbet ekranı gelince
/// kaldırılacaktır.
class AssistantDebugProbe extends StatefulWidget {
  const AssistantDebugProbe({super.key, this.service});

  final ExpenseDraftService? service;

  @override
  State<AssistantDebugProbe> createState() => _AssistantDebugProbeState();
}

class _AssistantDebugProbeState extends State<AssistantDebugProbe> {
  static const _sampleText = 'Taksiye 150 lira verdim';

  bool _loading = false;
  String? _output;
  bool _isError = false;

  Future<void> _runProbe() async {
    if (_loading) return;
    final categoryProvider = context.read<CategoryProvider>();
    final categoriesByType = <TxType, List<String>>{
      TxType.expense: categoryProvider
          .ofType(TxType.expense)
          .map((c) => c.name)
          .toList(),
      TxType.income: categoryProvider
          .ofType(TxType.income)
          .map((c) => c.name)
          .toList(),
    };

    setState(() {
      _loading = true;
      _output = null;
      _isError = false;
    });

    final service =
        widget.service ?? ExpenseDraftService(FirebaseGeminiClient());
    final result = await service.extractDraft(
      rawText: _sampleText,
      today: DateTime.now(),
      categoriesByType: categoriesByType,
      source: TxSource.chat,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (result) {
        case ExpenseDraftSuccess(:final draft):
          _isError = false;
          _output = _formatDraft(draft);
        case ExpenseDraftFailure(:final error):
          _isError = true;
          _output = error.userMessage;
      }
    });
  }

  String _formatDraft(ParsedExpenseDraft d) {
    final typeLabel = d.type == TxType.expense ? 'Gider' : 'Gelir';
    final lines = <String>[
      'Örnek: "$_sampleText"',
      'Tür: $typeLabel',
      'Tutar (TL): ${d.amountTl.toStringAsFixed(2)}',
      'Kategori: ${d.categoryName}${d.usedFallbackCategory ? ' (varsayılan)' : ''}',
      'İş yeri: ${d.merchant ?? '-'}',
      'Tarih: ${toDbDate(d.date)}${d.usedDefaultDate ? ' (tarih okunamadı, bugün)' : ''}',
      if (d.items.isNotEmpty) 'Kalem sayısı: ${d.items.length}',
    ];
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _runProbe,
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("AI'yı dene (geçici)"),
          ),
          if (_output != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isError
                    ? scheme.errorContainer
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _output!,
                style: TextStyle(
                  color: _isError ? scheme.onErrorContainer : scheme.onSurface,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
