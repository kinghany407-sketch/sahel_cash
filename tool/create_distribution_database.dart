import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2 || arguments[0] != '--output') {
    stderr.writeln(
      'Usage: dart run tool/create_distribution_database.dart '
      '--output <new-database-path>',
    );
    exitCode = 64;
    return;
  }

  final output = File(arguments[1]).absolute;
  if (await output.exists()) {
    throw FileSystemException(
      'Refusing to overwrite an existing database',
      output.path,
    );
  }
  if (!await output.parent.exists()) {
    throw FileSystemException(
      'Output directory does not exist',
      output.parent.path,
    );
  }

  final result = await Process.run(
    'flutter',
    ['test', 'test/distribution_database_test.dart'],
    environment: {
      ...Platform.environment,
      'SAHEL_CASH_DISTRIBUTION_DB': output.path,
    },
    runInShell: true,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    throw ProcessException(
      'flutter',
      ['test', 'test/distribution_database_test.dart'],
      'Distribution database creation test failed',
      result.exitCode,
    );
  }
  if (!await output.exists()) {
    throw StateError('Distribution database creation produced no output file');
  }

  stdout.writeln('Created an empty distribution database at ${output.path}');
}
