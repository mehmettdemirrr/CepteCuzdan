/// Bir tarih aralığındaki toplamlar (kuruş). Kategori map'lerinin anahtarı
/// kategori id'sidir.
class PeriodSummary {
  const PeriodSummary({
    required this.incomeTotal,
    required this.expenseTotal,
    this.expenseByCategory = const {},
    this.incomeByCategory = const {},
  });

  static const empty = PeriodSummary(incomeTotal: 0, expenseTotal: 0);

  final int incomeTotal;
  final int expenseTotal;
  final Map<int, int> expenseByCategory;
  final Map<int, int> incomeByCategory;

  int get balance => incomeTotal - expenseTotal;
}
