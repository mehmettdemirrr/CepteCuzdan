import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/enums.dart';
import '../../core/models/transaction_record.dart';
import '../../core/ui/widgets/amount_text.dart';
import '../../core/ui/widgets/category_avatar.dart';
import 'category_provider.dart';

/// Bir işlem satırı: kategori ikonu, işletme/kategori, not, kaynak etiketi
/// (Fiş/Ses/Sohbet) ve tutar. İşlemler listesi ve Dashboard kullanır.
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.tx, this.onTap});

  final TransactionRecord tx;
  final VoidCallback? onTap;

  static const _sourceLabels = {
    TxSource.receipt: 'Fiş',
    TxSource.voice: 'Ses',
    TxSource.chat: 'Sohbet',
  };

  @override
  Widget build(BuildContext context) {
    final category = context.watch<CategoryProvider>().byId(tx.categoryId);
    final categoryName = category?.name ?? 'Kategori yok';
    final merchant = tx.merchant;
    final title = merchant ?? categoryName;
    final subtitle = [
      if (merchant != null) categoryName,
      if (tx.note != null) tx.note!,
      if (_sourceLabels[tx.source] != null) _sourceLabels[tx.source]!,
    ].join(' · ');

    final amount = AmountText(
      tx.amount,
      type: tx.type,
      style: Theme.of(context).textTheme.titleMedium,
    );
    // Büyük yazıda tutar sağda sığmaz; başlığın altına iner.
    final large = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final subtitleText = subtitle.isEmpty
        ? null
        : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis);

    return ListTile(
      onTap: onTap,
      leading: category == null
          ? const CircleAvatar(child: Icon(Icons.help_outline))
          : CategoryAvatar(category),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [?subtitleText, amount],
            )
          : subtitleText,
      trailing: large ? null : amount,
    );
  }
}
