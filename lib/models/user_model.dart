enum UserRole {
  admin,
  cashier,
}

class User {
  int? id;
  final String username;
  final String password;
  final String fullName;
  final UserRole role;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  User({
    this.id,
    required this.username,
    required this.password,
    required this.fullName,
    required this.role,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      password: map['password'],
      fullName: map['fullName'],
      role: _parseRole(map['role']),
      isActive: (map['isActive'] ?? 1) == 1,
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'fullName': fullName,
      'role': role.name,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  User copyWith({
    int? id,
    String? username,
    String? password,
    String? fullName,
    UserRole? role,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static UserRole _parseRole(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'cashier':
      default:
        return UserRole.cashier;
    }
  }

  String getRoleDisplayName() {
    switch (role) {
      case UserRole.admin:
        return 'مدير النظام';
      case UserRole.cashier:
        return 'كاشير';
    }
  }

  bool hasPermission(String permission) {
    // Admin has all permissions
    if (role == UserRole.admin) return true;

    // Cashier permissions
    if (role == UserRole.cashier) {
      const cashierPermissions = [
        'cashier',
        'products_view',
        'inventory_view',
      ];
      return cashierPermissions.contains(permission);
    }

    return false;
  }
}
