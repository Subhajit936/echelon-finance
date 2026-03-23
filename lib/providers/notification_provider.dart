import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/services/notification_service.dart';
import 'database_provider.dart';

const _morningKey = 'notif_morning';
const _eveningKey = 'notif_evening';

class NotificationState {
  final bool morningEnabled;
  final bool eveningEnabled;

  const NotificationState({
    this.morningEnabled = false,
    this.eveningEnabled = false,
  });

  NotificationState copyWith({bool? morningEnabled, bool? eveningEnabled}) =>
      NotificationState(
        morningEnabled: morningEnabled ?? this.morningEnabled,
        eveningEnabled: eveningEnabled ?? this.eveningEnabled,
      );
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationService _svc;
  final FlutterSecureStorage _storage;

  NotificationNotifier(Ref _, this._svc, this._storage)
      : super(const NotificationState()) {
    _load();
  }

  Future<void> _load() async {
    final morning = (await _storage.read(key: _morningKey)) == 'true';
    final evening = (await _storage.read(key: _eveningKey)) == 'true';
    state = NotificationState(morningEnabled: morning, eveningEnabled: evening);
  }

  Future<void> toggleMorning(bool enabled) async {
    await _storage.write(key: _morningKey, value: enabled.toString());
    if (enabled) {
      await _svc.scheduleMorningSummary();
    } else {
      await _svc.cancelMorning();
    }
    state = state.copyWith(morningEnabled: enabled);
  }

  Future<void> toggleEvening(bool enabled) async {
    await _storage.write(key: _eveningKey, value: enabled.toString());
    if (enabled) {
      await _svc.scheduleEveningNudge();
    } else {
      await _svc.cancelEvening();
    }
    state = state.copyWith(eveningEnabled: enabled);
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(
    ref,
    ref.watch(notificationServiceProvider),
    ref.watch(secureStorageProvider),
  );
});
