import 'package:flutter/material.dart';

import '../../format/money.dart';
import '../../models/enums.dart';
import '../app_theme.dart';

/// Kuruş tutarını Türkçe biçimde yazar. Gider `-` önekli ve gider renginde,
/// gelir `+` önekli ve gelir renginde; tip yoksa işaret ve renk eklenmez.
class AmountText extends StatelessWidget {
  const AmountText(this.kurus, {super.key, this.type, this.style});

  final int kurus;
  final TxType? type;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final money = MoneyColors.of(context);
    final (text, color) = switch (type) {
      TxType.expense => ('-${formatKurus(kurus.abs())}', money.expense),
      TxType.income => ('+${formatKurus(kurus.abs())}', money.income),
      null => (formatKurus(kurus), null),
    };
    final base = style ?? DefaultTextStyle.of(context).style;
    return Text(
      text,
      style: base.copyWith(
        color: color ?? base.color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
