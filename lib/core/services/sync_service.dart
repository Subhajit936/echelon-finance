import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../api/api_client.dart';

/// Monitors connectivity and triggers a lightweight data-sync to the backend.
/// Currently syncs transactions, goals, budgets, and investments in one shot.
class SyncService {
  final ApiClient _api;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  SyncService(this._api);

  void startMonitoring(void Function() onOnline) {
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork) onOnline();
    });
  }

  void stopMonitoring() => _sub?.cancel();

  Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<bool> isBackendReachable() async {
    try {
      if (!await isOnline()) return false;
      if (!await _api.isConfigured()) return false;
      await _api.get('/api/health');
      return true;
    } catch (_) {
      return false;
    }
  }
}
