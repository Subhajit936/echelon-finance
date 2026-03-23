import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/user_profile_provider.dart';

/// Horizontal scrollable row of budget-utilisation pills shown on the dashboard.
/// Green ≤ 80 %, amber 80–99 %, red ≥ 100 %.
class BudgetPillsRow extends ConsumerWidget {
  const BudgetPillsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(budgetProvider);
    final currency = ref.watch(currencyProvider);

    if (state.isLoading || state.budgets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Monthly Budgets', style: AppTextStyles.labelLg),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: state.budgets.map((b) {
              final pct = b.utilizedPercent;
              final Color barColor;
              if (pct >= 1.0) {
                barColor = AppColors.tertiary; // over budget — red
              } else if (pct >= 0.8) {
                barColor = Colors.orange; // warning — amber
              } else {
                barColor = AppColors.secondary; // healthy — green
              }

              return Container(
                width: 130,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: barColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.category,
                      style: AppTextStyles.labelMd,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: barColor.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      NumberFormatter.formatCompact(b.remainingAmount, currency),
                      style: AppTextStyles.labelSm.copyWith(color: barColor),
                    ),
                    Text('left', style: AppTextStyles.labelSm),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
