import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/budget.dart';
import 'database_provider.dart';

const _uuid = Uuid();

// ── State ─────────────────────────────────────────────────────────────────────

class BudgetState {
  final List<Budget> budgets;
  final bool isLoading;

  const BudgetState({this.budgets = const [], this.isLoading = true});

  BudgetState copyWith({List<Budget>? budgets, bool? isLoading}) => BudgetState(
        budgets: budgets ?? this.budgets,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class BudgetNotifier extends StateNotifier<BudgetState> {
  final Ref _ref;
  BudgetNotifier(this._ref) : super(const BudgetState()) {
    _load();
  }

  Future<void> _load() async {
    final budgets = await _ref.read(budgetRepoProvider).getCurrentPeriodBudgets();
    state = state.copyWith(budgets: budgets, isLoading: false);
  }

  Future<void> refresh() => _load();

  /// Create a new budget for the current calendar month.
  Future<void> addBudget({
    required String category,
    required double limitAmount,
    required String currency,
  }) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final budget = Budget(
      id: _uuid.v4(),
      category: category,
      limitAmount: limitAmount,
      spentAmount: 0,
      periodStart: start,
      periodEnd: end,
      currency: currency,
    );

    await _ref.read(budgetRepoProvider).upsert(budget);
    await _load();
  }

  Future<void> deleteBudget(String id) async {
    await _ref.read(budgetRepoProvider).delete(id);
    state = state.copyWith(budgets: state.budgets.where((b) => b.id != id).toList());
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final budgetProvider = StateNotifierProvider<BudgetNotifier, BudgetState>((ref) {
  return BudgetNotifier(ref);
});

/// List of budgets that are over 80 % utilised — used for alert banners.
final overBudgetProvider = Provider<List<Budget>>((ref) {
  return ref.watch(budgetProvider).budgets.where((b) => b.utilizedPercent >= 0.8).toList();
});
