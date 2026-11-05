import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sahel_cash/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final sourcePath = Platform.environment['SAHEL_CASH_V22_DB'];

  test(
    'migration from the v22 backup preserves existing data and is repeat-safe',
    () async {
      final source = File(sourcePath!);
      expect(await source.exists(), isTrue);

      final directory = await Directory.systemTemp.createTemp(
        'sahel-cash-v22-migration-',
      );
      final databasePath =
          '${directory.path}${Platform.pathSeparator}migration-test.db';
      await source.copy(databasePath);

      Database? database;
      try {
        database = await databaseFactoryFfi.openDatabase(databasePath);
        expect(
          (await database.rawQuery(
            'PRAGMA user_version',
          )).single['user_version'],
          22,
        );

        final tablesToPreserve = [
          'customers',
          'receipt_vouchers',
          'invoices',
          'invoice_items',
          'purchase_invoices',
          'purchase_invoice_items',
          'expenses',
          'users',
          'products',
          'product_sale_units',
        ];
        final originalColumns = <String, List<String>>{};
        final originalRows = <String, String>{};
        for (final table in tablesToPreserve) {
          final columns = (await database.rawQuery(
            'PRAGMA table_info($table)',
          )).map((row) => row['name'] as String).toList();
          originalColumns[table] = columns;
          originalRows[table] = jsonEncode(
            await database.query(table, columns: columns, orderBy: 'id'),
          );
        }

        final originalForeignKeyViolations = await database.rawQuery(
          'PRAGMA foreign_key_check',
        );
        expect(originalForeignKeyViolations, hasLength(14));
        final originalOrphanInvoiceItems = await database.rawQuery('''
SELECT i.id, i.invoiceId, i.productId, i.productName, i.saleUnit,
  i.quantity, i.unitPrice, i.total
FROM invoice_items i
LEFT JOIN products p ON p.id = i.productId
WHERE p.id IS NULL
ORDER BY i.id
''');
        expect(originalOrphanInvoiceItems.map((row) => row['id']).toSet(), {
          54,
          59,
          81,
          82,
          83,
          84,
          85,
          86,
        });
        final originalOrphanSaleUnits = await database.rawQuery('''
SELECT u.id, u.productId, u.saleUnit, u.retailPrice, u.wholesalePrice,
  u.conversionToStorage
FROM product_sale_units u
LEFT JOIN products p ON p.id = u.productId
WHERE p.id IS NULL
ORDER BY u.id
''');
        expect(originalOrphanSaleUnits.map((row) => row['id']).toSet(), {
          25,
          26,
          113,
          114,
          115,
          116,
        });

        final customers = await database.query(
          'customers',
          columns: ['id', 'currentBalance'],
          orderBy: 'id',
        );
        final nonZeroCustomerCount = customers.where((customer) {
          final balance = (customer['currentBalance'] as num?)?.toDouble() ?? 0;
          return balance.abs() > 0.0000001;
        }).length;
        final originalReceiptCount = await _countRows(
          database,
          'receipt_vouchers',
        );
        final originalProductQuantities = await database.query(
          'products',
          columns: ['id', 'quantity'],
          orderBy: 'id',
        );

        await database.close();
        database = await databaseFactoryFfi.openDatabase(
          databasePath,
          options: OpenDatabaseOptions(
            version: 25,
            onUpgrade: DatabaseHelper.instance.onUpgradeForTesting,
          ),
        );

        expect(
          (await database.rawQuery(
            'PRAGMA user_version',
          )).single['user_version'],
          25,
        );
        expect(await database.rawQuery('PRAGMA integrity_check'), [
          {'integrity_check': 'ok'},
        ]);
        expect(
          await database.rawQuery('PRAGMA foreign_key_check'),
          originalForeignKeyViolations,
        );
        expect(
          await database.rawQuery('''
SELECT i.id, i.invoiceId, i.productId, i.productName, i.saleUnit,
  i.quantity, i.unitPrice, i.total
FROM invoice_items i
LEFT JOIN products p ON p.id = i.productId
WHERE p.id IS NULL
ORDER BY i.id
'''),
          originalOrphanInvoiceItems,
        );
        expect(
          await database.rawQuery('''
SELECT u.id, u.productId, u.saleUnit, u.retailPrice, u.wholesalePrice,
  u.conversionToStorage
FROM product_sale_units u
LEFT JOIN products p ON p.id = u.productId
WHERE p.id IS NULL
ORDER BY u.id
'''),
          originalOrphanSaleUnits,
        );

        for (final table in tablesToPreserve) {
          expect(
            jsonEncode(
              await database.query(
                table,
                columns: originalColumns[table],
                orderBy: 'id',
              ),
            ),
            originalRows[table],
            reason: '$table rows changed during migration',
          );
        }

        final openingTransactions = await database.query(
          'customer_account_transactions',
          where: 'sourceType = ?',
          whereArgs: ['legacy_opening_balance'],
          orderBy: 'customerId',
        );
        expect(openingTransactions, hasLength(nonZeroCustomerCount));
        expect(
          openingTransactions.map((row) => row['idempotencyKey']).toSet(),
          hasLength(nonZeroCustomerCount),
        );
        for (final customer in customers) {
          final customerId = customer['id'] as int;
          final balance = (customer['currentBalance'] as num?)?.toDouble() ?? 0;
          final rows = await database.query(
            'customer_account_transactions',
            where: 'customerId = ?',
            whereArgs: [customerId],
          );
          final ledgerBalance = rows.fold<double>(
            0,
            (sum, row) => sum + (row['amount'] as num).toDouble(),
          );
          expect(ledgerBalance, closeTo(balance, 0.0000001));
        }
        expect(
          await database.query(
            'customer_account_transactions',
            where: 'sourceType = ?',
            whereArgs: ['receipt_voucher'],
          ),
          isEmpty,
        );
        expect(
          await _countRows(database, 'receipt_vouchers'),
          originalReceiptCount,
        );
        expect(
          await database.query(
            'products',
            columns: ['id', 'quantity'],
            orderBy: 'id',
          ),
          originalProductQuantities,
        );
        expect(await _countRows(database, 'inventory_movements'), 0);

        final openingCountAfterUpgrade = await _countRows(
          database,
          'customer_account_transactions',
        );
        await DatabaseHelper.migrateCustomerAccountLedger(database);
        expect(
          await _countRows(database, 'customer_account_transactions'),
          openingCountAfterUpgrade,
        );

        await database.close();
        database = await databaseFactoryFfi.openDatabase(
          databasePath,
          options: OpenDatabaseOptions(
            version: 25,
            onUpgrade: DatabaseHelper.instance.onUpgradeForTesting,
          ),
        );
        expect(
          (await database.rawQuery(
            'PRAGMA user_version',
          )).single['user_version'],
          25,
        );
        expect(
          await _countRows(database, 'customer_account_transactions'),
          openingCountAfterUpgrade,
        );
        expect(await database.rawQuery('PRAGMA integrity_check'), [
          {'integrity_check': 'ok'},
        ]);
        expect(
          await database.rawQuery('PRAGMA foreign_key_check'),
          originalForeignKeyViolations,
        );
      } finally {
        if (database?.isOpen ?? false) await database!.close();
        await directory.delete(recursive: true);
      }
    },
    skip: sourcePath == null || sourcePath.isEmpty
        ? 'Set SAHEL_CASH_V22_DB to an isolated v22 backup database'
        : false,
  );
}

Future<int> _countRows(Database database, String table) async {
  final rows = await database.rawQuery('SELECT COUNT(*) AS count FROM $table');
  return (rows.single['count'] as num).toInt();
}
