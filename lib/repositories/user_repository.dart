import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/user_model.dart';
import '../utils/password_hasher.dart';

class UserRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<int> createUser(User user) async {
    _validatePassword(user.password);
    final db = await _databaseHelper.database;
    final values = user.toMap()
      ..['username'] = user.username.trim()
      ..['password'] = await PasswordHasher.hash(user.password);
    return db.insert('users', values);
  }

  Future<User> createInitialAdmin({
    required String username,
    required String password,
    required String fullName,
  }) async {
    _validatePassword(password);
    final normalizedUsername = username.trim();
    final normalizedFullName = fullName.trim();
    if (normalizedUsername.isEmpty || normalizedFullName.isEmpty) {
      throw ArgumentError('Username and full name are required');
    }

    final db = await _databaseHelper.database;
    final hashedPassword = await PasswordHasher.hash(password);
    return db.transaction((transaction) async {
      final existing = await transaction.rawQuery(
        'SELECT COUNT(*) AS count FROM users',
      );
      if ((existing.single['count'] as num).toInt() != 0) {
        throw StateError('Initial administrator is already configured');
      }

      final now = DateTime.now().toIso8601String();
      final id = await transaction.insert('users', {
        'username': normalizedUsername,
        'password': hashedPassword,
        'fullName': normalizedFullName,
        'role': UserRole.admin.name,
        'isActive': 1,
        'canAccessReports': 1,
        'canAccessProfits': 1,
        'canAccessSettings': 1,
        'canDiscount': 1,
        'createdAt': now,
        'updatedAt': now,
      });
      return User.fromMap({
        'id': id,
        'username': normalizedUsername,
        'password': hashedPassword,
        'fullName': normalizedFullName,
        'role': UserRole.admin.name,
        'isActive': 1,
        'canAccessReports': 1,
        'canAccessProfits': 1,
        'canAccessSettings': 1,
        'canDiscount': 1,
        'createdAt': now,
        'updatedAt': now,
      });
    });
  }

  Future<List<User>> getAllUsers() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('users');
    return maps.map((map) => User.fromMap(map)).toList();
  }

  Future<User?> getUserById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<User?> getUserByUsername(String username) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<User?> authenticate(String username, String password) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ? AND isActive = 1',
      whereArgs: [username.trim()],
    );
    if (maps.isEmpty) return null;
    final userRow = maps.first;
    final storedPassword = userRow['password'] as String;
    if (!await PasswordHasher.verify(password, storedPassword)) return null;

    if (!storedPassword.startsWith('pbkdf2-sha256\$')) {
      final hashedPassword = await PasswordHasher.hash(password);
      await db.update(
        'users',
        {'password': hashedPassword},
        where: 'id = ? AND password = ?',
        whereArgs: [userRow['id'], storedPassword],
      );
    }

    return User.fromMap(userRow);
  }

  Future<int> updateUser(User user) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    final values = <String, Object?>{
      'username': user.username.trim(),
      'fullName': user.fullName,
      'role': user.role.name,
      'isActive': user.isActive ? 1 : 0,
      'canAccessReports': user.canAccessReports ? 1 : 0,
      'canAccessProfits': user.canAccessProfits ? 1 : 0,
      'canAccessSettings': user.canAccessSettings ? 1 : 0,
      'canDiscount': user.canDiscount ? 1 : 0,
      'updatedAt': now,
    };
    if (user.password.isNotEmpty) {
      _validatePassword(user.password);
      values['password'] = await PasswordHasher.hash(user.password);
    }
    return db.update('users', values, where: 'id = ?', whereArgs: [user.id]);
  }

  Future<int> deleteUser(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> changePassword(int userId, String newPassword) async {
    _validatePassword(newPassword);
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    return await db.update(
      'users',
      {'password': await PasswordHasher.hash(newPassword), 'updatedAt': now},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<bool> usernameExists(String username, {int? excludeId}) async {
    final db = await _databaseHelper.database;
    String query = 'SELECT COUNT(*) FROM users WHERE username = ?';
    List<dynamic> args = [username];

    if (excludeId != null) {
      query += ' AND id != ?';
      args.add(excludeId);
    }

    final result = await db.rawQuery(query, args);
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  static void _validatePassword(String password) {
    if (password.length < 12) {
      throw ArgumentError.value(
        password.length,
        'password',
        'Password must be at least 12 characters',
      );
    }
  }
}
