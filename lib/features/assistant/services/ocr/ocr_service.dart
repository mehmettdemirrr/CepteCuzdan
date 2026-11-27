import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/models/enums.dart';
import '../gemini/expense_draft_service.dart';
import '../gemini/parsed_expense_draft.dart';
import 'receipt_text_cleaner.dart';

/// Fiş görseli seçim kaynağı.
enum ReceiptImageSource { camera, gallery }

/// OCR ve fiş görseli seçim hata kodları.
enum OcrErrorCode {
  cancelled,
  permissionDenied,
  permissionPermanentlyDenied,
  cameraUnavailable,
  invalidFile,
  unreadableReceipt,
  ocrFailed,
}

/// Kullanıcıya gösterilebilir Türkçe mesaj içeren OCR hatası.
class OcrError {
  const OcrError({required this.code, required this.userMessage});

  final OcrErrorCode code;
  final String userMessage;
}

/// Fiş görseli seçimi + OCR sonucu.
sealed class OcrResult {
  const OcrResult();
}

class OcrSuccess extends OcrResult {
  const OcrSuccess({required this.cleanedText, required this.receiptPath});

  final String cleanedText;
  final String receiptPath;
}

class OcrFailure extends OcrResult {
  const OcrFailure(this.error);

  final OcrError error;
}

/// Görsel seçici katmanından fırlatılan tipli hata.
class ReceiptPickerException implements Exception {
  const ReceiptPickerException(this.code, this.userMessage);

  final OcrErrorCode code;
  final String userMessage;
}

/// Kamera/galeriden fiş fotoğrafı seçen arayüz (testlerde sahtelenir).
abstract interface class ReceiptImagePicker {
  /// Seçilen geçici görselin dosya yolunu döner; kullanıcı iptal ederse `null`.
  Future<String?> pickImage(ReceiptImageSource source);
}

/// `image_picker` ve `permission_handler` kullanan cihaz görsel seçicisi.
class DeviceReceiptImagePicker implements ReceiptImagePicker {
  DeviceReceiptImagePicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pickImage(ReceiptImageSource source) async {
    if (source == ReceiptImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isPermanentlyDenied) {
        throw const ReceiptPickerException(
          OcrErrorCode.permissionPermanentlyDenied,
          'Kamera izni kalıcı olarak reddedildi. Ayarlardan izin verebilir, galeriden seçebilir veya manuel ekleyebilirsiniz.',
        );
      }
      if (!status.isGranted) {
        throw const ReceiptPickerException(
          OcrErrorCode.permissionDenied,
          'Fiş çekmek için kamera izni gerekiyor. Galeriden seçebilir veya yazılı/manuel devam edebilirsiniz.',
        );
      }
    }

    try {
      final imageSource = source == ReceiptImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery;
      final file = await _picker.pickImage(source: imageSource);
      return file?.path;
    } on PlatformException catch (e) {
      debugPrint('DeviceReceiptImagePicker: PlatformException (${e.code})');
      if (e.code == 'camera_access_denied') {
        throw const ReceiptPickerException(
          OcrErrorCode.permissionDenied,
          'Kamera izni verilmedi. Galeriden seçebilir veya manuel ekleyebilirsiniz.',
        );
      }
      if (e.code == 'no_available_camera') {
        throw const ReceiptPickerException(
          OcrErrorCode.cameraUnavailable,
          'Bu cihazda kullanılabilir kamera bulunamadı. Galeriden fiş seçebilirsiniz.',
        );
      }
      throw const ReceiptPickerException(
        OcrErrorCode.invalidFile,
        'Fiş fotoğrafı alınamadı. Tekrar deneyebilir veya manuel ekleyebilirsiniz.',
      );
    }
  }
}

/// Fiş görsellerini uygulama klasöründe kalıcı olarak saklayan arayüz.
abstract interface class ReceiptImageStorage {
  Future<String> copyToPermanentStorage(String sourcePath);
  Future<void> deleteReceipt(String path);
  Future<void> deleteAllReceipts();

  /// [activePaths] kümesinde yer almayan sahipsiz fiş dosyalarını siler.
  Future<void> deleteOrphanReceipts(Set<String> activePaths);
}

/// Fiş görsellerini `<appDocs>/receipts/` altında saklayan yerel depo.
class LocalReceiptImageStorage implements ReceiptImageStorage {
  LocalReceiptImageStorage({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  static const _allowedExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

  final Future<Directory> Function() _documentsDirectoryProvider;
  int _counter = 0;

  Future<Directory> _receiptsDir() async {
    final docs = await _documentsDirectoryProvider();
    final dir = Directory(p.join(docs.path, 'receipts'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<String> copyToPermanentStorage(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('Kaynak fiş dosyası bulunamadı', sourcePath);
    }

    final dir = await _receiptsDir();
    final rawExt = p.extension(sourcePath).toLowerCase();
    final ext = _allowedExtensions.contains(rawExt) ? rawExt : '.jpg';
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final seq = ++_counter;
    final targetPath = p.join(dir.path, 'receipt_${stamp}_$seq$ext');
    await sourceFile.copy(targetPath);
    return targetPath;
  }

  @override
  Future<void> deleteReceipt(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> deleteAllReceipts() async {
    final docs = await _documentsDirectoryProvider();
    final dir = Directory(p.join(docs.path, 'receipts'));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  Future<void> deleteOrphanReceipts(Set<String> activePaths) async {
    final docs = await _documentsDirectoryProvider();
    final dir = Directory(p.join(docs.path, 'receipts'));
    if (!await dir.exists()) return;

    final normalizedActive = activePaths.map(p.normalize).toSet();
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (!normalizedActive.contains(p.normalize(entity.path))) {
        try {
          await entity.delete();
        } catch (e) {
          debugPrint(
            'LocalReceiptImageStorage: Yetim fiş silinemedi (${e.runtimeType})',
          );
        }
      }
    }
  }
}

/// Cihaz içi OCR motoru arayüzü (testlerde sahtelenir).
abstract interface class TextOcrEngine {
  Future<String> recognizeText(String imagePath);
}

/// Google ML Kit (Latin) kullanan cihaz içi OCR motoru.
/// Görsel buluta gönderilmez; tanıyıcı her işlem sonunda kapatılır.
class MlKitTextOcrEngine implements TextOcrEngine {
  const MlKitTextOcrEngine();

  @override
  Future<String> recognizeText(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await recognizer.processImage(inputImage);
      return recognized.text;
    } finally {
      await recognizer.close();
    }
  }
}

/// Fiş seçimi → ML Kit OCR → kalite kontrol → kalıcı kopyalama servisi.
class ReceiptScanService {
  const ReceiptScanService({
    required this.picker,
    required this.ocrEngine,
    required this.storage,
  });

  final ReceiptImagePicker picker;
  final TextOcrEngine ocrEngine;
  final ReceiptImageStorage storage;

  Future<OcrResult> pickAndExtractText(ReceiptImageSource source) async {
    final String? tempPath;
    try {
      tempPath = await picker.pickImage(source);
    } on ReceiptPickerException catch (e) {
      return OcrFailure(OcrError(code: e.code, userMessage: e.userMessage));
    } catch (e) {
      debugPrint('ReceiptScanService: Görsel seçim hatası (${e.runtimeType})');
      return const OcrFailure(
        OcrError(
          code: OcrErrorCode.invalidFile,
          userMessage:
              'Fiş fotoğrafı alınamadı. Tekrar deneyin veya manuel ekleyin.',
        ),
      );
    }

    if (tempPath == null || tempPath.trim().isEmpty) {
      return const OcrFailure(
        OcrError(
          code: OcrErrorCode.cancelled,
          userMessage: 'Fiş seçimi iptal edildi.',
        ),
      );
    }

    final String rawOcrText;
    try {
      rawOcrText = await ocrEngine.recognizeText(tempPath);
    } on FileSystemException {
      return const OcrFailure(
        OcrError(
          code: OcrErrorCode.invalidFile,
          userMessage:
              'Seçilen fiş dosyası okunamadı. Lütfen başka bir fotoğraf seçin.',
        ),
      );
    } catch (e) {
      // Ham fiş metni veya tutar asla loglanmaz.
      debugPrint('ReceiptScanService: OCR hatası (${e.runtimeType})');
      return const OcrFailure(
        OcrError(
          code: OcrErrorCode.ocrFailed,
          userMessage: 'Fiş üzerindeki metin okunamadı. Tekrar çekebilir veya galeriden seçebilirsiniz.',
        ),
      );
    }

    final cleaned = cleanReceiptText(rawOcrText);
    if (!isMeaningfulReceiptText(cleaned)) {
      return const OcrFailure(
        OcrError(
          code: OcrErrorCode.unreadableReceipt,
          userMessage: 'Fiş metni okunamadı. Fişi daha net ışıkta tekrar çekin veya galeriden seçin.',
        ),
      );
    }

    final String permanentPath;
    try {
      permanentPath = await storage.copyToPermanentStorage(tempPath);
    } catch (e) {
      debugPrint(
        'ReceiptScanService: Dosya kopyalama hatası (${e.runtimeType})',
      );
      return const OcrFailure(
        OcrError(
          code: OcrErrorCode.invalidFile,
          userMessage: 'Fiş görseli kaydedilemedi. Lütfen tekrar deneyin.',
        ),
      );
    }

    return OcrSuccess(cleanedText: cleaned, receiptPath: permanentPath);
  }
}

/// Fiş seçimi → OCR → Gemini taslağı uçtan uca hattının sonucu.
sealed class ReceiptDraftResult {
  const ReceiptDraftResult();
}

class ReceiptDraftSuccess extends ReceiptDraftResult {
  const ReceiptDraftSuccess({required this.draft, required this.receiptPath});

  final ParsedExpenseDraft draft;
  final String receiptPath;
}

class ReceiptDraftOcrFailure extends ReceiptDraftResult {
  const ReceiptDraftOcrFailure(this.error);

  final OcrError error;
}

class ReceiptDraftAiFailure extends ReceiptDraftResult {
  const ReceiptDraftAiFailure(this.error);

  final ExpenseDraftError error;
}

/// Fiş fotoğrafından (kamera/galeri) doğrulanmış gelir/gider taslağı üreten hat.
/// Görsel cihazda kalır; Gemini'ye yalnızca temizlenmiş OCR metni gider.
class ReceiptDraftPipeline {
  const ReceiptDraftPipeline({
    required this.scanService,
    required this.draftService,
  });

  final ReceiptScanService scanService;
  final ExpenseDraftService draftService;

  Future<ReceiptDraftResult> scanReceiptToDraft({
    required ReceiptImageSource source,
    required DateTime today,
    required Map<TxType, List<String>> categoriesByType,
  }) async {
    final ocrResult = await scanService.pickAndExtractText(source);
    switch (ocrResult) {
      case OcrFailure(:final error):
        return ReceiptDraftOcrFailure(error);
      case OcrSuccess(:final cleanedText, :final receiptPath):
        final draftResult = await draftService.extractDraft(
          rawText: cleanedText,
          today: today,
          categoriesByType: categoriesByType,
          source: TxSource.receipt,
        );
        switch (draftResult) {
          case ExpenseDraftSuccess(:final draft):
            return ReceiptDraftSuccess(draft: draft, receiptPath: receiptPath);
          case ExpenseDraftFailure(:final error):
            // Taslak oluşmadıysa sahipsiz fiş dosyası bırakma.
            try {
              await scanService.storage.deleteReceipt(receiptPath);
            } catch (e) {
              debugPrint(
                'ReceiptDraftPipeline: Fiş dosyası temizlenemedi (${e.runtimeType})',
              );
            }
            return ReceiptDraftAiFailure(error);
        }
    }
  }
}
