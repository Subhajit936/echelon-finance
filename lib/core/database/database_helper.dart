import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants/app_constants.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id          TEXT PRIMARY KEY,
        merchant    TEXT NOT NULL,
        category    TEXT NOT NULL,
        type        TEXT NOT NULL,
        amount      REAL NOT NULL,
        date        INTEGER NOT NULL,
        status      TEXT NOT NULL DEFAULT 'cleared',
        note        TEXT,
        currency    TEXT NOT NULL DEFAULT 'INR',
        created_at  INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_txn_date ON transactions(date DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_txn_type ON transactions(type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_txn_cat  ON transactions(category)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goals (
        id              TEXT PRIMARY KEY,
        name            TEXT NOT NULL,
        emoji           TEXT NOT NULL DEFAULT '🎯',
        target_amount   REAL NOT NULL,
        current_amount  REAL NOT NULL DEFAULT 0,
        target_date     INTEGER,
        daily_target    REAL NOT NULL DEFAULT 0,
        status          TEXT NOT NULL DEFAULT 'active',
        currency        TEXT NOT NULL DEFAULT 'INR',
        created_at      INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS investments (
        id                TEXT PRIMARY KEY,
        name              TEXT NOT NULL,
        ticker            TEXT NOT NULL,
        asset_class       TEXT NOT NULL,
        units             REAL NOT NULL DEFAULT 0,
        current_price     REAL NOT NULL DEFAULT 0,
        seven_day_return  REAL NOT NULL DEFAULT 0,
        currency          TEXT NOT NULL DEFAULT 'INR',
        last_updated      INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS investment_snapshots (
        id                    TEXT PRIMARY KEY,
        date                  INTEGER NOT NULL,
        total_portfolio_value REAL NOT NULL,
        currency              TEXT NOT NULL DEFAULT 'INR'
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_snap_date ON investment_snapshots(date DESC)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id            TEXT PRIMARY KEY,
        category      TEXT NOT NULL,
        limit_amount  REAL NOT NULL,
        period_start  INTEGER NOT NULL,
        period_end    INTEGER NOT NULL,
        currency      TEXT NOT NULL DEFAULT 'INR'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id                    TEXT PRIMARY KEY DEFAULT '1',
        display_name          TEXT NOT NULL DEFAULT 'User',
        preferred_currency    TEXT NOT NULL DEFAULT 'INR',
        onboarding_complete   INTEGER NOT NULL DEFAULT 0,
        created_at            INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_messages (
        id                    TEXT PRIMARY KEY,
        role                  TEXT NOT NULL,
        content               TEXT NOT NULL,
        intent                TEXT NOT NULL DEFAULT 'conversation',
        timestamp             INTEGER NOT NULL,
        parsed_transaction_id TEXT,
        is_error              INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_chat_ts ON chat_messages(timestamp DESC)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here
  }

  /// Clears all user-generated data from local SQLite (called on login to
  /// eliminate stale seed/test data and start fresh from the remote source).
  Future<void> clearUserData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('goals');
      await txn.delete('investments');
      await txn.delete('investment_snapshots');
      await txn.delete('budgets');
      await txn.delete('chat_messages');
      // Keep user_profile — it holds currency preference + onboarding flag
    });
  }
}
