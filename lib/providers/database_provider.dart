import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/database/database_helper.dart';
import '../core/api/api_client.dart';
import '../core/services/ai_service.dart';
import '../core/services/sms_service.dart';
import '../core/services/export_service.dart';
import '../core/services/sync_service.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/repositories/goal_repository.dart';
import '../data/repositories/investment_repository.dart';
import '../data/repositories/budget_repository.dart';
import '../data/repositories/user_profile_repository.dart';
import '../data/repositories/chat_repository.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(storage: ref.watch(secureStorageProvider));
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.watch(apiClientProvider));
});

final transactionRepoProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(
    ref.watch(databaseHelperProvider),
    ref.watch(apiClientProvider),
  );
});

final goalRepoProvider = Provider<GoalRepository>((ref) {
  return GoalRepository(
    ref.watch(databaseHelperProvider),
    ref.watch(apiClientProvider),
  );
});

final investmentRepoProvider = Provider<InvestmentRepository>((ref) {
  return InvestmentRepository(
    ref.watch(databaseHelperProvider),
    ref.watch(apiClientProvider),
  );
});

final budgetRepoProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(
    ref.watch(databaseHelperProvider),
    ref.watch(apiClientProvider),
  );
});

final userProfileRepoProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository(
    ref.watch(databaseHelperProvider),
    ref.watch(apiClientProvider),
  );
});

final chatRepoProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    ref.watch(databaseHelperProvider),
    ref.watch(apiClientProvider),
  );
});

/// Unified AI service — replaces claudeServiceProvider for all AI calls.
final aiServiceProvider = Provider<AIService>((ref) {
  return AIService(ref.watch(secureStorageProvider));
});

/// SMS reading + bank transaction parsing.
final smsServiceProvider = Provider<SmsService>((ref) {
  return SmsService();
});

/// CSV + PDF export service.
final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService();
});
