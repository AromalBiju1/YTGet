import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Completion notifications so downloads that finish while the app is in the
/// background (or on the History tab) still get picked up.
class AppNotifier {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (!Platform.isAndroid) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {
      // Missing plugin in tests / unsupported platform: notifications off.
    }
  }

  Future<void> downloadDone(String title) async {
    try {
      await _plugin.show(
        id: 1,
        title: 'Download complete',
        body: title,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'ytget_downloads',
            'Downloads',
            channelDescription: 'Tells you when a download finishes',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
      );
    } catch (_) {}
  }
}
