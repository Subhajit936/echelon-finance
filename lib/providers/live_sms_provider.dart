import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/services/live_sms_service.dart';
import '../core/services/sms_service.dart';
import '../data/models/transaction.dart';
import 'database_provider.dart';
import 'transaction_provider.dart';
import 'user_profile_provider.dart';

// ── SMS auto-add threshold ────────────────────────────────────────────────────

class SmsThresholdNotifier extends StateNotifier<double> {
  final FlutterSecureStorage _storage;
  static const _key = 'sms_auto_add_threshold';
  static const _default = 10000.0;

  SmsThresholdNotifier(this._storage) : super(_default) {
    _load();
  }

  Future<void> _load() async {
    final v = await _storage.read(key: _key);
    if (v != null) state = double.tryParse(v) ?? _default;
  }

  Future<void> setThreshold(double value) async {
    await _storage.write(key: _key, value: value.toString());
    state = value;
  }
}

final smsThresholdProvider =
    StateNotifierProvider<SmsThresholdNotifier, double>((ref) {
  return SmsThresholdNotifier(ref.watch(secureStorageProvider));
});

// ── Data classes ──────────────────────────────────────────────────────────────

/// A transaction detected from a live incoming SMS.
class LiveSmsDetection {
  final String id;
  final AppTransaction transaction;
  final String smsSender;
  final String smsBody;
  final bool autoAdded;

  LiveSmsDetection({
    required this.id,
    required this.transaction,
    required this.smsSender,
    required this.smsBody,
    required this.autoAdded,
  });
}

class LiveSmsState {
  /// Transactions waiting for user confirmation (not yet added to DB).
  final List<LiveSmsDetection> pendingConfirmations;

  /// Transactions silently auto-added this session (for undo support).
  final List<LiveSmsDetection> recentAutoAdded;

  const LiveSmsState({
    this.pendingConfirmations = const [],
    this.recentAutoAdded = const [],
  });

  LiveSmsState copyWith({
    List<LiveSmsDetection>? pendingConfirmations,
    List<LiveSmsDetection>? recentAutoAdded,
  }) => LiveSmsState(
        pendingConfirmations: pendingConfirmations ?? this.pendingConfirmations,
        recentAutoAdded: recentAutoAdded ?? this.recentAutoAdded,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class LiveSmsNotifier extends StateNotifier<LiveSmsState> {
  final Ref _ref;
  final LiveSmsService _liveService;
  final SmsService _smsService;
  StreamSubscription<RawSmsEvent>? _sub;

  LiveSmsNotifier(this._ref, this._liveService, this._smsService)
      : super(const LiveSmsState()) {
    _start();
  }

  Future<void> _start() async {
    // Drain any SMS that arrived while the app was fully closed
    final pending = await _liveService.drainPendingOnLaunch();
    for (final raw in pending) {
      await _process(raw);
    }

    // Subscribe to the live event channel for real-time SMS
    _sub = _liveService.liveStream.listen(_process);
  }

  Future<void> _process(RawSmsEvent raw) async {
    if (!_smsService.isBankSms(raw.body, raw.sender)) return;
    if (_smsService.isSpamOrOtp(raw.body)) return;

    final currency = _ref.read(currencyProvider);
    final txn = _smsService.parseTransactionPublic(raw.body, raw.timestamp, currency);
    if (txn == null) return;

    final detection = LiveSmsDetection(
      id: txn.id,
      transaction: txn.copyWith(note: 'Auto-detected via SMS'),
      smsSender: raw.sender,
      smsBody: raw.body,
      autoAdded: _shouldAutoAdd(txn, raw),
    );

    if (detection.autoAdded) {
      await _ref.read(transactionProvider.notifier).add(detection.transaction);
      state = state.copyWith(
        recentAutoAdded: [detection, ...state.recentAutoAdded].take(5).toList(),
      );
    } else {
      state = state.copyWith(
        pendingConfirmations: [...state.pendingConfirmations, detection],
      );
    }
  }

  bool _shouldAutoAdd(AppTransaction txn, RawSmsEvent raw) {
    // Always confirm income — salary/credits are rare and high-value
    if (txn.type == TransactionType.income) return false;
    // Always confirm amounts above the user-configurable threshold
    final threshold = _ref.read(smsThresholdProvider);
    if (txn.amount > threshold) return false;
    // Confirm ambiguous bank-transfer catch-all
    if (txn.merchant.toLowerCase() == 'bank transfer') return false;
    // Confirm unknown/generic merchants
    if (txn.merchant == 'General') return false;
    // Auto-add small routine expenses from known merchants
    return true;
  }

  /// User tapped "Add" on the confirmation banner.
  Future<void> confirm(String detectionId) async {
    final item = state.pendingConfirmations
        .where((d) => d.id == detectionId)
        .firstOrNull;
    if (item == null) return;

    await _ref.read(transactionProvider.notifier).add(item.transaction);
    state = state.copyWith(
      pendingConfirmations:
          state.pendingConfirmations.where((d) => d.id != detectionId).toList(),
      recentAutoAdded: [item, ...state.recentAutoAdded].take(5).toList(),
    );
  }

  /// User tapped "Dismiss" — discard without saving.
  void dismiss(String detectionId) {
    state = state.copyWith(
      pendingConfirmations:
          state.pendingConfirmations.where((d) => d.id != detectionId).toList(),
    );
  }

  /// Undo the most recent auto-added transaction.
  Future<void> undoLastAutoAdd() async {
    if (state.recentAutoAdded.isEmpty) return;
    final last = state.recentAutoAdded.first;
    await _ref.read(transactionProvider.notifier).delete(last.id);
    state = state.copyWith(
      recentAutoAdded: state.recentAutoAdded.skip(1).toList(),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final liveSmsServiceProvider = Provider<LiveSmsService>((ref) {
  return LiveSmsService();
});

final liveSmsProvider =
    StateNotifierProvider<LiveSmsNotifier, LiveSmsState>((ref) {
  return LiveSmsNotifier(
    ref,
    ref.watch(liveSmsServiceProvider),
    ref.watch(smsServiceProvider),
  );
});
