enum UserRole {
  admin,
  supervisor,
  cashier,
}

class User {
  int? id;
  final String username;
  final String password;
  final String fullName;
  final UserRole role;
  final bool isActive;
  final bool canAccessReports;
  final bool canAccessProfits;
  final bool canAccessSettings;
  final bool canDiscount;
  final String createdAt;
  final String updatedAt;

  User({
    this.id,
    required this.username,
    required this.password,
    required this.fullName,
    required this.role,
    this.isActive = true,
    this.canAccessReports = false,
    this.canAccessProfits = false,
    this.canAccessSettings = false,
    this.canDiscount = false,
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
      canAccessReports: (map['canAccessReports'] ?? 0) == 1,
      canAccessProfits: (map['canAccessProfits'] ?? 0) == 1,
      canAccessSettings: (map['canAccessSettings'] ?? 0) == 1,
      canDiscount: (map['canDiscount'] ?? 0) == 1,
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
      'canAccessReports': canAccessReports ? 1 : 0,
      'canAccessProfits': canAccessProfits ? 1 : 0,
      'canAccessSettings': canAccessSettings ? 1 : 0,
      'canDiscount': canDiscount ? 1 : 0,
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
    bool? canAccessReports,
    bool? canAccessProfits,
    bool? canAccessSettings,
    bool? canDiscount,
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
      canAccessReports: canAccessReports ?? this.canAccessReports,
      canAccessProfits: canAccessProfits ?? this.canAccessProfits,
      canAccessSettings: canAccessSettings ?? this.canAccessSettings,
      canDiscount: canDiscount ?? this.canDiscount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static UserRole _parseRole(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'supervisor':
        return UserRole.supervisor;
      case 'cashier':
      default:
        return UserRole.cashier;
    }
  }

  String getRoleDisplayName() {
    switch (role) {
      case UserRole.admin:
        return 'مدير النظام';
      case UserRole.supervisor:
        return 'مشرف';
      case UserRole.cashier:
        return 'كاشير';
    }
  }

  bool hasPermission(String permission) {
    // Admin has all permissions
    if (role == UserRole.admin) return true;

    // Check specific permissions
    switch (permission) {
      case 'access_reports':
        return canAccessReports;
      case 'access_profits':
        return canAccessProfits;
      case 'access_settings':
        return canAccessSettings;
      case 'discount':
        return canDiscount;
      default:
        return false;
    }
  }
}
