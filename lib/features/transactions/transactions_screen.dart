import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/utils/animation_helper.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../data/models/transaction.dart';
import '../../providers/database_provider.dart';
import 'widgets/transaction_tile.dart';
import 'widgets/savings_rate_gauge.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedPeriod = 'All Time';
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 100) {
        ref.read(transactionProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _applyFilter(String period) {
    setState(() => _selectedPeriod = period);
    final notifier = ref.read(transactionProvider.notifier);
    final current = ref.read(transactionProvider).filter;
    final now = DateTime.now();
    switch (period) {
      case 'This Month':
        // Merge with existing search query — don't clear it
        notifier.setFilter(current.copyWith(
          from: DateTime(now.year, now.month, 1),
          to: now,
        ));
      default:
        // Clear only date range — preserve search query
        notifier.setFilter(current.copyWith(clearDates: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionProvider);
    final savingsRateAsync = ref.watch(savingsRateProvider);
    final currency = ref.watch(currencyProvider);

    // Calculate period totals
    final income = state.transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final expense = state.transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);
    final net = income - expense;

    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLow,
        title: Text('Transaction Log', style: AppTextStyles.headlineLg),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export',
            onSelected: (value) async {
              final transactions = ref.read(transactionProvider).transactions;
              final currency = ref.read(currencyProvider);
              final exporter = ref.read(exportServiceProvider);
              final messenger = ScaffoldMessenger.of(context);
              try {
                if (value == 'csv') {
                  await exporter.exportCsv(transactions, currency);
                } else {
                  await exporter.exportPdf(transactions, currency);
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Export failed: $e')),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'csv', child: ListTile(leading: Icon(Icons.table_chart_outlined), title: Text('Export CSV'))),
              PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf_outlined), title: Text('Export PDF'))),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/transactions/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary header
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Net Balance', style: AppTextStyles.labelLg),
                      Text(
                        NumberFormatter.formatCurrency(net, currency),
                        style: AppTextStyles.headlineLg.copyWith(
                          color: net >= 0 ? AppColors.secondary : AppColors.tertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '+${NumberFormatter.formatCompact(income, currency)}',
                            style: AppTextStyles.labelLg.copyWith(color: AppColors.secondary),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '-${NumberFormatter.formatCompact(expense, currency)}',
                            style: AppTextStyles.labelLg.copyWith(color: AppColors.tertiary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                savingsRateAsync.maybeWhen(
                  data: (rate) => SavingsRateGauge(savingsRate: rate),
                  orElse: () => const SizedBox(),
                ),
              ],
            ),
          ),
          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['All Time', 'This Month'].map((period) {
                final selected = _selectedPeriod == period;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(period),
                    selected: selected,
                    onSelected: (_) => _applyFilter(period),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (q) {
                final current = ref.read(transactionProvider).filter;
                ref.read(transactionProvider.notifier)
                    .setFilter(current.copyWith(searchQuery: q));
              },
              decoration: const InputDecoration(
                hintText: 'Search transactions...',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // List
          Expanded(
            child: state.transactions.isEmpty && !state.isLoading
                ? Center(
                    child: Text('No transactions found', style: AppTextStyles.bodyMd),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: state.transactions.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= state.transactions.length) {
                        return state.isLoading
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: List.generate(
                                    3,
                                    (j) => Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        children: [
                                          AnimationHelper.shimmerBox(width: 40, height: 40, radius: 20),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                AnimationHelper.shimmerBox(height: 14),
                                                const SizedBox(height: 6),
                                                AnimationHelper.shimmerBox(width: 100, height: 11),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox();
                      }
                      return AnimationHelper.staggeredItem(
                        index: i,
                        child: TransactionTile(
                          transaction: state.transactions[i],
                          currency: currency,
                          onDelete: () => ref
                              .read(transactionProvider.notifier)
                              .delete(state.transactions[i].id),
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
