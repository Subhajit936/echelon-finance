class Budget {
  final String id;
  final String category;
  final double limitAmount;
  final double spentAmount;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String currency;

  const Budget({
    required this.id,
    required this.category,
    required this.limitAmount,
    required this.spentAmount,
    required this.periodStart,
    required this.periodEnd,
    required this.currency,
  });

  double get remainingAmount => (limitAmount - spentAmount).clamp(0, double.infinity);
  double get utilizedPercent => (spentAmount / limitAmount).clamp(0.0, 1.0);

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category,
    'limit_amount': limitAmount,
    'period_start': periodStart.millisecondsSinceEpoch,
    'period_end': periodEnd.millisecondsSinceEpoch,
    'currency': currency,
  };

  factory Budget.fromMap(Map<String, dynamic> m, {double spentAmount = 0}) => Budget(
    id: m['id'] as String,
    category: m['category'] as String,
    limitAmount: (m['limit_amount'] as num).toDouble(),
    spentAmount: spentAmount,
    periodStart: DateTime.fromMillisecondsSinceEpoch(m['period_start'] as int),
    periodEnd: DateTime.fromMillisecondsSinceEpoch(m['period_end'] as int),
    currency: m['currency'] as String? ?? 'INR',
  );
}
