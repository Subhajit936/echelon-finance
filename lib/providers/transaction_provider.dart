import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/transaction.dart';
import '../data/repositories/transaction_repository.dart';
import '../core/constants/app_constants.dart';
import 'database_provider.dart';

class TransactionFilter {
  final String? searchQuery;
  final String? category;
  final DateTime? from;
  final DateTime? to;

  const TransactionFilter({this.searchQuery, this.category, this.from, this.to});

  TransactionFilter copyWith({
    String? searchQuery,
    String? category,
    DateTime? from,
    DateTime? to,
    bool clearCategory = false,
    bool clearDates = false,
  }) => TransactionFilter(
    searchQuery: searchQuery ?? this.searchQuery,
    category: clearCategory ? null : (category ?? this.category),
    from: clearDates ? null : (from ?? this.from),
    to: clearDates ? null : (to ?? this.to),
  );
}

class TransactionState {
  final List<AppTransaction> transactions;
  final bool isLoading;
  final bool hasMore;
  final TransactionFilter filter;
  final String? error;

  const TransactionState({
    this.transactions = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.filter = const TransactionFilter(),
    this.error,
  });

  TransactionState copyWith({
    List<AppTransaction>? transactions,
    bool? isLoading,
    bool? hasMore,
    TransactionFilter? filter,
    String? error,
  }) => TransactionState(
    transactions: transactions ?? this.transactions,
    isLoading: isLoading ?? this.isLoading,
    hasMore: hasMore ?? this.hasMore,
    filter: filter ?? this.filter,
    error: error,
  );
}

class TransactionNotifier extends StateNotifier<TransactionState> {
  final TransactionRepository _repo;
  TransactionNotifier(this._repo) : super(const TransactionState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, transactions: []);
    try {
      final txns = await _repo.getPage(
        limit: AppConstants.transactionPageSize,
        searchQuery: state.filter.searchQuery,
        category: state.filter.category,
        from: state.filter.from,
        to: state.filter.to,
      );
      state = state.copyWith(
        transactions: txns,
        isLoading: false,
        hasMore: txns.length >= AppConstants.transactionPageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    final next = await _repo.getPage(
      offset: state.transactions.length,
      limit: AppConstants.transactionPageSize,
      searchQuery: state.filter.searchQuery,
      category: state.filter.category,
      from: state.filter.from,
      to: state.filter.to,
    );
    state = state.copyWith(
      transactions: [...state.transactions, ...next],
      hasMore: next.length >= AppConstants.transactionPageSize,
    );
  }

  void setFilter(TransactionFilter filter) {
    state = state.copyWith(filter: filter);
    load();
  }

  Future<void> add(AppTransaction txn) async {
    await _repo.insert(txn);
    load();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    state = state.copyWith(
      transactions: state.transactions.where((t) => t.id != id).toList(),
    );
  }
}

final transactionProvider =
    StateNotifierProvider<TransactionNotifier, TransactionState>((ref) {
  return TransactionNotifier(ref.watch(transactionRepoProvider));
});

class DashboardSummary {
  final double netWorth;
  final double monthlyIncome;
  final double dailyExpenseAvg;
  final double monthlyExpenses;
  final List<AppTransaction> recentTransactions;

  const DashboardSummary({
    required this.netWorth,
    required this.monthlyIncome,
    required this.dailyExpenseAvg,
    required this.monthlyExpenses,
    required this.recentTransactions,
  });
}

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final txnRepo = ref.watch(transactionRepoProvider);
  final invRepo = ref.watch(investmentRepoProvider);

  final portfolioValue = await invRepo.getTotalValue();
  final summary = await txnRepo.getMonthlySummary();
  final recent = await txnRepo.getRecent(4);
  final netWorth = await txnRepo.getNetWorth(portfolioValue);

  return DashboardSummary(
    netWorth: netWorth,
    monthlyIncome: summary.totalIncome,
    dailyExpenseAvg: summary.dailyExpenseAvg,
    monthlyExpenses: summary.totalExpenses,
    recentTransactions: recent,
  );
});

/// Last 7 days of daily expense totals — drives the SpendingChart on Dashboard.
final dailyBreakdownProvider = FutureProvider<List<double>>((ref) async {
  return ref.watch(transactionRepoProvider).getDailyBreakdown(days: 7);
});

final savingsRateProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(transactionRepoProvider);
  final summary = await repo.getMonthlySummary();
  if (summary.totalIncome == 0) return 0;
  return ((summary.totalIncome - summary.totalExpenses) / summary.totalIncome * 100).clamp(0, 100);
});
