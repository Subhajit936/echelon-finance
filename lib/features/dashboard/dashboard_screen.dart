import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/animation_helper.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/insights_provider.dart';
import '../../providers/user_profile_provider.dart';
import 'widgets/net_worth_card.dart';
import 'widgets/income_expense_row.dart';
import 'widgets/savings_goal_card.dart';
import 'widgets/recent_transactions_list.dart';
import 'widgets/budget_pills_row.dart';
import 'widgets/spending_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final activeGoal = ref.watch(activeGoalProvider);
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardSummaryProvider);
            ref.invalidate(dailyBreakdownProvider);
            ref.invalidate(goalProvider);
            ref.invalidate(budgetProvider);
            ref.invalidate(insightsProvider);
          },
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: false,
                floating: true,
                backgroundColor: AppColors.surfaceContainerLow,
                title: Text('The Ledger', style: AppTextStyles.headlineLg),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => context.push('/settings'),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              summaryAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: Center(child: Text('Error: $e', style: AppTextStyles.bodyMd)),
                ),
                data: (summary) => SliverList(
                  delegate: SliverChildListDelegate([
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        children: [
                          AnimationHelper.staggeredItem(
                            index: 0,
                            child: NetWorthCard(netWorth: summary.netWorth),
                          ),
                          const SizedBox(height: 16),
                          AnimationHelper.staggeredItem(
                            index: 1,
                            child: IncomeExpenseRow(
                              monthlyIncome: summary.monthlyIncome,
                              dailyExpense: summary.dailyExpenseAvg,
                              currency: currency,
                            ),
                          ),
                          if (activeGoal != null) ...[
                            const SizedBox(height: 16),
                            AnimationHelper.staggeredItem(
                              index: 2,
                              child: SavingsGoalCard(
                                goal: activeGoal,
                                currency: currency,
                                onBoost: () => _showBoostDialog(context, ref, activeGoal.id),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          AnimationHelper.staggeredItem(
                            index: 3,
                            child: const BudgetPillsRow(),
                          ),
                          const SizedBox(height: 16),
                          AnimationHelper.staggeredItem(
                            index: 4,
                            child: const SpendingChart(),
                          ),
                          const SizedBox(height: 16),
                          AnimationHelper.staggeredItem(
                            index: 5,
                            child: RecentTransactionsList(
                              transactions: summary.recentTransactions,
                              currency: currency,
                              onViewAll: () => context.go('/transactions'),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/transactions/add'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showBoostDialog(BuildContext context, WidgetRef ref, String goalId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add to Goal', style: AppTextStyles.headlineMd),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                ref.read(goalProvider.notifier).contribute(goalId, amount);
              }
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
