import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Yerel bildirim gösterme arabirimi (testlerde sahtesi kullanılır).
abstract class AlertNotifier {
  Future<void> init();
  Future<void> show({
    required int id,
    required String title,
    required String body,
  });
}

/// flutter_local_notifications ile gerçek bildirim.
class LocalAlertNotifier implements AlertNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'budget_alerts',
      'Bütçe uyarıları',
      channelDescription:
          'Bütçe limitine yaklaşınca ve aşılınca gelen uyarılar',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  /// İzin penceresini açar. İlk kare çizildikten sonra çağrılmalı.
  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, sound: true);
    // Android 13+ bildirim izni.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) => _plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: _details,
  );
}
