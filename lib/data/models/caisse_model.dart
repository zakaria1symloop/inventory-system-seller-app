class CaisseModel {
  final int id;
  final int userId;
  final String type;
  final double balance;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  CaisseModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.balance,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory CaisseModel.fromJson(Map<String, dynamic> json) {
    return CaisseModel(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'] ?? '',
      balance: (json['balance'] is String)
          ? double.tryParse(json['balance']) ?? 0
          : (json['balance'] ?? 0).toDouble(),
      isActive: json['is_active'] == true || json['is_active'] == 1,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}
