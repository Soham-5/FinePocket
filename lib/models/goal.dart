class Goal {
  final String id;
  final String name;
  final double targetAmount;
  final int? monthsToAchieve;
  double savedAmount;

  Goal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.monthsToAchieve,
    this.savedAmount = 0.0,
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'],
      name: json['name'],
      targetAmount: json['targetAmount'].toDouble(),
      monthsToAchieve: json['monthsToAchieve'],
      savedAmount: json['savedAmount']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'monthsToAchieve': monthsToAchieve,
      'savedAmount': savedAmount,
    };
  }

  double get progressPercentage =>
      targetAmount > 0 ? (savedAmount / targetAmount) : 0;
}
