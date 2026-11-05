import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahel_cash/database/database_helper.dart';
import 'package:sahel_cash/repositories/user_repository.dart';
import 'package:sahel_cash/screens/auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  Database? database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('sahel-cash-first-run-');
    final path = '${directory.path}${Platform.pathSeparator}first-run.db';
    await DatabaseHelper.createEmptyDistributionDatabase(path);
    database = await databaseFactoryFfi.openDatabase(path);
    DatabaseHelper.setDatabaseForTesting(database);
  });

  tearDown(() async {
    if (database?.isOpen ?? false) await database!.close();
    DatabaseHelper.setDatabaseForTesting(null);
    await directory.delete(recursive: true);
  });

  testWidgets('first run creates a chosen hashed admin account', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const LoginScreen(),
        routes: {
          '/home': (_) => const Scaffold(
            body: Text('home-screen', key: Key('home-screen')),
          ),
        },
      ),
    );
    await _pumpUntilVisible(
      tester,
      find.text('الإعداد الأولي: أنشئ حساب المدير بكلمة مرور قوية.'),
    );

    expect(
      find.text('الإعداد الأولي: أنشئ حساب المدير بكلمة مرور قوية.'),
      findsOneWidget,
    );
    expect(await tester.runAsync(() => _countUsers(database!)), 0);

    await tester.enterText(
      find.byKey(const ValueKey('first-run-full-name')),
      'مدير جديد',
    );
    await tester.enterText(
      find.byKey(const ValueKey('first-run-username')),
      'chosen-admin',
    );
    await tester.enterText(
      find.byKey(const ValueKey('first-run-password')),
      'unique-user-chosen-passphrase',
    );
    await tester.enterText(
      find.byKey(const ValueKey('first-run-confirm-password')),
      'unique-user-chosen-passphrase',
    );
    final createButton = find.text('إنشاء حساب المدير والدخول');
    await tester.ensureVisible(createButton);
    await tester.pump();
    await tester.tap(createButton);
    await _pumpUntilVisible(tester, find.byKey(const Key('home-screen')));

    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    final users = (await tester.runAsync(() => database!.query('users')))!;
    expect(users, hasLength(1));
    expect(users.single['username'], 'chosen-admin');
    final storedPassword = users.single['password'] as String;
    expect(storedPassword, startsWith('pbkdf2-sha256\$'));
    expect(storedPassword, isNot('unique-user-chosen-passphrase'));
    expect(storedPassword, isNot('admin123'));
    expect(storedPassword, isNot('123'));

    final repository = UserRepository();
    expect(
      await tester.runAsync(
        () => repository.authenticate(
          'chosen-admin',
          'unique-user-chosen-passphrase',
        ),
      ),
      isNotNull,
    );
    expect(
      await tester.runAsync(
        () => repository.authenticate('chosen-admin', 'wrong-password'),
      ),
      isNull,
    );
    expect(
      await tester.runAsync(() => repository.authenticate('admin', 'admin123')),
      isNull,
    );
    expect(
      await tester.runAsync(() => repository.authenticate('cashier', '123')),
      isNull,
    );
    final duplicateAdminRejected = await tester.runAsync(() async {
      try {
        await repository.createInitialAdmin(
          username: 'second-admin',
          password: 'another-chosen-password',
          fullName: 'Second Admin',
        );
        return false;
      } on StateError {
        return true;
      }
    });
    expect(duplicateAdminRejected, isTrue);
  });

  testWidgets(
    'legacy plaintext passwords upgrade after successful authentication',
    (tester) async {
      final user = await tester.runAsync(() async {
        final now = DateTime.now().toIso8601String();
        await database!.insert('users', {
          'username': 'legacy-user',
          'password': 'legacy-password',
          'fullName': 'Legacy User',
          'role': 'admin',
          'createdAt': now,
          'updatedAt': now,
        });
        return UserRepository().authenticate('legacy-user', 'legacy-password');
      });

      expect(user, isNotNull);
      expect(user!.password, isEmpty);
      final stored = (await tester.runAsync(
        () => database!.query(
          'users',
          columns: ['password'],
          where: 'username = ?',
          whereArgs: ['legacy-user'],
        ),
      ))!;
      expect(stored.single['password'], startsWith('pbkdf2-sha256\$'));
    },
  );
}

Future<int> _countUsers(Database database) async {
  final rows = await database.rawQuery('SELECT COUNT(*) AS count FROM users');
  return (rows.single['count'] as num).toInt();
}

Future<void> _pumpUntilVisible(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>();
  fail('Expected widget was not visible: $finder. Text: $visibleText');
}
