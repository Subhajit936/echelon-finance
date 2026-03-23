import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/number_formatter.dart';

class IncomeExpenseRow extends StatelessWidget {
  final double monthlyIncome;
  final double dailyExpense;
  final String currency;

  const IncomeExpenseRow({
    super.key,
    required this.monthlyIncome,
    required this.dailyExpense,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Monthly Income',
            value: NumberFormatter.formatCompact(monthlyIncome, currency),
            icon: Icons.arrow_downward_rounded,
            iconColor: AppColors.secondary,
            bgColor: AppColors.secondaryContainer.withOpacity(0.2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Daily Expenses',
            value: NumberFormatter.formatCompact(dailyExpense, currency),
            icon: Icons.arrow_upward_rounded,
            iconColor: AppColors.tertiary,
            bgColor: AppColors.tertiaryContainer.withOpacity(0.3),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 10),
          Text(value, style: AppTextStyles.headlineMd),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.labelMd),
        ],
      ),
    );
  }
}
