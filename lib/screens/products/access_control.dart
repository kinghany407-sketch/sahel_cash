enum UserRole { admin, supervisor, cashier }

class ProductAccess {
  static const String restrictedMessage = 'هذه العملية تتطلب صلاحية المدير';

  static bool canAccessPurchasePrice(UserRole role) => role != UserRole.cashier;

  static bool canAccessProfit(UserRole role) => role == UserRole.admin;

  static bool canAccessReports(UserRole role) => role == UserRole.admin;

  static bool canAccessSettings(UserRole role) => role == UserRole.admin;

  static bool canAccessSuppliers(UserRole role) => role != UserRole.cashier;

  static bool canAccessAdvancedSettings(UserRole role) =>
      role != UserRole.cashier;

  static bool canAccessRestrictedSection(UserRole role) =>
      role == UserRole.admin;

  static String roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'مدير';
      case UserRole.supervisor:
        return 'مشرف';
      case UserRole.cashier:
        return 'أمين صندوق';
    }
  }
}
