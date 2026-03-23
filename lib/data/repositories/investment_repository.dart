import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../models/investment.dart';

class InvestmentRepository {
  final DatabaseHelper _db;
  final ApiClient _api;
  InvestmentRepository(this._db, this._api);

  // ─── Remote helpers ───────────────────────────────────────────────────────

  Future<bool> _hasRemote() => _api.isConfigured();

  // ─── Write operations (local + remote mirror) ────────────────────────────

  Future<void> upsertInvestment(Investment inv) async {
    final db = await _db.database;
    await db.insert('investments', inv.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    unawaited(_mirrorUpsertInvestment(inv));
  }

  Future<void> _mirrorUpsertInvestment(Investment inv) async {
    try {
      if (!await _hasRemote()) return;
      await _api.post(ApiEndpoints.investments, _invToRemoteMap(inv));
    } catch (_) {}
  }

  Future<void> deleteInvestment(String id) async {
    final db = await _db.database;
    await db.delete('investments', where: 'id = ?', whereArgs: [id]);
    unawaited(_mirrorDeleteInvestment(id));
  }

  Future<void> _mirrorDeleteInvestment(String id) async {
    try {
      if (!await _hasRemote()) return;
      await _api.delete(ApiEndpoints.investmentById(id));
    } catch (_) {}
  }

  Future<void> addSnapshot(InvestmentSnapshot snapshot) async {
    final db = await _db.database;
    await db.insert('investment_snapshots', snapshot.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    unawaited(_mirrorSnapshot(snapshot));
  }

  Future<void> _mirrorSnapshot(InvestmentSnapshot snapshot) async {
    try {
      if (!await _hasRemote()) return;
      await _api.post(ApiEndpoints.investmentSnapshots, {
        'id': snapshot.id,
        'date': snapshot.date.toIso8601String(),
        'totalPortfolioValue': snapshot.totalPortfolioValue,
        'currency': snapshot.currency,
      });
    } catch (_) {}
  }

  // ─── Read operations (remote-first, local fallback) ───────────────────────

  Future<List<Investment>> getAll() async {
    try {
      if (await _hasRemote()) {
        final data = await _api.get(ApiEndpoints.investments) as List;
        return data.map((e) => _invFromRemote(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    final db = await _db.database;
    final rows = await db.query('investments', orderBy: 'last_updated DESC');
    return rows.map(Investment.fromMap).toList();
  }

  Future<double> getTotalValue() async {
    try {
      if (await _hasRemote()) {
        final data = await _api.get(ApiEndpoints.investmentsTotalValue)
            as Map<String, dynamic>;
        return (data['totalValue'] as num).toDouble();
      }
    } catch (_) {}
    return _localTotalValue();
  }

  Future<double> _localTotalValue() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(units * current_price), 0) as total FROM investments',
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<Map<String, double>> getAllocation() async {
    try {
      if (await _hasRemote()) {
        final data = await _api.get(ApiEndpoints.investmentsAllocation)
            as Map<String, dynamic>;
        return data.map((k, v) => MapEntry(k, (v as num).toDouble()));
      }
    } catch (_) {}
    return _localAllocation();
  }

  Future<Map<String, double>> _localAllocation() async {
    final all = await getAll();
    final totals = <String, double>{};
    for (final inv in all) {
      final key = inv.assetClass.name;
      totals[key] = (totals[key] ?? 0) + inv.totalValue;
    }
    return totals;
  }

  Future<List<InvestmentSnapshot>> getSnapshots({int limit = 365}) async {
    try {
      if (await _hasRemote()) {
        final data = await _api.get(ApiEndpoints.investmentSnapshots,
            query: {'limit': limit.toString()}) as List;
        return data
            .map((e) => _snapshotFromRemote(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    final db = await _db.database;
    final rows = await db.query(
      'investment_snapshots',
      orderBy: 'date ASC',
      limit: limit,
    );
    return rows.map(InvestmentSnapshot.fromMap).toList();
  }

  // ─── Model converters ─────────────────────────────────────────────────────

  Map<String, dynamic> _invToRemoteMap(Investment inv) {
    return {
      'id': inv.id,
      'name': inv.name,
      'ticker': inv.ticker,
      'assetClass': inv.assetClass.name,
      'units': inv.units,
      'currentPrice': inv.currentPrice,
      'sevenDayReturn': inv.sevenDayReturn,
      'currency': inv.currency,
      'lastUpdated': inv.lastUpdated.toIso8601String(),
    };
  }

  Investment _invFromRemote(Map<String, dynamic> e) {
    final map = Map<String, dynamic>.from(e);
    map['id'] = map['_id'] ?? map['id'];
    // Normalise camelCase → snake_case for fromMap
    if (map['assetClass'] != null) map['asset_class'] = map['assetClass'];
    if (map['currentPrice'] != null) map['current_price'] = map['currentPrice'];
    if (map['sevenDayReturn'] != null) {
      map['seven_day_return'] = map['sevenDayReturn'];
    }
    if (map['lastUpdated'] is String) {
      map['last_updated'] =
          DateTime.parse(map['lastUpdated'] as String).millisecondsSinceEpoch;
    }
    map.remove('_id');
    map.remove('__v');
    return Investment.fromMap(map);
  }

  InvestmentSnapshot _snapshotFromRemote(Map<String, dynamic> e) {
    final map = Map<String, dynamic>.from(e);
    map['id'] = map['_id'] ?? map['id'];
    if (map['date'] is String) {
      map['date'] =
          DateTime.parse(map['date'] as String).millisecondsSinceEpoch;
    }
    if (map['totalPortfolioValue'] != null) {
      map['total_portfolio_value'] = map['totalPortfolioValue'];
    }
    map.remove('_id');
    map.remove('__v');
    return InvestmentSnapshot.fromMap(map);
  }
}
