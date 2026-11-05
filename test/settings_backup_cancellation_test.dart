import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahel_cash/screens/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FilePicker.platform = _CancelFilePicker();
  });

  testWidgets('cancelling local backup reports cancellation', (tester) async {
    await _openBackupSettings(tester);

    await tester.tap(find.text('نسخ احتياطي الآن'));
    await tester.pumpAndSettle();

    expect(find.text('تم إلغاء النسخ الاحتياطي'), findsOneWidget);
  });

  testWidgets('cancelling local restore reports cancellation', (tester) async {
    await _openBackupSettings(tester);

    await tester.tap(find.text('استعادة نسخة احتياطية'));
    await tester.pumpAndSettle();

    expect(find.text('تم إلغاء اختيار النسخة الاحتياطية'), findsOneWidget);
  });

  testWidgets('declining restore confirmation leaves the database untouched', (
    tester,
  ) async {
    FilePicker.platform = _CancelFilePicker(selectedPath: 'unused-backup.db');
    await _openBackupSettings(tester);

    await tester.tap(find.text('استعادة نسخة احتياطية'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
    await tester.pumpAndSettle();

    expect(find.text('تم إلغاء الاستعادة'), findsOneWidget);
  });
}

Future<void> _openBackupSettings(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('النسخ الاحتياطي واستعادة البيانات'));
  await tester.pumpAndSettle();
}

class _CancelFilePicker extends FilePicker {
  _CancelFilePicker({this.selectedPath});

  final String? selectedPath;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => selectedPath == null
      ? null
      : FilePickerResult([
          PlatformFile(name: selectedPath!, path: selectedPath, size: 0),
        ]);

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async => null;
}
