import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/user_model.dart';

class UserRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<int> createUser(User user) async {
    final db = await _databaseHelper.database;
    return await db.insert('users', user.toMap());
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
      where: 'username = ? AND password = ? AND isActive = 1',
      whereArgs: [username, password],
    );
    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<int> updateUser(User user) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    return await db.update(
      'users',
      {
        'username': user.username,
        'password': user.password,
        'fullName': user.fullName,
        'role': user.role.name,
        'isActive': user.isActive ? 1 : 0,
        'canAccessReports': user.canAccessReports ? 1 : 0,
        'canAccessProfits': user.canAccessProfits ? 1 : 0,
        'canAccessSettings': user.canAccessSettings ? 1 : 0,
        'canDiscount': user.canDiscount ? 1 : 0,
        'updatedAt': now,
      },
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> changePassword(int userId, String newPassword) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    return await db.update(
      'users',
      {
        'password': newPassword,
        'updatedAt': now,
      },
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
}
