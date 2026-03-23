class UserProfile {
  final String id;
  final String displayName;
  final String preferredCurrency;
  final bool onboardingComplete;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.preferredCurrency,
    required this.onboardingComplete,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'display_name': displayName,
    'preferred_currency': preferredCurrency,
    'onboarding_complete': onboardingComplete ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
    id: m['id'] as String,
    displayName: m['display_name'] as String,
    preferredCurrency: m['preferred_currency'] as String? ?? 'INR',
    onboardingComplete: (m['onboarding_complete'] as int) == 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
  );

  UserProfile copyWith({
    String? displayName,
    String? preferredCurrency,
    bool? onboardingComplete,
  }) => UserProfile(
    id: id,
    displayName: displayName ?? this.displayName,
    preferredCurrency: preferredCurrency ?? this.preferredCurrency,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    createdAt: createdAt,
  );
}
