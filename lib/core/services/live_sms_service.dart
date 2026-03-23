import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

/// Raw SMS event from the native layer.
class RawSmsEvent {
  final String body;
  final String sender;
  final DateTime timestamp;

  RawSmsEvent({
    required this.body,
    required this.sender,
    required this.timestamp,
  });

  factory RawSmsEvent.fromMap(Map<dynamic, dynamic> map) => RawSmsEvent(
        body: map['body'] as String? ?? '',
        sender: map['sender'] as String? ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (map['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );
}

/// Bridges Kotlin ↔ Dart for live SMS delivery.
/// Two channels:
///   • EventChannel  — streams SMS arriving while app is open/backgrounded.
///   • MethodChannel — retrieves SMS that arrived while app was fully closed.
class LiveSmsService {
  static const _eventChannel =
      EventChannel('echelon_finance/sms_events');
  static const _pendingChannel =
      MethodChannel('echelon_finance/pending_sms');

  /// Continuous stream of incoming SMS events (app must be running).
  Stream<RawSmsEvent> get liveStream => _eventChannel
      .receiveBroadcastStream()
      .map((e) => RawSmsEvent.fromMap(e as Map));

  /// Returns all SMS that arrived while the app was closed, then clears them.
  Future<List<RawSmsEvent>> drainPendingOnLaunch() async {
    try {
      final raw =
          await _pendingChannel.invokeMethod<String>('getPendingAndClear') ??
              '[]';
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => RawSmsEvent.fromMap(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
