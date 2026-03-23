enum GoalStatus { active, completed, paused }

class Goal {
  final String id;
  final String name;
  final String emoji;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final double dailyTarget;
  final GoalStatus status;
  final String currency;
  final DateTime createdAt;

  const Goal({
    required this.id,
    required this.name,
    required this.emoji,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    required this.dailyTarget,
    required this.status,
    required this.currency,
    required this.createdAt,
  });

  double get progressPercent =>
      (currentAmount / targetAmount).clamp(0.0, 1.0);

  double get remaining => (targetAmount - currentAmount).clamp(0, double.infinity);

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'target_amount': targetAmount,
    'current_amount': currentAmount,
    'target_date': targetDate?.millisecondsSinceEpoch,
    'daily_target': dailyTarget,
    'status': status.name,
    'currency': currency,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory Goal.fromMap(Map<String, dynamic> m) => Goal(
    id: m['id'] as String,
    name: m['name'] as String,
    emoji: m['emoji'] as String? ?? '🎯',
    targetAmount: (m['target_amount'] as num).toDouble(),
    currentAmount: (m['current_amount'] as num).toDouble(),
    targetDate: m['target_date'] != null
        ? DateTime.fromMillisecondsSinceEpoch(m['target_date'] as int)
        : null,
    dailyTarget: (m['daily_target'] as num).toDouble(),
    status: GoalStatus.values.firstWhere(
      (e) => e.name == m['status'],
      orElse: () => GoalStatus.active,
    ),
    currency: m['currency'] as String? ?? 'INR',
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
  );

  Goal copyWith({
    String? name,
    String? emoji,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    double? dailyTarget,
    GoalStatus? status,
    String? currency,
  }) => Goal(
    id: id,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    targetAmount: targetAmount ?? this.targetAmount,
    currentAmount: currentAmount ?? this.currentAmount,
    targetDate: targetDate ?? this.targetDate,
    dailyTarget: dailyTarget ?? this.dailyTarget,
    status: status ?? this.status,
    currency: currency ?? this.currency,
    createdAt: createdAt,
  );
}
