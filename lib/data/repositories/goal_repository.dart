import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../models/goal.dart';

class GoalRepository {
  final DatabaseHelper _db;
  final ApiClient _api;
  GoalRepository(this._db, this._api);

  // ─── Remote helpers ───────────────────────────────────────────────────────

  Future<bool> _hasRemote() => _api.isConfigured();

  // ─── Write operations (local + remote mirror) ────────────────────────────

  Future<void> insert(Goal goal) async {
    final db = await _db.database;
    await db.insert('goals', goal.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    unawaited(_mirrorInsert(goal));
  }

  Future<void> _mirrorInsert(Goal goal) async {
    try {
      if (!await _hasRemote()) return;
      await _api.post(ApiEndpoints.goals, _goalToRemoteMap(goal));
    } catch (_) {}
  }

  Future<void> update(Goal goal) async {
    final db = await _db.database;
    await db.update('goals', goal.toMap(),
        where: 'id = ?', whereArgs: [goal.id]);
    unawaited(_mirrorUpdate(goal));
  }

  Future<void> _mirrorUpdate(Goal goal) async {
    try {
      if (!await _hasRemote()) return;
      await _api.put(ApiEndpoints.goalById(goal.id), _goalToRemoteMap(goal));
    } catch (_) {}
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
    unawaited(_mirrorDelete(id));
  }

  Future<void> _mirrorDelete(String id) async {
    try {
      if (!await _hasRemote()) return;
      await _api.delete(ApiEndpoints.goalById(id));
    } catch (_) {}
  }

  // ─── Read operations (remote-first, local fallback) ───────────────────────

  Future<List<Goal>> getAll() async {
    try {
      if (await _hasRemote()) {
        final data = await _api.get(ApiEndpoints.goals) as List;
        return data.map((e) => _goalFromRemote(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    final db = await _db.database;
    final rows = await db.query('goals', orderBy: 'created_at DESC');
    return rows.map(Goal.fromMap).toList();
  }

  Future<List<Goal>> getActive() async {
    try {
      if (await _hasRemote()) {
        final data = await _api.get(ApiEndpoints.goalsActive) as List;
        return data.map((e) => _goalFromRemote(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    final db = await _db.database;
    final rows = await db.query(
      'goals',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'created_at DESC',
    );
    return rows.map(Goal.fromMap).toList();
  }

  Future<void> contribute(String id, double amount) async {
    // Always update locally first
    final db = await _db.database;
    final rows = await db.query('goals', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final goal = Goal.fromMap(rows.first);
    final newAmount =
        (goal.currentAmount + amount).clamp(0, goal.targetAmount);
    await db.update(
      'goals',
      {
        'current_amount': newAmount,
        'status': newAmount >= goal.targetAmount ? 'completed' : 'active',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    // Mirror contribution to remote
    unawaited(_mirrorContribute(id, amount));
  }

  Future<void> _mirrorContribute(String id, double amount) async {
    try {
      if (!await _hasRemote()) return;
      await _api.post(ApiEndpoints.goalContribute(id), {'amount': amount});
    } catch (_) {}
  }

  // ─── Model converters ─────────────────────────────────────────────────────

  Map<String, dynamic> _goalToRemoteMap(Goal goal) {
    return {
      'id': goal.id,
      'name': goal.name,
      'emoji': goal.emoji,
      'targetAmount': goal.targetAmount,
      'currentAmount': goal.currentAmount,
      'targetDate': goal.targetDate?.toIso8601String(),
      'dailyTarget': goal.dailyTarget,
      'status': goal.status.name,
      'currency': goal.currency,
      'createdAt': goal.createdAt.toIso8601String(),
    };
  }

  Goal _goalFromRemote(Map<String, dynamic> e) {
    final map = Map<String, dynamic>.from(e);
    map['id'] = map['_id'] ?? map['id'];
    // Normalise camelCase remote fields → snake_case for fromMap
    if (map['targetAmount'] != null) map['target_amount'] = map['targetAmount'];
    if (map['currentAmount'] != null) {
      map['current_amount'] = map['currentAmount'];
    }
    if (map['dailyTarget'] != null) map['daily_target'] = map['dailyTarget'];
    if (map['targetDate'] is String) {
      map['target_date'] =
          DateTime.parse(map['targetDate'] as String).millisecondsSinceEpoch;
    }
    if (map['createdAt'] is String) {
      map['created_at'] =
          DateTime.parse(map['createdAt'] as String).millisecondsSinceEpoch;
    }
    map.remove('_id');
    map.remove('__v');
    return Goal.fromMap(map);
  }
}
