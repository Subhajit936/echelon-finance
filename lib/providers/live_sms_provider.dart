import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/live_sms_service.dart';
import '../core/services/sms_service.dart';
import '../data/models/transaction.dart';
import 'database_provider.dart';
import 'transaction_provider.dart';
import 'user_profile_provider.dart';

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

  // ── TODO: YOUR CONTRIBUTION ───────────────────────────────────────────────
  // Decide whether an incoming detected transaction is silently auto-added
  // or shown as a confirmation banner.
  //
  // You have access to:
  //   txn  → AppTransaction  (amount, type, merchant, category, date)
  //   raw  → RawSmsEvent     (body text, sender string)
  //
  // Design choices to consider (5–10 lines):
  //   • Auto-add small routine expenses (e.g. amount < 500)?
  //   • Always confirm income (salary/freelance) since it's high-value & rare?
  //   • Always confirm if merchant == 'Bank Transfer' (ambiguous parser fallback)?
  //   • Auto-add if the sender exactly matches a known major bank header?
  //   • Never auto-add amounts above a certain threshold (e.g. ₹10,000)?
  //
  // Return true  → silently added to the database
  // Return false → shown in a confirmation banner (Add / Dismiss)
  bool _shouldAutoAdd(AppTransaction txn, RawSmsEvent raw) {
    // Always confirm income — salary/credits are rare and high-value
    if (txn.type == TransactionType.income) return false;
    // Always confirm large amounts (> ₹10,000 / $200)
    if (txn.amount > 10000) return false;
    // Confirm ambiguous bank-transfer catch-all
    if (txn.merchant.toLowerCase() == 'bank transfer') return false;
    // Confirm unknown/generic merchants
    if (txn.merchant == 'General') return false;
    // Auto-add small routine expenses from known merchants
    return true;
  }
  // ─────────────────────────────────────────────────────────────────────────

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
