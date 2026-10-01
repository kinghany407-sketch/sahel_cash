class Supplier {
  int? id;
  final String name;
  final String? phone;
  final String? address;
  final double initialBalance;
  final double currentBalance;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  Supplier({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.initialBalance = 0,
    this.currentBalance = 0,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'initialBalance': initialBalance,
      'currentBalance': currentBalance,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'],
      name: map['name'] ?? '',
      phone: map['phone'],
      address: map['address'],
      initialBalance: (map['initialBalance'] ?? 0).toDouble(),
      currentBalance: (map['currentBalance'] ?? 0).toDouble(),
      notes: map['notes'],
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }

  Supplier copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    double? initialBalance,
    double? currentBalance,
    String? notes,
    String? createdAt,
    String? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}