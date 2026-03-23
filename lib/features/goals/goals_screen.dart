import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/number_formatter.dart';
import '../../data/models/goal.dart';
import '../../providers/goal_provider.dart';
import '../../providers/investment_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../shared/widgets/gradient_button.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  ChartPeriod _period = ChartPeriod.month;

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final portfolioAsync = ref.watch(portfolioProvider);
    final goalsAsync = ref.watch(goalProvider);
    final chartAsync = ref.watch(chartDataProvider(_period));

    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLow,
        title: Text('Goals & Portfolio', style: AppTextStyles.headlineLg),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/goals/create'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(portfolioProvider);
          ref.invalidate(goalProvider);
        },
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Portfolio hero
              portfolioAsync.when(
                loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('Error: $e'),
                data: (portfolio) => _PortfolioHeader(
                  totalValue: portfolio.totalValue,
                  sevenDayReturn: portfolio.sevenDayReturn,
                  currency: currency,
                ),
              ),
              const SizedBox(height: 16),

              // Performance chart
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Performance', style: AppTextStyles.titleLg),
                        SegmentedButton<ChartPeriod>(
                          selected: {_period},
                          onSelectionChanged: (v) => setState(() => _period = v.first),
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: AppColors.primary.withOpacity(0.12),
                            selectedForegroundColor: AppColors.primary,
                            textStyle: AppTextStyles.labelMd,
                          ),
                          segments: const [
                            ButtonSegment(value: ChartPeriod.week, label: Text('1W')),
                            ButtonSegment(value: ChartPeriod.month, label: Text('1M')),
                            ButtonSegment(value: ChartPeriod.year, label: Text('1Y')),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 140,
                      child: chartAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => Center(child: Text('No data', style: AppTextStyles.labelMd)),
                        data: (spots) => spots.isEmpty
                            ? Center(child: Text('No portfolio history yet', style: AppTextStyles.labelMd))
                            : LineChart(LineChartData(
                                lineTouchData: const LineTouchData(enabled: false),
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                titlesData: const FlTitlesData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: spots,
                                    isCurved: true,
                                    color: AppColors.primary,
                                    barWidth: 2.5,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          AppColors.primary.withOpacity(0.15),
                                          AppColors.primary.withOpacity(0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Goals
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Savings Goals', style: AppTextStyles.headlineMd),
                  GradientButton(
                    label: 'New Goal',
                    icon: const Icon(Icons.add),
                    onTap: () => context.push('/goals/create'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              goalsAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (goals) => goals.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No goals yet. Create your first!', style: AppTextStyles.bodyMd),
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: goals.length,
                        itemBuilder: (_, i) => _GoalTile(
                          goal: goals[i],
                          currency: currency,
                          onContribute: () => _contributeDialog(context, ref, goals[i].id),
                          onDelete: () => ref.read(goalProvider.notifier).delete(goals[i].id),
                        ),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _contributeDialog(BuildContext ctx, WidgetRef ref, String goalId) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text('Add to Goal', style: AppTextStyles.headlineMd),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final a = double.tryParse(ctrl.text);
              if (a != null && a > 0) ref.read(goalProvider.notifier).contribute(goalId, a);
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

class _PortfolioHeader extends StatelessWidget {
  final double totalValue;
  final double sevenDayReturn;
  final String currency;

  const _PortfolioHeader({
    required this.totalValue,
    required this.sevenDayReturn,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Portfolio Value',
                    style: AppTextStyles.labelLg.copyWith(color: Colors.white70)),
                const SizedBox(height: 4),
                Text(
                  NumberFormatter.formatCurrency(totalValue, currency),
                  style: AppTextStyles.displaySm.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Icon(
                    sevenDayReturn >= 0 ? Icons.trending_up : Icons.trending_down,
                    color: sevenDayReturn >= 0 ? const Color(0xFF89F8C7) : AppColors.tertiaryContainer,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    NumberFormatter.formatPercent(sevenDayReturn),
                    style: AppTextStyles.titleMd.copyWith(
                      color: sevenDayReturn >= 0 ? const Color(0xFF89F8C7) : AppColors.tertiaryContainer,
                    ),
                  ),
                ],
              ),
              Text('7-day return',
                  style: AppTextStyles.labelSm.copyWith(color: Colors.white60)),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final Goal goal;
  final String currency;
  final VoidCallback onContribute;
  final VoidCallback onDelete;

  const _GoalTile({
    required this.goal,
    required this.currency,
    required this.onContribute,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(goal.emoji, style: const TextStyle(fontSize: 24)),
              IconButton(
                icon: const Icon(Icons.more_vert, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  builder: (_) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text('Contribute'),
                        onTap: () { Navigator.pop(context); onContribute(); },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete_outline, color: AppColors.tertiary),
                        title: Text('Delete', style: TextStyle(color: AppColors.tertiary)),
                        onTap: () { Navigator.pop(context); onDelete(); },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(goal.name, style: AppTextStyles.titleMd, maxLines: 1, overflow: TextOverflow.ellipsis),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: goal.progressPercent,
              minHeight: 6,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(goal.progressPercent * 100).toStringAsFixed(0)}% · ${NumberFormatter.formatCompact(goal.remaining, currency)} left',
            style: AppTextStyles.labelSm,
          ),
        ],
      ),
    );
  }
}
