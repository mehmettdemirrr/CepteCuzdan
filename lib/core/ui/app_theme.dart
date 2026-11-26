import 'package:flutter/material.dart';

/// Gelir ve gider tutarlarının renkleri; iki temada da tanımlıdır.
@immutable
class MoneyColors extends ThemeExtension<MoneyColors> {
  const MoneyColors({required this.income, required this.expense});

  final Color income;
  final Color expense;

  static const light = MoneyColors(
    income: Color(0xFF2E7D32),
    expense: Color(0xFFC62828),
  );
  static const dark = MoneyColors(
    income: Color(0xFF81C784),
    expense: Color(0xFFEF9A9A),
  );

  static MoneyColors of(BuildContext context) =>
      Theme.of(context).extension<MoneyColors>() ?? light;

  @override
  MoneyColors copyWith({Color? income, Color? expense}) => MoneyColors(
    income: income ?? this.income,
    expense: expense ?? this.expense,
  );

  @override
  MoneyColors lerp(MoneyColors? other, double t) {
    if (other == null) return this;
    return MoneyColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
    );
  }
}

class AppTheme {
  AppTheme._();

  /// Tohum renk (Berkay ile onaylanacak).
  static const seed = Color(0xFF00897B);

  static ThemeData light() => _build(Brightness.light, MoneyColors.light);

  static ThemeData dark() => _build(Brightness.dark, MoneyColors.dark);

  static ThemeData _build(Brightness brightness, MoneyColors money) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [money],
      appBarTheme: const AppBarTheme(centerTitle: false),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      cardTheme: const CardThemeData(margin: EdgeInsets.zero),
    );
  }
}
