import '../../../../core/format/dates.dart';
import '../../../../core/format/money.dart';
import '../../../../core/format/text.dart';
import '../../../../core/models/category.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/repositories/category_repository.dart';
import '../../../../core/repositories/transaction_repository.dart';

/// Bütçe ve harcama sorularını yerelde (`TransactionRepository.summarize`)
/// yanıtlayan servis. Modele işlem listesi gönderilmez, hesap yerelde yapılır.
class BudgetQueryService {
  const BudgetQueryService({
    required this.transactions,
    required this.categories,
  });

  final TransactionRepository transactions;
  final CategoryRepository categories;

  static const _questionCues = [
    'ne kadar',
    'kac lira',
    'kac tl',
    'toplam',
    'ozet',
    'bakiye',
    'durumum',
    'butcem',
    'butce',
    'kaldi',
    'ne harcadim',
    'neler harcadim',
  ];

  static const _summaryCues = ['ozet', 'bakiye', 'durum', 'butce', 'kaldi'];
  static const _incomeCues = ['gelir', 'maas', 'kazan'];

  static String _normalize(String s) =>
      foldTr(s)
          .replaceAll('ç', 'c')
          .replaceAll('ğ', 'g')
          .replaceAll('ı', 'i')
          .replaceAll('ö', 'o')
          .replaceAll('ş', 's')
          .replaceAll('ü', 'u');

  /// Metnin yeni bir işlem kaydı değil, bütçe/harcama sorusu olup olmadığını belirler.
  static bool isBudgetQuestion(String rawText) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return false;
    final folded = _normalize(trimmed);

    final hasQuestionCue =
        trimmed.contains('?') || _questionCues.any(folded.contains);
    if (!hasQuestionCue) return false;

    // Soru işareti yokken metinde somut tutar + kayıt fiili varsa (örn. "150 tl verdim")
    // bu bir harcama kaydıdır, soru değil.
    final hasDigit = RegExp(r'\d').hasMatch(trimmed);
    if (!trimmed.contains('?') &&
        hasDigit &&
        (folded.contains('verdim') ||
            folded.contains('aldim') ||
            folded.contains('odedim'))) {
      return false;
    }

    return true;
  }

  /// Metin bir bütçe/harcama sorusuysa yerel SQLite özetinden Türkçe yanıt döner;
  /// soru değilse `null` döner (akış normal taslak çıkarmaya devam eder).
  Future<String?> tryAnswer(String rawText, {required DateTime now}) async {
    if (!isBudgetQuestion(rawText)) return null;

    final folded = _normalize(rawText);
    final period = _parsePeriod(folded, now);
    final summary = await transactions.summarize(period.range);
    final allCategories = await categories.all();

    final isIncomeQuery = _incomeCues.any(folded.contains);
    final matchedCategory = _matchCategory(
      folded,
      allCategories,
      preferIncome: isIncomeQuery,
    );

    final isSummaryQuery =
        matchedCategory == null && _summaryCues.any(folded.contains);

    if (isSummaryQuery) {
      if (summary.incomeTotal == 0 && summary.expenseTotal == 0) {
        return '${period.label} henüz kayıtlı bir gelir veya gideriniz bulunmuyor.';
      }
      return '${period.label} toplam geliriniz ${formatKurus(summary.incomeTotal)}, '
          'gideriniz ${formatKurus(summary.expenseTotal)}. '
          'Net bakiyeniz ${formatKurus(summary.balance)}.';
    }

    if (matchedCategory != null) {
      final isIncomeCat = matchedCategory.type == TxType.income;
      final totalKurus = isIncomeCat
          ? (summary.incomeByCategory[matchedCategory.id] ?? 0)
          : (summary.expenseByCategory[matchedCategory.id] ?? 0);

      if (totalKurus == 0) {
        final kind = isIncomeCat ? 'geliriniz' : 'gideriniz';
        return '${period.label} ${matchedCategory.name} kategorisinde kayıtlı $kind bulunmuyor.';
      }
      final verb = isIncomeCat ? 'gelir elde ettiniz' : 'harcadınız';
      return '${period.label} ${matchedCategory.name} kategorisinde toplam ${formatKurus(totalKurus)} $verb.';
    }

    if (isIncomeQuery) {
      if (summary.incomeTotal == 0) {
        return '${period.label} kayıtlı bir geliriniz bulunmuyor.';
      }
      return '${period.label} toplam geliriniz ${formatKurus(summary.incomeTotal)}.';
    }

    if (summary.expenseTotal == 0) {
      return '${period.label} kayıtlı bir harcamanız bulunmuyor.';
    }
    return '${period.label} toplam ${formatKurus(summary.expenseTotal)} harcadınız.';
  }

  _ParsedPeriod _parsePeriod(String folded, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (folded.contains('bugun')) {
      return _ParsedPeriod('Bugün', DateRange(today, today));
    }
    if (folded.contains('dun')) {
      final yesterday = today.subtract(const Duration(days: 1));
      return _ParsedPeriod('Dün', DateRange(yesterday, yesterday));
    }
    if (folded.contains('gecen hafta')) {
      return _ParsedPeriod(
        'Geçen hafta',
        weekOf(today.subtract(const Duration(days: 7))),
      );
    }
    if (folded.contains('bu hafta')) {
      return _ParsedPeriod('Bu hafta', weekOf(today));
    }
    if (folded.contains('gecen ay')) {
      return _ParsedPeriod(
        'Geçen ay',
        monthOf(DateTime(today.year, today.month - 1, 1)),
      );
    }
    if (folded.contains('bu yil') || folded.contains('bu sene')) {
      return _ParsedPeriod(
        'Bu yıl',
        DateRange(DateTime(today.year, 1, 1), DateTime(today.year, 12, 31)),
      );
    }
    return _ParsedPeriod('Bu ay', monthOf(today));
  }

  Category? _matchCategory(
    String foldedQuery,
    List<Category> allCategories, {
    required bool preferIncome,
  }) {
    final ordered = [
      ...allCategories.where(
        (c) =>
            preferIncome ? c.type == TxType.income : c.type == TxType.expense,
      ),
      ...allCategories.where(
        (c) =>
            preferIncome ? c.type == TxType.expense : c.type == TxType.income,
      ),
    ];

    for (final cat in ordered) {
      final foldedName = _normalize(cat.name);
      if (foldedName.isEmpty || foldedName == 'diger') continue;

      // Tam ad veya tire yerine boşluklu eşleşme ("yeme-icme" -> "yeme icme")
      final normalizedName = foldedName.replaceAll('-', ' ');
      if (foldedQuery.contains(foldedName) ||
          foldedQuery.contains(normalizedName)) {
        return cat;
      }

      // Türkçe çekim ekleri için kök eşleşmesi (örn. "sağlığa" -> "sagl", "ulaşıma" -> "ulasim", "faturalara" -> "fatura")
      final stems = _turkishStems(normalizedName);
      for (final stem in stems) {
        if (stem.length >= 4 && foldedQuery.contains(stem)) {
          return cat;
        }
      }
    }
    return null;
  }

  List<String> _turkishStems(String normalizedName) {
    final result = <String>[];
    for (final token in normalizedName.split(' ')) {
      if (token.length < 4) continue;
      result.add(token);
      // Yumuşama (k -> g, p -> b, t -> d, ç -> c) veya çoğul (-lar/-ler)
      if (token.endsWith('lar') || token.endsWith('ler')) {
        result.add(token.substring(0, token.length - 3));
      }
      if (token.endsWith('k') || token.endsWith('p') || token.endsWith('t')) {
        result.add(token.substring(0, token.length - 1));
      }
    }
    return result;
  }
}

class _ParsedPeriod {
  const _ParsedPeriod(this.label, this.range);

  final String label;
  final DateRange range;
}
