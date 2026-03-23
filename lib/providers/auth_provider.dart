import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/database/database_helper.dart';
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
  final ApiClient _api;
  final FlutterSecureStorage _storage;
  final DatabaseHelper _db;

  static const _emailKey = 'auth_user_email';
  static const _nameKey = 'auth_user_name';

  AuthNotifier(this._api, this._storage, this._db) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final jwt = await _api.getJwt();
    if (jwt == null || jwt.isEmpty) {
      state = const AuthState(isLoading: false, isAuthenticated: false);
      return;
    }

    // Validate the stored JWT against the server
    try {
      final res = await _api.get(ApiEndpoints.authMe);
      final user = res['user'] as Map<String, dynamic>;
      await _storage.write(key: _emailKey, value: user['email'] as String);
      await _storage.write(key: _nameKey, value: user['name'] as String);
      state = AuthState(
        isLoading: false,
        isAuthenticated: true,
        userEmail: user['email'] as String,
        userName: user['name'] as String,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        // Token is expired or invalid — force re-login
        await _api.clearJwt();
        await _storage.delete(key: _emailKey);
        await _storage.delete(key: _nameKey);
        state = const AuthState(isLoading: false, isAuthenticated: false);
      } else {
        // Network error or server down — trust the stored token
        final email = await _storage.read(key: _emailKey);
        final name = await _storage.read(key: _nameKey);
        state = AuthState(
          isLoading: false,
          isAuthenticated: true,
          userEmail: email,
          userName: name,
        );
      }
    } catch (_) {
      // Network unreachable — trust the stored token
      final email = await _storage.read(key: _emailKey);
      final name = await _storage.read(key: _nameKey);
      state = AuthState(
        isLoading: false,
        isAuthenticated: true,
        userEmail: email,
        userName: name,
      );
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.postNoAuth(
        ApiEndpoints.authLogin,
        {'email': email.trim().toLowerCase(), 'password': password},
      );
      await _saveSession(res);
      await _db.clearUserData();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is ApiException ? e.message : 'Login failed. Check your connection.',
      );
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.postNoAuth(
        ApiEndpoints.authRegister,
        {'name': name.trim(), 'email': email.trim().toLowerCase(), 'password': password},
      );
      await _saveSession(res);
      await _db.clearUserData();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is ApiException ? e.message : 'Registration failed. Check your connection.',
      );
    }
  }

  Future<void> _saveSession(Map<String, dynamic> res) async {
    final token = res['token'] as String;
    final user = res['user'] as Map<String, dynamic>;
    await _api.saveJwt(token);
    await _storage.write(key: _emailKey, value: user['email'] as String);
    await _storage.write(key: _nameKey, value: user['name'] as String);
    state = AuthState(
      isLoading: false,
      isAuthenticated: true,
      userEmail: user['email'] as String,
      userName: user['name'] as String,
    );
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> logout() async {
    await _api.clearJwt();
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _nameKey);
    state = const AuthState(isLoading: false, isAuthenticated: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
    ref.watch(databaseHelperProvider),
  );
});
