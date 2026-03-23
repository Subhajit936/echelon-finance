import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../models/budget.dart';

class BudgetRepository {
  final DatabaseHelper _db;
  final ApiClient _api;
  BudgetRepository(this._db, this._api);

  // ─── Remote helpers ───────────────────────────────────────────────────────

  Future<bool> _hasRemote() => _api.isConfigured();

  // ─── Write operations (local + remote mirror) ────────────────────────────

  Future<void> upsert(Budget budget) async {
    final db = await _db.database;
    await db.insert('budgets', budget.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    unawaited(_mirrorUpsert(budget));
  }

  Future<void> _mirrorUpsert(Budget budget) async {
    try {
      if (!await _hasRemote()) return;
      await _api.post(ApiEndpoints.budgets, _budgetToRemoteMap(budget));
    } catch (_) {}
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
    unawaited(_mirrorDelete(id));
  }

  Future<void> _mirrorDelete(String id) async {
    try {
      if (!await _hasRemote()) return;
      await _api.delete(ApiEndpoints.budgetById(id));
    } catch (_) {}
  }

  // ─── Read operations (remote-first, local fallback) ───────────────────────

  Future<List<Budget>> getCurrentPeriodBudgets() async {
    try {
      if (await _hasRemote()) {
        final data = await _api.get(ApiEndpoints.budgetsCurrent) as List;
        return data.map((e) => _budgetFromRemote(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return _localCurrentPeriodBudgets();
  }

  Future<List<Budget>> _localCurrentPeriodBudgets() async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final budgetRows = await db.query(
      'budgets',
      where: 'period_start <= ? AND period_end >= ?',
      whereArgs: [now, now],
    );

    final result = <Budget>[];
    for (final row in budgetRows) {
      final category = row['category'] as String;
      final start = row['period_start'] as int;
      final end = row['period_end'] as int;

      final spentResult = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as spent FROM transactions WHERE category = ? AND type = "expense" AND date >= ? AND date <= ?',
        [category, start, end],
      );
      final spent = (spentResult.first['spent'] as num).toDouble();
      result.add(Budget.fromMap(row, spentAmount: spent));
    }
    return result;
  }

  // ─── Model converters ─────────────────────────────────────────────────────

  Map<String, dynamic> _budgetToRemoteMap(Budget budget) {
    return {
      'id': budget.id,
      'category': budget.category,
      'limitAmount': budget.limitAmount,
      'periodStart': budget.periodStart.toIso8601String(),
      'periodEnd': budget.periodEnd.toIso8601String(),
      'currency': budget.currency,
    };
  }

  Budget _budgetFromRemote(Map<String, dynamic> e) {
    final map = Map<String, dynamic>.from(e);
    map['id'] = map['_id'] ?? map['id'];
    // Normalise camelCase → snake_case for fromMap
    if (map['limitAmount'] != null) map['limit_amount'] = map['limitAmount'];
    if (map['periodStart'] is String) {
      map['period_start'] =
          DateTime.parse(map['periodStart'] as String).millisecondsSinceEpoch;
    }
    if (map['periodEnd'] is String) {
      map['period_end'] =
          DateTime.parse(map['periodEnd'] as String).millisecondsSinceEpoch;
    }
    final spentAmount =
        map['spentAmount'] != null ? (map['spentAmount'] as num).toDouble() : 0.0;
    map.remove('_id');
    map.remove('__v');
    return Budget.fromMap(map, spentAmount: spentAmount);
  }
}
