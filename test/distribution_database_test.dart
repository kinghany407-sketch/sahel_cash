import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahel_cash/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final requestedOutputPath =
      Platform.environment['SAHEL_CASH_DISTRIBUTION_DB'];

  test('creates a version 25 database without test business data', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sahel-cash-distribution-',
    );
    final path = '${directory.path}${Platform.pathSeparator}distribution.db';
    Database? database;

    try {
      await DatabaseHelper.createEmptyDistributionDatabase(path);
      database = await databaseFactoryFfi.openDatabase(path);

      expect(
        (await database.rawQuery('PRAGMA user_version')).single['user_version'],
        25,
      );
      for (final table in [
        'products',
        'product_sale_units',
        'invoices',
        'invoice_items',
        'customers',
        'receipt_vouchers',
        'suppliers',
        'purchase_invoices',
        'purchase_invoice_items',
        'expenses',
        'customer_account_transactions',
        'inventory_movements',
      ]) {
        expect(
          await _countRows(database, table),
          0,
          reason: '$table should not include copied test data',
        );
      }
      expect(await _countRows(database, 'units'), greaterThan(0));
      expect(await _countRows(database, 'users'), 0);
      expect(await database.rawQuery('PRAGMA integrity_check'), [
        {'integrity_check': 'ok'},
      ]);
      expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);

      final existingDatabase = await File(path).readAsBytes();
      await expectLater(
        DatabaseHelper.createEmptyDistributionDatabase(path),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File(path).readAsBytes(), existingDatabase);

      final concurrentPath =
          '${directory.path}${Platform.pathSeparator}concurrent.db';
      final attempts = await Future.wait([
        _tryCreateDatabase(concurrentPath),
        _tryCreateDatabase(concurrentPath),
      ]);
      expect(attempts.where((created) => created), hasLength(1));
      expect(attempts.where((created) => !created), hasLength(1));
      final concurrentDatabase = await databaseFactoryFfi.openDatabase(
        concurrentPath,
      );
      expect(
        (await concurrentDatabase.rawQuery(
          'PRAGMA user_version',
        )).single['user_version'],
        25,
      );
      expect(await concurrentDatabase.rawQuery('PRAGMA integrity_check'), [
        {'integrity_check': 'ok'},
      ]);
      await concurrentDatabase.close();
    } finally {
      if (database?.isOpen ?? false) await database!.close();
      await directory.delete(recursive: true);
    }
  });

  test(
    'creates the explicitly requested distribution database',
    () async {
      await DatabaseHelper.createEmptyDistributionDatabase(
        requestedOutputPath!,
      );
    },
    skip: requestedOutputPath == null || requestedOutputPath.isEmpty
        ? 'Set SAHEL_CASH_DISTRIBUTION_DB to a new output path'
        : false,
  );
}

Future<bool> _tryCreateDatabase(String path) async {
  try {
    await DatabaseHelper.createEmptyDistributionDatabase(path);
    return true;
  } on FileSystemException {
    return false;
  }
}

Future<int> _countRows(Database database, String table) async {
  final rows = await database.rawQuery('SELECT COUNT(*) AS count FROM $table');
  return (rows.single['count'] as num).toInt();
}
