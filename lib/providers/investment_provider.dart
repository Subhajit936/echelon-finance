import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/investment.dart';
import 'database_provider.dart';

class PortfolioSummary {
  final double totalValue;
  final double sevenDayReturn;
  final List<Investment> holdings;
  final Map<String, double> allocation;

  const PortfolioSummary({
    required this.totalValue,
    required this.sevenDayReturn,
    required this.holdings,
    required this.allocation,
  });
}

final portfolioProvider = FutureProvider<PortfolioSummary>((ref) async {
  final repo = ref.watch(investmentRepoProvider);
  final holdings = await repo.getAll();
  final allocation = await repo.getAllocation();
  final totalValue = holdings.fold(0.0, (sum, h) => sum + h.totalValue);

  final weightedReturn = totalValue == 0
      ? 0.0
      : holdings.fold(0.0, (sum, h) => sum + h.sevenDayReturn * (h.totalValue / totalValue));

  return PortfolioSummary(
    totalValue: totalValue,
    sevenDayReturn: weightedReturn,
    holdings: holdings,
    allocation: allocation,
  );
});

enum ChartPeriod { week, month, year }

final chartDataProvider = FutureProvider.family<List<FlSpot>, ChartPeriod>((ref, period) async {
  final repo = ref.watch(investmentRepoProvider);
  final snapshots = await repo.getSnapshots();

  final now = DateTime.now();
  final cutoff = switch (period) {
    ChartPeriod.week => now.subtract(const Duration(days: 7)),
    ChartPeriod.month => now.subtract(const Duration(days: 30)),
    ChartPeriod.year => now.subtract(const Duration(days: 365)),
  };

  final filtered = snapshots.where((s) => s.date.isAfter(cutoff)).toList();

  if (filtered.isEmpty) return [];

  // Normalize X axis to 0-based day offsets
  final firstDate = filtered.first.date;
  return filtered
      .asMap()
      .entries
      .map((e) => FlSpot(
            e.value.date.difference(firstDate).inHours.toDouble(),
            e.value.totalPortfolioValue,
          ))
      .toList();
});
