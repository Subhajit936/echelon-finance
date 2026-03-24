import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/database/database_helper.dart';
import '../core/database/seed_data.dart';
import 'database_provider.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? userEmail;
  final String? userName;
  final String? error;

  const AuthState({
    this.isLoading = true,
    this.isAuthenticated = false,
    this.userEmail,
    this.userName,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? userEmail,
    String? userName,
    String? error,
  }) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        userEmail: userEmail ?? this.userEmail,
        userName: userName ?? this.userName,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final FlutterSecureStorage _storage;
  final DatabaseHelper _db;

  static const _emailKey = 'auth_user_email';
  static const _nameKey = 'auth_user_name';
  static const _passwordKey = 'auth_user_password';
  static const _isLoggedInKey = 'auth_is_logged_in';

  AuthNotifier(this._storage, this._db) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final isLoggedIn = await _storage.read(key: _isLoggedInKey);
    if (isLoggedIn == 'true') {
      final email = await _storage.read(key: _emailKey);
      final name = await _storage.read(key: _nameKey);
      state = AuthState(
        isLoading: false,
        isAuthenticated: true,
        userEmail: email,
        userName: name,
      );
    } else {
      // Clear any stale seed/demo data from old sessions so the app
      // starts fresh once the user logs in or registers.
      await _db.clearUserData();
      state = const AuthState(isLoading: false, isAuthenticated: false);
    }
  }

  Future<String> _getProfileCurrency() async {
    final db = await _db.database;
    final rows = await db.query('user_profile', limit: 1);
    if (rows.isEmpty) return 'INR';
    return (rows.first['preferred_currency'] as String?) ?? 'INR';
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    final storedEmail = await _storage.read(key: _emailKey);
    final storedPassword = await _storage.read(key: _passwordKey);
    final storedName = await _storage.read(key: _nameKey);

    if (storedEmail == null || storedEmail.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: "No account found on this device. Tap \"Create one\" to register.",
      );
      return;
    }

    if (storedEmail != email.trim().toLowerCase() || storedPassword != password) {
      state = state.copyWith(isLoading: false, error: 'Incorrect email or password.');
      return;
    }

    await _storage.write(key: _isLoggedInKey, value: 'true');
    state = AuthState(
      isLoading: false,
      isAuthenticated: true,
      userEmail: storedEmail,
      userName: storedName,
    );
  }

  Future<void> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    final existing = await _storage.read(key: _emailKey);
    if (existing != null && existing.isNotEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'An account already exists on this device. Sign in instead.',
      );
      return;
    }

    await _storage.write(key: _emailKey, value: email.trim().toLowerCase());
    await _storage.write(key: _nameKey, value: name.trim());
    await _storage.write(key: _passwordKey, value: password);
    await _storage.write(key: _isLoggedInKey, value: 'true');

    // Clear any leftover data and seed fresh demo data for the new account.
    await _db.clearUserData();
    final currency = await _getProfileCurrency();
    await SeedData.seed(_db, currency);

    state = AuthState(
      isLoading: false,
      isAuthenticated: true,
      userEmail: email.trim().toLowerCase(),
      userName: name.trim(),
    );
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> logout() async {
    await _storage.write(key: _isLoggedInKey, value: 'false');
    state = const AuthState(isLoading: false, isAuthenticated: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(secureStorageProvider),
    ref.watch(databaseHelperProvider),
  );
});
