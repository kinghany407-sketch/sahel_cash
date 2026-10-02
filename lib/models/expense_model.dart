class Expense {
  int? id;
  final String category;
  final double amount;
  final String date;
  final String? notes;
  final String createdAt;

  static const List<String> categories = [
    'إيجار',
    'رواتب',
    'فواتير',
    'مشتريات تشغيلية',
    'نقل',
    'أخرى',
  ];

  Expense({
    this.id,
    required this.category,
    required this.amount,
    required this.date,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category,
    'amount': amount,
    'date': date,
    'notes': notes,
    'createdAt': createdAt,
  };

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      category: map['category'] ?? 'أخرى',
      amount: (map['amount'] ?? 0).toDouble(),
      date: map['date'] ?? '',
      notes: map['notes'],
      createdAt: map['createdAt'] ?? '',
    );
  }
}
