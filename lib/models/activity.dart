class Activity {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final bool isExpense;
  final String category;

  Activity({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    this.isExpense = true,
    this.category = 'Other',
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'],
      title: json['title'],
      amount: json['amount'].toDouble(),
      date: DateTime.parse(json['date']),
      isExpense: json['isExpense'] ?? true,
      category: json['category'] ?? 'Other',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'isExpense': isExpense,
      'category': category,
    };
  }
}
