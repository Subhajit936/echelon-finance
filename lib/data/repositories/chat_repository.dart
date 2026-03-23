import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../models/chat_message.dart';

class ChatRepository {
  final DatabaseHelper _db;
  final ApiClient _api;
  ChatRepository(this._db, this._api);

  // ─── Remote helpers ───────────────────────────────────────────────────────

  Future<bool> _hasRemote() => _api.isConfigured();

  // ─── Write operations (local + remote mirror) ────────────────────────────

  Future<void> insert(ChatMessage message) async {
    final db = await _db.database;
    await db.insert('chat_messages', message.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    unawaited(_mirrorInsert(message));
  }

  Future<void> _mirrorInsert(ChatMessage message) async {
    try {
      if (!await _hasRemote()) return;
      await _api.post(ApiEndpoints.chat, {
        'id': message.id,
        'role': message.role.name,
        'content': message.content,
        'timestamp': message.timestamp.toIso8601String(),
        'isError': message.isError,
        if (message.parsedTransaction != null)
          'parsedTransactionId': message.parsedTransaction!.id,
      });
    } catch (_) {}
  }

  // ─── Read operations (remote-first, local fallback) ───────────────────────

  Future<List<ChatMessage>> getRecent(int limit) async {
    try {
      if (await _hasRemote()) {
        final data = await _api.get(ApiEndpoints.chat,
            query: {'limit': limit.toString()}) as List;
        return data
            .map((e) => _messageFromRemote(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    final db = await _db.database;
    final rows = await db.query(
      'chat_messages',
      orderBy: 'timestamp ASC',
      limit: limit,
    );
    return rows.map(ChatMessage.fromMap).toList();
  }

  Future<void> clear() async {
    final db = await _db.database;
    await db.delete('chat_messages');
    // Best-effort clear on remote as well
    unawaited(_mirrorClear());
  }

  Future<void> _mirrorClear() async {
    try {
      if (!await _hasRemote()) return;
      await _api.delete(ApiEndpoints.chat);
    } catch (_) {}
  }

  // ─── Model converter ──────────────────────────────────────────────────────

  ChatMessage _messageFromRemote(Map<String, dynamic> e) {
    final map = Map<String, dynamic>.from(e);
    map['id'] = map['_id'] ?? map['id'];
    if (map['timestamp'] is String) {
      map['timestamp'] =
          DateTime.parse(map['timestamp'] as String).millisecondsSinceEpoch;
    }
    if (map['isError'] != null) {
      map['is_error'] = (map['isError'] == true) ? 1 : 0;
    }
    map.remove('_id');
    map.remove('__v');
    return ChatMessage.fromMap(map);
  }
}
