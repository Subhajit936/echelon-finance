import 'package:uuid/uuid.dart';
import 'database_helper.dart';
import '../../data/models/transaction.dart';
import '../../data/models/goal.dart';
import '../../data/models/investment.dart';

const _uuid = Uuid();

class SeedData {
  static Future<void> seed(DatabaseHelper db, String currency) async {
    final dbInstance = await db.database;

    // Check if already seeded
    final count = await dbInstance.rawQuery('SELECT COUNT(*) as c FROM transactions');
    if ((count.first['c'] as int) > 0) return;

    final now = DateTime.now();

    // Sample transactions
    final transactions = [
      AppTransaction(
        id: _uuid.v4(),
        merchant: 'Salary - Company',
        category: TransactionCategory.salary,
        type: TransactionType.income,
        amount: currency == 'INR' ? 75000 : 2500,
        date: DateTime(now.year, now.month, 1),
        status: TransactionStatus.cleared,
        currency: currency,
        createdAt: DateTime(now.year, now.month, 1),
      ),
      AppTransaction(
        id: _uuid.v4(),
        merchant: 'Swiggy',
        category: TransactionCategory.food,
        type: TransactionType.expense,
        amount: currency == 'INR' ? 450 : 12,
        date: now.subtract(const Duration(days: 1)),
        status: TransactionStatus.cleared,
        currency: currency,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      AppTransaction(
        id: _uuid.v4(),
        merchant: 'Ola/Uber',
        category: TransactionCategory.transport,
        type: TransactionType.expense,
        amount: currency == 'INR' ? 280 : 8,
        date: now.subtract(const Duration(days: 2)),
        status: TransactionStatus.cleared,
        currency: currency,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      AppTransaction(
        id: _uuid.v4(),
        merchant: 'Netflix',
        category: TransactionCategory.entertainment,
        type: TransactionType.expense,
        amount: currency == 'INR' ? 649 : 15,
        date: now.subtract(const Duration(days: 3)),
        status: TransactionStatus.subscription,
        currency: currency,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      AppTransaction(
        id: _uuid.v4(),
        merchant: 'Amazon',
        category: TransactionCategory.shopping,
        type: TransactionType.expense,
        amount: currency == 'INR' ? 1299 : 45,
        date: now.subtract(const Duration(days: 4)),
        status: TransactionStatus.cleared,
        currency: currency,
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      AppTransaction(
        id: _uuid.v4(),
        merchant: 'Electricity Bill',
        category: TransactionCategory.utilities,
        type: TransactionType.expense,
        amount: currency == 'INR' ? 1800 : 60,
        date: now.subtract(const Duration(days: 5)),
        status: TransactionStatus.cleared,
        currency: currency,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      AppTransaction(
        id: _uuid.v4(),
        merchant: 'Freelance Project',
        category: TransactionCategory.freelance,
        type: TransactionType.income,
        amount: currency == 'INR' ? 12000 : 400,
        date: now.subtract(const Duration(days: 7)),
        status: TransactionStatus.cleared,
        currency: currency,
        createdAt: now.subtract(const Duration(days: 7)),
      ),
      AppTransaction(
        id: _uuid.v4(),
        merchant: 'Zomato',
        category: TransactionCategory.food,
        type: TransactionType.expense,
        amount: currency == 'INR' ? 320 : 10,
        date: now.subtract(const Duration(days: 8)),
        status: TransactionStatus.cleared,
        currency: currency,
        createdAt: now.subtract(const Duration(days: 8)),
      ),
    ];

    for (final txn in transactions) {
      await dbInstance.insert('transactions', txn.toMap());
    }

    // Sample goals
    final goals = [
      Goal(
        id: _uuid.v4(),
        name: 'Emergency Fund',
        emoji: '🏦',
        targetAmount: currency == 'INR' ? 150000 : 5000,
        currentAmount: currency == 'INR' ? 45000 : 1500,
        dailyTarget: currency == 'INR' ? 250 : 8,
        status: GoalStatus.active,
        currency: currency,
        createdAt: now.subtract(const Duration(days: 30)),
        targetDate: DateTime(now.year, now.month + 6, 1),
      ),
      Goal(
        id: _uuid.v4(),
        name: 'New Laptop',
        emoji: '💻',
        targetAmount: currency == 'INR' ? 80000 : 1200,
        currentAmount: currency == 'INR' ? 30000 : 450,
        dailyTarget: currency == 'INR' ? 150 : 5,
        status: GoalStatus.active,
        currency: currency,
        createdAt: now.subtract(const Duration(days: 15)),
        targetDate: DateTime(now.year, now.month + 4, 1),
      ),
    ];

    for (final goal in goals) {
      await dbInstance.insert('goals', goal.toMap());
    }

    // Sample investments
    final investments = [
      Investment(
        id: _uuid.v4(),
        name: 'Nifty 50 Index Fund',
        ticker: 'NIFTY50',
        assetClass: AssetClass.equities,
        units: 10.5,
        currentPrice: currency == 'INR' ? 2200 : 26,
        sevenDayReturn: 1.8,
        currency: currency,
        lastUpdated: now,
      ),
      Investment(
        id: _uuid.v4(),
        name: 'Bitcoin',
        ticker: 'BTC',
        assetClass: AssetClass.crypto,
        units: 0.02,
        currentPrice: currency == 'INR' ? 5000000 : 65000,
        sevenDayReturn: -2.3,
        currency: currency,
        lastUpdated: now,
      ),
    ];

    for (final inv in investments) {
      await dbInstance.insert('investments', inv.toMap());
    }

    // Add investment snapshots for the chart (last 30 days)
    double baseValue = currency == 'INR' ? 90000 : 3000;
    for (int i = 30; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      baseValue *= (1 + (0.001 * (i % 3 == 0 ? 1 : -0.5)));
      await dbInstance.insert('investment_snapshots', {
        'id': _uuid.v4(),
        'date': date.millisecondsSinceEpoch,
        'total_portfolio_value': baseValue,
        'currency': currency,
      });
    }
  }
}
