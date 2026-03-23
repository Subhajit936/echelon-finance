import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../data/models/goal.dart';
import '../../../shared/widgets/gradient_button.dart';

class SavingsGoalCard extends StatelessWidget {
  final Goal goal;
  final String currency;
  final VoidCallback onBoost;

  const SavingsGoalCard({
    super.key,
    required this.goal,
    required this.currency,
    required this.onBoost,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(goal.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name, style: AppTextStyles.titleLg),
                    Text(
                      'Save ${NumberFormatter.formatCurrency(goal.dailyTarget, currency)}/day',
                      style: AppTextStyles.labelMd,
                    ),
                  ],
                ),
              ),
              Text(
                '${(goal.progressPercent * 100).toStringAsFixed(0)}%',
                style: AppTextStyles.titleLg.copyWith(color: AppColors.secondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: goal.progressPercent,
              minHeight: 8,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                NumberFormatter.formatCurrency(goal.currentAmount, currency),
                style: AppTextStyles.labelLg.copyWith(color: AppColors.secondary),
              ),
              Text(
                NumberFormatter.formatCurrency(goal.targetAmount, currency),
                style: AppTextStyles.labelLg,
              ),
            ],
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Boost Savings',
            icon: const Icon(Icons.bolt),
            onTap: onBoost,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}
