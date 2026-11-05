import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sahel_cash/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late String livePath;
  late Database database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sahel-backup-restore-');
    livePath = '${directory.path}${Platform.pathSeparator}live-test.db';
    await DatabaseHelper.createEmptyDistributionDatabase(livePath);
    database = await databaseFactoryFfi.openDatabase(
      livePath,
      options: OpenDatabaseOptions(
        onConfigure: (db) async {
          await db.execute('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA wal_autocheckpoint = 0');
        },
      ),
    );
    await database.execute(
      'CREATE TABLE maintenance_probe (value TEXT NOT NULL)',
    );
    await database.insert('maintenance_probe', {'value': 'original'});
    DatabaseHelper.setDatabaseForTesting(database);
    DatabaseHelper.setDatabasePathForTesting(livePath);
    expect(
      await DatabaseHelper.instance.getDatabasePath(),
      isNot(r'C:\Users\IP\Documents\sahel_cash.db'),
    );
  });

  tearDown(() async {
    DatabaseHelper.beforeRestoreReplaceForTesting = null;
    DatabaseHelper.afterRestoreReplaceForTesting = null;
    DatabaseHelper.setDatabaseForTesting(null);
    DatabaseHelper.setDatabasePathForTesting(null);
    if (database.isOpen) await database.close();
    await directory.delete(recursive: true);
  });

  test('backup uses a consistent SQLite snapshot with WAL data', () async {
    final walFile = File('$livePath-wal');
    expect(await walFile.exists(), isTrue);
    expect(await walFile.length(), greaterThan(0));

    final backupPath = '${directory.path}${Platform.pathSeparator}backup.db';
    final result = await DatabaseHelper.instance.backupDatabase(
      destinationPath: backupPath,
    );

    expect(result, backupPath);
    expect(await File(backupPath).exists(), isTrue);
    expect(await File('$backupPath-wal').exists(), isFalse);
    final backup = await databaseFactoryFfi.openDatabase(
      backupPath,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    expect(await _probeValues(backup), ['original']);
    expect(await backup.rawQuery('PRAGMA integrity_check'), [
      {'integrity_check': 'ok'},
    ]);
    expect(
      (await backup.rawQuery('PRAGMA user_version')).single['user_version'],
      DatabaseHelper.currentDatabaseVersion,
    );
    await backup.close();
  });

  test('backup refuses to overwrite an existing destination', () async {
    final destinationPath =
        '${directory.path}${Platform.pathSeparator}existing-backup.db';
    await File(destinationPath).writeAsString('keep this file');

    await expectLater(
      DatabaseHelper.instance.backupDatabase(destinationPath: destinationPath),
      throwsA(isA<FileSystemException>()),
    );
    expect(await File(destinationPath).readAsString(), 'keep this file');
  });

  test('restore validates first and preserves a safety snapshot', () async {
    final restorePath = await _createReplacementDatabase(
      directory,
      'replacement',
    );

    final safetyPath = await DatabaseHelper.instance.restoreDatabase(
      restorePath,
    );

    final restored = await databaseFactoryFfi.openDatabase(
      livePath,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    expect(await _probeValues(restored), ['replacement']);
    await restored.close();
    expect(await File('$livePath-wal').exists(), isFalse);

    final safety = await databaseFactoryFfi.openDatabase(
      safetyPath,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    expect(await _probeValues(safety), ['original']);
    await safety.close();
  });

  test(
    'corrupt and incompatible backups never replace the live database',
    () async {
      final corruptPath =
          '${directory.path}${Platform.pathSeparator}corrupt.db';
      await File(corruptPath).writeAsString('not a SQLite database');
      await expectLater(
        DatabaseHelper.instance.restoreDatabase(corruptPath),
        throwsA(anything),
      );
      expect(await _probeValues(database), ['original']);

      final incompatiblePath =
          '${directory.path}${Platform.pathSeparator}version-24.db';
      final incompatible = await databaseFactoryFfi.openDatabase(
        incompatiblePath,
        options: OpenDatabaseOptions(
          version: 24,
          onCreate: (db, version) async {
            await db.execute('CREATE TABLE unsupported (id INTEGER)');
          },
          singleInstance: false,
        ),
      );
      await incompatible.close();

      await expectLater(
        DatabaseHelper.instance.restoreDatabase(incompatiblePath),
        throwsA(isA<FormatException>()),
      );
      expect(await _probeValues(database), ['original']);
    },
  );

  test(
    'interruption before atomic replacement leaves the live database intact',
    () async {
      final restorePath = await _createReplacementDatabase(
        directory,
        'replacement',
      );
      DatabaseHelper.beforeRestoreReplaceForTesting = () async {
        throw StateError('simulated interruption');
      };

      await expectLater(
        DatabaseHelper.instance.restoreDatabase(restorePath),
        throwsA(isA<StateError>()),
      );

      final unchanged = await databaseFactoryFfi.openDatabase(
        livePath,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      expect(await _probeValues(unchanged), ['original']);
      await unchanged.close();
      expect(
        Directory(directory.path)
            .listSync()
            .whereType<File>()
            .where((file) => file.path.contains('before-restore'))
            .length,
        1,
      );
    },
  );

  test(
    'failure after replacement rolls back from the safety snapshot',
    () async {
      final restorePath = await _createReplacementDatabase(
        directory,
        'replacement',
      );
      DatabaseHelper.afterRestoreReplaceForTesting = () async {
        throw StateError('simulated post-replacement failure');
      };

      await expectLater(
        DatabaseHelper.instance.restoreDatabase(restorePath),
        throwsA(isA<StateError>()),
      );

      final unchanged = await databaseFactoryFfi.openDatabase(
        livePath,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      expect(await _probeValues(unchanged), ['original']);
      await unchanged.close();
    },
  );

  test(
    'restore waits for an active write transaction before replacement',
    () async {
      final restorePath = await _createReplacementDatabase(
        directory,
        'replacement',
      );
      final writeStarted = Completer<void>();
      final releaseWrite = Completer<void>();
      final activeWrite = database.transaction<void>((transaction) async {
        await transaction.insert('maintenance_probe', {
          'value': 'committed-before-restore',
        });
        writeStarted.complete();
        await releaseWrite.future;
      }, exclusive: true);
      await writeStarted.future;

      var restoreCompleted = false;
      String? safetyPath;
      final restore = DatabaseHelper.instance.restoreDatabase(restorePath).then(
        (path) {
          safetyPath = path;
          restoreCompleted = true;
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(restoreCompleted, isFalse);

      releaseWrite.complete();
      await activeWrite;
      await restore;
      expect(restoreCompleted, isTrue);

      final safety = await databaseFactoryFfi.openDatabase(
        safetyPath!,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      expect(await _probeValues(safety), [
        'original',
        'committed-before-restore',
      ]);
      await safety.close();
    },
  );
}

Future<String> _createReplacementDatabase(
  Directory directory,
  String value,
) async {
  final path =
      '${directory.path}${Platform.pathSeparator}replacement-${value.hashCode}.db';
  await DatabaseHelper.createEmptyDistributionDatabase(path);
  final database = await databaseFactoryFfi.openDatabase(path);
  await database.execute(
    'CREATE TABLE maintenance_probe (value TEXT NOT NULL)',
  );
  await database.insert('maintenance_probe', {'value': value});
  await database.close();
  return path;
}

Future<List<String>> _probeValues(Database database) async {
  final rows = await database.query(
    'maintenance_probe',
    columns: ['value'],
    orderBy: 'rowid',
  );
  return rows.map((row) => row['value'] as String).toList();
}
