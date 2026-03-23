import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/goal.dart';
import 'database_provider.dart';

class GoalNotifier extends AsyncNotifier<List<Goal>> {
  @override
  Future<List<Goal>> build() async {
    return ref.watch(goalRepoProvider).getAll();
  }

  Future<void> create(Goal goal) async {
    await ref.read(goalRepoProvider).insert(goal);
    ref.invalidateSelf();
  }

  Future<void> updateGoal(Goal goal) async {
    await ref.read(goalRepoProvider).update(goal);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(goalRepoProvider).delete(id);
    ref.invalidateSelf();
  }

  Future<void> contribute(String id, double amount) async {
    await ref.read(goalRepoProvider).contribute(id, amount);
    ref.invalidateSelf();
  }
}

final goalProvider = AsyncNotifierProvider<GoalNotifier, List<Goal>>(
  GoalNotifier.new,
);

final activeGoalProvider = Provider<Goal?>((ref) {
  final goals = ref.watch(goalProvider).valueOrNull ?? [];
  final active = goals.where((g) => g.status == GoalStatus.active).toList();
  return active.isEmpty ? null : active.first;
});
