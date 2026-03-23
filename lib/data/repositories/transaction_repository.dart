import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../core/constants/app_constants.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../models/transaction.dart';

class MonthlySummary {
  final double totalIncome;
  final double totalExpenses;
  final double dailyExpenseAvg;
  const MonthlySummary({
    required this.totalIncome,
    required this.totalExpenses,
    required this.dailyExpenseAvg,
  });
}

class TransactionRepository {
  final DatabaseHelper _db;
  final ApiClient _api;
  TransactionRepository(this._db, this._api);

  // ─── Remote helpers ───────────────────────────────────────────────────────

  Future<bool> _hasRemote() => _api.isConfigured();

  // ─── Write operations (local + remote mirror) ────────────────────────────

  Future<void> insert(AppTransaction txn) async {
    // Always write locally first
    final db = await _db.database;
    await db.insert('transactions', txn.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    // Mirror to remote (fire and forget)
    unawaited(_mirrorInsert(txn));
  }

  Future<void> _mirrorInsert(AppTransaction txn) async {
    try {
      if (!await _hasRemote()) return;
      final map = Map<String, dynamic>.from(txn.toMap());
      // Convert ms epoch to ISO for backend
      map['date'] = txn.date.toIso8601String();
      map['createdAt'] = txn.createdAt.toIso8601String();
      await _api.post(ApiEndpoints.transactions, map);
    } catch (_) {} // ignore remote failures — local is source of truth
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    // Mirror delete to remote
    unawaited(_mirrorDelete(id));
  }

  Future<void> _mirrorDelete(String id) async {
    try {
      if (!await _hasRemote()) return;
      await _api.delete(ApiEndpoints.transactionById(id));
    } catch (_) {}
  }

  // ─── Duplicate detection ──────────────────────────────────────────────────

  /// Returns true if a transaction with the same merchant, amount and date
  /// (±1 minute) already exists — used to prevent SMS import duplicates.
  Future<bool> existsByKey(
      String merchant, double amount, DateTime date) async {
    try {
      if (await _hasRemote()) {
        final res = await _api.get(ApiEndpoints.transactionsExists, query: {
          'merchant': merchant,
          'amount': amount.toString(),
          'date': date.millisecondsSinceEpoch.toString(),
        });
        return res['exists'] == true;
      }
    } catch (_) {}
    // Fall back to local
    final db = await _db.database;
    final margin = const Duration(minutes: 1).inMilliseconds;
    final rows = await db.rawQuery(
      '''SELECT 1 FROM transactions
         WHERE LOWER(merchant) = LOWER(?)
           AND ABS(amount - ?) < 0.01
           AND ABS(date - ?) <= ?
         LIMIT 1''',
      [merchant, amount, date.millisecondsSinceEpoch, margin],
    );
    return rows.isNotEmpty;
  }

  // ─── Read operations (remote-first, local fallback) ───────────────────────

  Future<List<AppTransaction>> getPage({
    int offset = 0,
    int limit = AppConstants.transactionPageSize,
    String? searchQuery,
    String? category,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      if (await _hasRemote()) {
        final query = <String, String>{
          'offset': offset.toString(),
          'limit': limit.toString(),
          if (searchQuery != null && searchQuery.isNotEmpty)
            'search': searchQuery,
          if (category != null) 'category': category,
          if (from != null) 'from': from.millisecondsSinceEpoch.toString(),
          if (to != null) 'to': to.millisecondsSinceEpoch.toString(),
        };
        final data =
            await _api.get(ApiEndpoints.transactions, query: query) as List;
        return data.map((e) => _txnFromRemote(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return _localGetPage(
        offset: offset,
        limit: limit,
        searchQuery: searchQuery,
        category: category,
        from: from,
        to: to);
  }

  Future<List<AppTransaction>> getRecent(int n) async {
    try {
      if (await _hasRemote()) {
        final data = await _api.get(ApiEndpoints.transactionsRecent,
            query: {'n': n.toString()}) as List;
        return data.map((e) => _txnFromRemote(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    final db = await _db.database;
    final rows =
        await db.query('transactions', orderBy: 'date DESC', limit: n);
    return rows.map(AppTransaction.fromMap).toList();
  }

  Future<MonthlySummary> getMonthlySummary() async {
    try {
      if (await _hasRemote()) {
        final data = await _api.get(ApiEndpoints.transactionsMonthlySummary)
            as Map<String, dynamic>;
        return MonthlySummary(
          totalIncome: (data['totalIncome'] as num).toDouble(),
          totalExpenses: (data['totalExpenses'] as num).toDouble(),
          dailyExpenseAvg: (data['dailyExpenseAvg'] as num).toDouble(),
        );
      }
    } catch (_) {}
    return _localMonthlySummary();
  }

  Future<double> getNetWorth(double portfolioValue) async {
    try {
      if (await _hasRemote()) {
        final data = await _api.get(ApiEndpoints.transactionsNetWorth,
            query: {
              'portfolioValue': portfolioValue.toString()
            }) as Map<String, dynamic>;
        return (data['netWorth'] as num).toDouble();
      }
    } catch (_) {}
    return _localNetWorth(portfolioValue);
  }

  Future<Map<String, double>> getCategoryBreakdown(
      {DateTime? from, DateTime? to}) async {
    try {
      if (await _hasRemote()) {
        final query = <String, String>{
          if (from != null) 'from': from.millisecondsSinceEpoch.toString(),
          if (to != null) 'to': to.millisecondsSinceEpoch.toString(),
        };
        final data = await _api.get(ApiEndpoints.transactionsCategoryBreakdown,
            query: query) as Map<String, dynamic>;
        return data.map((k, v) => MapEntry(k, (v as num).toDouble()));
      }
    } catch (_) {}
    return _localCategoryBreakdown(from: from, to: to);
  }

  Future<List<double>> getDailyBreakdown({int days = 7}) async {
    try {
      if (await _hasRemote()) {
        final data = await _api.get(ApiEndpoints.transactionsDailyBreakdown,
            query: {'days': days.toString()}) as List;
        return data.map((e) => (e as num).toDouble()).toList();
      }
    } catch (_) {}
    return _localDailyBreakdown(days: days);
  }

  Future<List<double>> getMonthlySavings(int months) async {
    try {
      if (await _hasRemote()) {
        final data = await _api.get(ApiEndpoints.transactionsMonthlySavings,
            query: {'months': months.toString()}) as List;
        return data.map((e) => (e as num).toDouble()).toList();
      }
    } catch (_) {}
    return _localMonthlySavings(months);
  }

  // ─── Local SQLite fallbacks ───────────────────────────────────────────────

  Future<List<AppTransaction>> _localGetPage({
    int offset = 0,
    int limit = AppConstants.transactionPageSize,
    String? searchQuery,
    String? category,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db.database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add('(merchant LIKE ? OR note LIKE ?)');
      args.addAll(['%$searchQuery%', '%$searchQuery%']);
    }
    if (category != null) {
      conditions.add('category = ?');
      args.add(category);
    }
    if (from != null) {
      conditions.add('date >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      conditions.add('date <= ?');
      args.add(to.millisecondsSinceEpoch);
    }

    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    final rows = await db.query(
      'transactions',
      where: where,
      whereArgs: where != null ? args : null,
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(AppTransaction.fromMap).toList();
  }

  Future<MonthlySummary> _localMonthlySummary() async {
    final db = await _db.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final end =
        DateTime(now.year, now.month + 1, 0, 23, 59, 59).millisecondsSinceEpoch;

    final incomeResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE type = "income" AND date >= ? AND date <= ?',
      [start, end],
    );
    final expenseResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE type = "expense" AND date >= ? AND date <= ?',
      [start, end],
    );

    final income = (incomeResult.first['total'] as num).toDouble();
    final expenses = (expenseResult.first['total'] as num).toDouble();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    return MonthlySummary(
      totalIncome: income,
      totalExpenses: expenses,
      dailyExpenseAvg: expenses / daysInMonth,
    );
  }

  Future<double> _localNetWorth(double portfolioValue) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(CASE WHEN type="income" THEN amount ELSE -amount END), 0) as net FROM transactions',
    );
    return (result.first['net'] as num).toDouble() + portfolioValue;
  }

  Future<Map<String, double>> _localCategoryBreakdown(
      {DateTime? from, DateTime? to}) async {
    final db = await _db.database;
    from ??= DateTime(DateTime.now().year, DateTime.now().month, 1);
    to ??= DateTime.now();

    final rows = await db.rawQuery(
      '''SELECT category, SUM(amount) as total
         FROM transactions
         WHERE type = "expense" AND date >= ? AND date <= ?
         GROUP BY category''',
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return {
      for (final r in rows)
        r['category'] as String: (r['total'] as num).toDouble()
    };
  }

  Future<List<double>> _localDailyBreakdown({int days = 7}) async {
    final db = await _db.database;
    final now = DateTime.now();
    final results = <double>[];

    for (int i = days - 1; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final nextDay = day.add(const Duration(days: 1));
      final rows = await db.rawQuery(
        'SELECT COALESCE(SUM(amount),0) as t FROM transactions WHERE type="expense" AND date>=? AND date<?',
        [day.millisecondsSinceEpoch, nextDay.millisecondsSinceEpoch],
      );
      results.add((rows.first['t'] as num).toDouble());
    }
    return results;
  }

  Future<List<double>> _localMonthlySavings(int months) async {
    final db = await _db.database;
    final results = <double>[];
    final now = DateTime.now();

    for (int i = months - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(month.year, month.month + 1, 1);

      final inc = await db.rawQuery(
        'SELECT COALESCE(SUM(amount),0) as t FROM transactions WHERE type="income" AND date>=? AND date<?',
        [month.millisecondsSinceEpoch, nextMonth.millisecondsSinceEpoch],
      );
      final exp = await db.rawQuery(
        'SELECT COALESCE(SUM(amount),0) as t FROM transactions WHERE type="expense" AND date>=? AND date<?',
        [month.millisecondsSinceEpoch, nextMonth.millisecondsSinceEpoch],
      );
      results.add(
          (inc.first['t'] as num).toDouble() -
          (exp.first['t'] as num).toDouble());
    }
    return results;
  }

  // ─── Model converter (remote JSON → AppTransaction) ───────────────────────

  AppTransaction _txnFromRemote(Map<String, dynamic> e) {
    // Backend returns ISO dates and MongoDB _id; normalise for fromMap
    final map = Map<String, dynamic>.from(e);
    map['id'] = map['_id'] ?? map['id'];
    if (map['date'] is String) {
      map['date'] = DateTime.parse(map['date'] as String).millisecondsSinceEpoch;
    }
    if (map['createdAt'] is String) {
      map['created_at'] =
          DateTime.parse(map['createdAt'] as String).millisecondsSinceEpoch;
    }
    map.remove('_id');
    map.remove('__v');
    return AppTransaction.fromMap(map);
  }
}
