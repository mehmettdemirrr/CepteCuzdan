import 'package:cepte_cuzdan/features/budget/alert_notifier.dart';

/// Gösterilen bildirimleri kaydeden sahte bildirimci.
class FakeAlertNotifier implements AlertNotifier {
  final shown = <({int id, String title, String body})>[];

  @override
  Future<void> init() async {}

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    shown.add((id: id, title: title, body: body));
  }
}
