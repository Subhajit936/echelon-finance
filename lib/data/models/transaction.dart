enum TransactionType { income, expense }

enum TransactionStatus { approved, cleared, pending, subscription }

enum TransactionCategory {
  food,
  transport,
  housing,
  utilities,
  entertainment,
  healthcare,
  education,
  shopping,
  salary,
  freelance,
  investment,
  other,
}

extension TransactionCategoryX on TransactionCategory {
  String get label {
    switch (this) {
      case TransactionCategory.food: return 'Food & Dining';
      case TransactionCategory.transport: return 'Transport';
      case TransactionCategory.housing: return 'Housing';
      case TransactionCategory.utilities: return 'Utilities';
      case TransactionCategory.entertainment: return 'Entertainment';
      case TransactionCategory.healthcare: return 'Healthcare';
      case TransactionCategory.education: return 'Education';
      case TransactionCategory.shopping: return 'Shopping';
      case TransactionCategory.salary: return 'Salary';
      case TransactionCategory.freelance: return 'Freelance';
      case TransactionCategory.investment: return 'Investment';
      case TransactionCategory.other: return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case TransactionCategory.food: return '🍽️';
      case TransactionCategory.transport: return '🚗';
      case TransactionCategory.housing: return '🏠';
      case TransactionCategory.utilities: return '💡';
      case TransactionCategory.entertainment: return '🎬';
      case TransactionCategory.healthcare: return '🏥';
      case TransactionCategory.education: return '📚';
      case TransactionCategory.shopping: return '🛍️';
      case TransactionCategory.salary: return '💼';
      case TransactionCategory.freelance: return '💻';
      case TransactionCategory.investment: return '📈';
      case TransactionCategory.other: return '💰';
    }
  }
}

class AppTransaction {
  final String id;
  final String merchant;
  final TransactionCategory category;
  final TransactionType type;
  final double amount;
  final DateTime date;
  final TransactionStatus status;
  final String? note;
  final String currency;
  final DateTime createdAt;

  const AppTransaction({
    required this.id,
    required this.merchant,
    required this.category,
    required this.type,
    required this.amount,
    required this.date,
    required this.status,
    this.note,
    required this.currency,
    required this.createdAt,
  });

  double get signedAmount => type == TransactionType.income ? amount : -amount;

  Map<String, dynamic> toMap() => {
    'id': id,
    'merchant': merchant,
    'category': category.name,
    'type': type.name,
    'amount': amount,
    'date': date.millisecondsSinceEpoch,
    'status': status.name,
    'note': note,
    'currency': currency,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory AppTransaction.fromMap(Map<String, dynamic> m) => AppTransaction(
    id: m['id'] as String,
    merchant: m['merchant'] as String,
    category: TransactionCategory.values.firstWhere(
      (e) => e.name == m['category'],
      orElse: () => TransactionCategory.other,
    ),
    type: TransactionType.values.firstWhere(
      (e) => e.name == m['type'],
      orElse: () => TransactionType.expense,
    ),
    amount: (m['amount'] as num).toDouble(),
    date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
    status: TransactionStatus.values.firstWhere(
      (e) => e.name == m['status'],
      orElse: () => TransactionStatus.cleared,
    ),
    note: m['note'] as String?,
    currency: m['currency'] as String? ?? 'INR',
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
  );

  AppTransaction copyWith({
    String? merchant,
    TransactionCategory? category,
    TransactionType? type,
    double? amount,
    DateTime? date,
    TransactionStatus? status,
    String? note,
    String? currency,
  }) => AppTransaction(
    id: id,
    merchant: merchant ?? this.merchant,
    category: category ?? this.category,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    date: date ?? this.date,
    status: status ?? this.status,
    note: note ?? this.note,
    currency: currency ?? this.currency,
    createdAt: createdAt,
  );
}
