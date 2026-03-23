import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/goal.dart';
import 'database_provider.dart';
import 'goal_provider.dart';

class SpendingDna {
  final double essentialPercent;   // housing + utilities + healthcare
  final double lifestylePercent;   // food + entertainment + shopping + transport
  final double investmentPercent;  // investment category

  const SpendingDna({
    required this.essentialPercent,
    required this.lifestylePercent,
    required this.investmentPercent,
  });
}

class InsightsSummary {
  final double healthScore;
  final List<double> savingsVelocity; // 6 months
  final SpendingDna spendingDna;
  final String aiTips;
  final double savingsRate;

  const InsightsSummary({
    required this.healthScore,
    required this.savingsVelocity,
    required this.spendingDna,
    required this.aiTips,
    required this.savingsRate,
  });
}

final insightsProvider = FutureProvider<InsightsSummary>((ref) async {
  final txnRepo = ref.watch(transactionRepoProvider);
  final invRepo = ref.watch(investmentRepoProvider);
  final goals = ref.watch(goalProvider).valueOrNull ?? [];

  // Savings velocity — last 6 months
  final velocity = await txnRepo.getMonthlySavings(6);

  // Monthly summary for savings rate
  final monthly = await txnRepo.getMonthlySummary();
  final savingsRate = monthly.totalIncome == 0
      ? 0.0
      : ((monthly.totalIncome - monthly.totalExpenses) / monthly.totalIncome * 100).clamp(0.0, 100.0);

  // Spending DNA
  final categories = await txnRepo.getCategoryBreakdown();
  final essential = (categories['housing'] ?? 0) +
      (categories['utilities'] ?? 0) +
      (categories['healthcare'] ?? 0);
  final lifestyle = (categories['food'] ?? 0) +
      (categories['entertainment'] ?? 0) +
      (categories['shopping'] ?? 0) +
      (categories['transport'] ?? 0);
  final investmentSpend = categories['investment'] ?? 0;
  final totalSpend = essential + lifestyle + investmentSpend;

  final dna = totalSpend == 0
      ? const SpendingDna(essentialPercent: 0, lifestylePercent: 0, investmentPercent: 0)
      : SpendingDna(
          essentialPercent: essential / totalSpend * 100,
          lifestylePercent: lifestyle / totalSpend * 100,
          investmentPercent: investmentSpend / totalSpend * 100,
        );

  // Portfolio performance — calculated from real snapshot history
  final snapshots = await invRepo.getSnapshots(limit: 31);
  final double portfolioGrowth;
  if (snapshots.length >= 2) {
    final first = snapshots.first.totalPortfolioValue;
    final last = snapshots.last.totalPortfolioValue;
    portfolioGrowth = first > 0
        ? ((last - first) / first * 100).clamp(0.0, 100.0)
        : 0.0;
  } else {
    portfolioGrowth = 0.0;
  }

  // Goal progress average
  final activeGoals = goals.where((g) => g.status == GoalStatus.active).toList();
  final goalProgress = activeGoals.isEmpty
      ? 50.0
      : activeGoals.fold(0.0, (s, g) => s + g.progressPercent * 100) / activeGoals.length;

  // Budget adherence (simplified — always decent when under budget)
  final budgets = await ref.watch(budgetRepoProvider).getCurrentPeriodBudgets();
  final adherence = budgets.isEmpty
      ? 80.0
      : budgets
              .where((b) => b.spentAmount <= b.limitAmount)
              .length /
          budgets.length *
          100;

  // Health score formula
  final healthScore = (savingsRate * 0.4 +
          goalProgress * 0.3 +
          portfolioGrowth * 0.2 +
          adherence * 0.1)
      .clamp(0.0, 100.0);

  // AI tips — use 24-hour disk cache to avoid repeated API calls
  const _tipsCacheKey = 'ai_tips_cache';
  const _tipsCacheTsKey = 'ai_tips_cache_ts';
  final storage = ref.read(secureStorageProvider);
  final cachedTs = await storage.read(key: _tipsCacheTsKey);
  final cacheAge = cachedTs != null
      ? DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(int.parse(cachedTs)))
      : const Duration(days: 999);
  final cachedText = cacheAge.inHours < 24
      ? await storage.read(key: _tipsCacheKey)
      : null;

  String tips = cachedText ??
      ref.read(aiTipsCacheProvider) ??
      '• Review your Food & Dining spending — potential monthly savings.\n'
          '• Check for unused subscriptions to cancel.\n'
          '• Consider increasing your investment contributions by 5%.';

  return InsightsSummary(
    healthScore: healthScore,
    savingsVelocity: velocity,
    spendingDna: dna,
    aiTips: tips,
    savingsRate: savingsRate,
  );
});

final aiTipsCacheProvider = StateProvider<String?>((ref) => null);
