import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user_profile.dart';
import 'database_provider.dart';

class UserProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    return ref.watch(userProfileRepoProvider).getProfile();
  }

  Future<void> save(UserProfile profile) async {
    await ref.read(userProfileRepoProvider).upsert(profile);
    state = AsyncValue.data(profile);
  }

  Future<void> updateCurrency(String currency) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await save(current.copyWith(preferredCurrency: currency));
  }

  Future<void> updateName(String name) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await save(current.copyWith(displayName: name));
  }
}

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile?>(
  UserProfileNotifier.new,
);

final currencyProvider = Provider<String>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return profile?.preferredCurrency ?? 'INR';
});
