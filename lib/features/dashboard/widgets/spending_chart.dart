import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/user_profile_provider.dart';

/// 7-day daily spending bar chart shown on the Dashboard.
class SpendingChart extends ConsumerWidget {
  const SpendingChart({super.key});

  static const _dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dailyBreakdownProvider);
    final currency = ref.watch(currencyProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('7-Day Spending', style: AppTextStyles.labelLg),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Text('Could not load chart', style: AppTextStyles.bodyMd),
              ),
              data: (values) {
                final maxY = values.fold(0.0, (m, v) => v > m ? v : m);
                final safeMax = maxY == 0 ? 100.0 : maxY * 1.25;

                // Labels: today is index 6, go back 6 days
                final now = DateTime.now();
                final labels = List.generate(
                  7,
                  (i) => _dayLabels[(now.weekday - (6 - i) - 1 + 7) % 7],
                );

                return BarChart(
                  BarChartData(
                    maxY: safeMax,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (x, _) => Text(
                            labels[x.toInt()],
                            style: AppTextStyles.labelSm,
                          ),
                        ),
                      ),
                    ),
                    barGroups: List.generate(7, (i) {
                      final isToday = i == 6;
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: values[i],
                            color: isToday
                                ? AppColors.primary
                                : AppColors.primary.withOpacity(0.35),
                            width: 18,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ],
                      );
                    }),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                          NumberFormatter.formatCompact(rod.toY, currency),
                          AppTextStyles.labelSm.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
