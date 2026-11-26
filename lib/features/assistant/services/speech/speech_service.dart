import 'package:flutter/foundation.dart' show debugPrint;
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Sesli komut hata kodları.
enum SpeechErrorCode {
  permissionDenied,
  permissionPermanentlyDenied,
  serviceUnavailable,
  localeUnsupported,
  emptyResult,
  timeout,
  recognitionFailed,
}

/// Kullanıcıya gösterilebilir Türkçe ses tanıma hatası.
class SpeechError {
  const SpeechError({required this.code, required this.userMessage});

  final SpeechErrorCode code;
  final String userMessage;
}

/// Türkçe sesli komut servisi arayüzü (testlerde sahtelenir).
abstract interface class SpeechService {
  bool get isListening;

  /// Dinlemeyi başlatır. Başlatma başarısızsa [SpeechError] döner;
  /// başarılıysa `null` döner ve sonuçlar geri çağrılarla iletilir.
  Future<SpeechError?> startListening({
    required void Function(String partialText) onPartial,
    required void Function(String finalText) onFinal,
    required void Function(SpeechError error) onError,
  });

  Future<void> stopListening();

  Future<void> cancelListening();
}

/// `speech_to_text` (`tr_TR`) ve `permission_handler` kullanan cihaz servisi.
class DeviceSpeechService implements SpeechService {
  DeviceSpeechService({SpeechToText? speechToText})
    : _stt = speechToText ?? SpeechToText();

  final SpeechToText _stt;
  bool _initialized = false;
  bool _isListening = false;
  String? _turkishLocaleId;
  String _latestWords = '';
  bool _resultDelivered = false;

  void Function(String)? _onFinal;
  void Function(SpeechError)? _onError;

  @override
  bool get isListening => _isListening;

  @override
  Future<SpeechError?> startListening({
    required void Function(String partialText) onPartial,
    required void Function(String finalText) onFinal,
    required void Function(SpeechError error) onError,
  }) async {
    final perm = await Permission.microphone.request();
    if (perm.isPermanentlyDenied) {
      return const SpeechError(
        code: SpeechErrorCode.permissionPermanentlyDenied,
        userMessage: 'Mikrofon izni kalıcı olarak reddedildi. Ayarlardan izin verebilir, yazarak veya manuel devam edebilirsiniz.',
      );
    }
    if (!perm.isGranted) {
      return const SpeechError(
        code: SpeechErrorCode.permissionDenied,
        userMessage: 'Sesli komut için mikrofon izni gerekiyor. Yazarak veya manuel devam edebilirsiniz.',
      );
    }

    _onFinal = onFinal;
    _onError = onError;
    _latestWords = '';
    _resultDelivered = false;

    if (!_initialized) {
      try {
        _initialized = await _stt.initialize(
          onError: (err) {
            debugPrint('DeviceSpeechService: STT hatası (${err.errorMsg})');
            _handlePluginError(err.errorMsg);
          },
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') {
              _isListening = false;
            }
          },
        );
      } catch (e) {
        debugPrint('DeviceSpeechService: Başlatma hatası (${e.runtimeType})');
        _initialized = false;
      }
    }

    if (!_initialized) {
      return const SpeechError(
        code: SpeechErrorCode.serviceUnavailable,
        userMessage: 'Bu cihazda konuşma tanıma servisi kullanılamıyor. Yazarak veya manuel devam edebilirsiniz.',
      );
    }

    if (_turkishLocaleId == null) {
      try {
        final locales = await _stt.locales();
        _turkishLocaleId = _pickTurkishLocale(locales);
      } catch (e) {
        debugPrint(
          'DeviceSpeechService: Dil listesi alınamadı (${e.runtimeType})',
        );
      }
    }

    if (_turkishLocaleId == null) {
      return const SpeechError(
        code: SpeechErrorCode.localeUnsupported,
        userMessage: 'Cihazda Türkçe (tr_TR) ses tanıma desteği bulunamadı. Yazarak veya manuel devam edebilirsiniz.',
      );
    }

    try {
      _isListening = true;
      await _stt.listen(
        onResult: (result) {
          _latestWords = result.recognizedWords.trim();
          if (result.finalResult) {
            _isListening = false;
            if (_resultDelivered) return;
            _resultDelivered = true;
            if (_latestWords.isEmpty) {
              _onError?.call(
                const SpeechError(
                  code: SpeechErrorCode.emptyResult,
                  userMessage: 'Ses algılanamadı. Tekrar deneyebilir veya yazarak devam edebilirsiniz.',
                ),
              );
            } else {
              _onFinal?.call(_latestWords);
            }
          } else if (_latestWords.isNotEmpty) {
            onPartial(_latestWords);
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: _turkishLocaleId,
          partialResults: true,
          cancelOnError: true,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
          listenMode: ListenMode.confirmation,
        ),
      );
      return null;
    } catch (e) {
      _isListening = false;
      debugPrint('DeviceSpeechService: Dinleme hatası (${e.runtimeType})');
      return const SpeechError(
        code: SpeechErrorCode.recognitionFailed,
        userMessage: 'Sesli komut başlatılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin veya yazın.',
      );
    }
  }

  String? _pickTurkishLocale(List<LocaleName> locales) {
    for (final l in locales) {
      final norm = l.localeId.toLowerCase().replaceAll('-', '_');
      if (norm == 'tr_tr') return l.localeId;
    }
    for (final l in locales) {
      final norm = l.localeId.toLowerCase().replaceAll('-', '_');
      if (norm.startsWith('tr')) return l.localeId;
    }
    return null;
  }

  void _handlePluginError(String errorMsg) {
    _isListening = false;
    if (_resultDelivered) return;
    _resultDelivered = true;

    final lower = errorMsg.toLowerCase();
    if (lower.contains('timeout') || lower.contains('no_match')) {
      _onError?.call(
        const SpeechError(
          code: SpeechErrorCode.timeout,
          userMessage: 'Konuşma algılanamadı veya zaman aşımına uğradı. Tekrar deneyin veya yazın.',
        ),
      );
      return;
    }
    if (lower.contains('network')) {
      _onError?.call(
        const SpeechError(
          code: SpeechErrorCode.recognitionFailed,
          userMessage: 'Ses tanıma için internet bağlantısı gerekiyor. Bağlantınızı kontrol edin veya manuel ekleyin.',
        ),
      );
      return;
    }
    _onError?.call(
      const SpeechError(
        code: SpeechErrorCode.recognitionFailed,
        userMessage: 'Ses tanıma tamamlanamadı. Tekrar deneyebilir veya yazarak devam edebilirsiniz.',
      ),
    );
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
    try {
      await _stt.stop();
    } catch (e) {
      debugPrint('DeviceSpeechService: Durdurma hatası (${e.runtimeType})');
    }
    if (!_resultDelivered && _latestWords.isNotEmpty) {
      _resultDelivered = true;
      _onFinal?.call(_latestWords);
    }
  }

  @override
  Future<void> cancelListening() async {
    _isListening = false;
    _resultDelivered = true;
    _latestWords = '';
    try {
      await _stt.cancel();
    } catch (e) {
      debugPrint('DeviceSpeechService: İptal hatası (${e.runtimeType})');
    }
  }
}
