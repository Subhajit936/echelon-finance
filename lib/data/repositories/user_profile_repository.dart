import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../models/user_profile.dart';

class UserProfileRepository {
  final DatabaseHelper _db;
  final ApiClient _api;
  UserProfileRepository(this._db, this._api);

  // ─── Remote helpers ───────────────────────────────────────────────────────

  Future<bool> _hasRemote() => _api.isConfigured();

  // ─── Read operations (remote-first, local fallback) ───────────────────────

  Future<UserProfile?> getProfile() async {
    try {
      if (await _hasRemote()) {
        final data =
            await _api.get(ApiEndpoints.profile) as Map<String, dynamic>?;
        if (data != null) return _profileFromRemote(data);
      }
    } catch (_) {}
    final db = await _db.database;
    final rows = await db.query('user_profile', limit: 1);
    if (rows.isEmpty) return null;
    return UserProfile.fromMap(rows.first);
  }

  // ─── Write operations (local + remote mirror) ────────────────────────────

  Future<void> upsert(UserProfile profile) async {
    final db = await _db.database;
    await db.insert('user_profile', profile.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    unawaited(_mirrorUpsert(profile));
  }

  Future<void> _mirrorUpsert(UserProfile profile) async {
    try {
      if (!await _hasRemote()) return;
      await _api.put(ApiEndpoints.profile, {
        'id': profile.id,
        'displayName': profile.displayName,
        'preferredCurrency': profile.preferredCurrency,
        'onboardingComplete': profile.onboardingComplete,
        'createdAt': profile.createdAt.toIso8601String(),
      });
    } catch (_) {}
  }

  // ─── Model converter ──────────────────────────────────────────────────────

  UserProfile _profileFromRemote(Map<String, dynamic> e) {
    final map = Map<String, dynamic>.from(e);
    map['id'] = map['_id'] ?? map['id'];
    if (map['displayName'] != null) map['display_name'] = map['displayName'];
    if (map['preferredCurrency'] != null) {
      map['preferred_currency'] = map['preferredCurrency'];
    }
    if (map['onboardingComplete'] != null) {
      map['onboarding_complete'] = (map['onboardingComplete'] == true) ? 1 : 0;
    }
    if (map['createdAt'] is String) {
      map['created_at'] =
          DateTime.parse(map['createdAt'] as String).millisecondsSinceEpoch;
    }
    map.remove('_id');
    map.remove('__v');
    return UserProfile.fromMap(map);
  }
}
