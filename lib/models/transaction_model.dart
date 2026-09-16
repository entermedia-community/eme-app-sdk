class TransactionItemModel {
  final String id;
  final String title;
  final String date;
  final String amount;
  final bool isCredit;
  final String category;

  const TransactionItemModel({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    required this.isCredit,
    required this.category,
  });

  factory TransactionItemModel.fromJson(Map<String, dynamic> json) {
    return TransactionItemModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      date: json['date'] as String? ?? '',
      amount: json['amount'] as String? ?? '',
      isCredit: json['isCredit'] as bool? ?? false,
      category: json['category'] as String? ?? 'General',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'amount': amount,
      'isCredit': isCredit,
      'category': category,
    };
  }

  TransactionItemModel copyWith({
    String? id,
    String? title,
    String? date,
    String? amount,
    bool? isCredit,
    String? category,
  }) {
    return TransactionItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      isCredit: isCredit ?? this.isCredit,
      category: category ?? this.category,
    );
  }
}
