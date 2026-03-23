import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../data/models/transaction.dart';

class RecentTransactionsList extends StatelessWidget {
  final List<AppTransaction> transactions;
  final String currency;
  final VoidCallback onViewAll;

  const RecentTransactionsList({
    super.key,
    required this.transactions,
    required this.currency,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Activity', style: AppTextStyles.headlineMd),
            TextButton(
              onPressed: onViewAll,
              child: Text(
                'View All',
                style: AppTextStyles.titleMd.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (transactions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No transactions yet', style: AppTextStyles.bodyMd),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 2),
            itemBuilder: (_, i) => _TransactionTile(
              transaction: transactions[i],
              currency: currency,
            ),
          ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final AppTransaction transaction;
  final String currency;

  const _TransactionTile({required this.transaction, required this.currency});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                transaction.category.icon,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction.merchant, style: AppTextStyles.titleMd),
                Text(transaction.category.label, style: AppTextStyles.labelMd),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : '-'}${NumberFormatter.formatCurrency(transaction.amount, currency)}',
                style: isIncome
                    ? AppTextStyles.amountPositive
                    : AppTextStyles.amountNegative,
              ),
              Text(
                _formatDate(transaction.date),
                style: AppTextStyles.labelSm,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${date.day}/${date.month}';
  }
}
