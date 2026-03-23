enum AssetClass { equities, realEstate, fixedIncome, crypto, cash }

extension AssetClassX on AssetClass {
  String get label {
    switch (this) {
      case AssetClass.equities: return 'Equities';
      case AssetClass.realEstate: return 'Real Estate';
      case AssetClass.fixedIncome: return 'Fixed Income';
      case AssetClass.crypto: return 'Crypto';
      case AssetClass.cash: return 'Cash';
    }
  }
}

class Investment {
  final String id;
  final String name;
  final String ticker;
  final AssetClass assetClass;
  final double units;
  final double currentPrice;
  final double sevenDayReturn;
  final String currency;
  final DateTime lastUpdated;

  const Investment({
    required this.id,
    required this.name,
    required this.ticker,
    required this.assetClass,
    required this.units,
    required this.currentPrice,
    required this.sevenDayReturn,
    required this.currency,
    required this.lastUpdated,
  });

  double get totalValue => units * currentPrice;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'ticker': ticker,
    'asset_class': assetClass.name,
    'units': units,
    'current_price': currentPrice,
    'seven_day_return': sevenDayReturn,
    'currency': currency,
    'last_updated': lastUpdated.millisecondsSinceEpoch,
  };

  factory Investment.fromMap(Map<String, dynamic> m) => Investment(
    id: m['id'] as String,
    name: m['name'] as String,
    ticker: m['ticker'] as String,
    assetClass: AssetClass.values.firstWhere(
      (e) => e.name == m['asset_class'],
      orElse: () => AssetClass.equities,
    ),
    units: (m['units'] as num).toDouble(),
    currentPrice: (m['current_price'] as num).toDouble(),
    sevenDayReturn: (m['seven_day_return'] as num).toDouble(),
    currency: m['currency'] as String? ?? 'INR',
    lastUpdated: DateTime.fromMillisecondsSinceEpoch(m['last_updated'] as int),
  );
}

class InvestmentSnapshot {
  final String id;
  final DateTime date;
  final double totalPortfolioValue;
  final String currency;

  const InvestmentSnapshot({
    required this.id,
    required this.date,
    required this.totalPortfolioValue,
    required this.currency,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.millisecondsSinceEpoch,
    'total_portfolio_value': totalPortfolioValue,
    'currency': currency,
  };

  factory InvestmentSnapshot.fromMap(Map<String, dynamic> m) => InvestmentSnapshot(
    id: m['id'] as String,
    date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
    totalPortfolioValue: (m['total_portfolio_value'] as num).toDouble(),
    currency: m['currency'] as String? ?? 'INR',
  );
}
