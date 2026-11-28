import 'dart:io';

import 'package:cepte_cuzdan/features/assistant/services/ocr/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempRoot;
  late Directory appDocsDir;
  late LocalReceiptImageStorage storage;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('cepte_cuzdan_ocr_test_');
    appDocsDir = Directory('${tempRoot.path}${Platform.pathSeparator}docs')
      ..createSync();
    storage = LocalReceiptImageStorage(
      documentsDirectoryProvider: () async => appDocsDir,
    );
  });

  tearDown(() {
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  test('geçici görseli kalıcı receipts klasörüne kopyalar ve siler', () async {
    final sourceFile = File(
      '${tempRoot.path}${Platform.pathSeparator}temp_fis.jpg',
    )..writeAsBytesSync([1, 2, 3, 4]);

    final savedPath = await storage.copyToPermanentStorage(sourceFile.path);
    final savedFile = File(savedPath);

    expect(savedFile.existsSync(), isTrue);
    expect(savedPath, contains('receipts'));
    expect(savedPath.endsWith('.jpg'), isTrue);
    expect(savedFile.readAsBytesSync(), [1, 2, 3, 4]);

    await storage.deleteReceipt(savedPath);
    expect(savedFile.existsSync(), isFalse);
  });

  test('deleteAllReceipts tüm kayıtlı fiş görsellerini temizler', () async {
    final source1 = File('${tempRoot.path}${Platform.pathSeparator}f1.png')
      ..writeAsBytesSync([10]);
    final source2 = File('${tempRoot.path}${Platform.pathSeparator}f2.png')
      ..writeAsBytesSync([20]);

    final p1 = await storage.copyToPermanentStorage(source1.path);
    final p2 = await storage.copyToPermanentStorage(source2.path);

    expect(File(p1).existsSync(), isTrue);
    expect(File(p2).existsSync(), isTrue);

    await storage.deleteAllReceipts();

    expect(File(p1).existsSync(), isFalse);
    expect(File(p2).existsSync(), isFalse);
  });

  test('olmayan kaynak dosyada FileSystemException fırlatır', () async {
    expect(
      () => storage.copyToPermanentStorage(
        '${tempRoot.path}${Platform.pathSeparator}yok.jpg',
      ),
      throwsA(isA<FileSystemException>()),
    );
  });
}
