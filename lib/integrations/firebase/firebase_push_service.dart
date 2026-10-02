import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../core/push/push_service.dart';
import '../local_notifications/local_notification_service.dart';
import 'firebase_options.dart';

/// Runs in a separate isolate when a message arrives while the app is in the
/// background or terminated. Keep it light: no `sl`, no UI. Data-only
/// messages that need work (e.g. sync) go here.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Firebase must be initialised in this isolate too.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
}

/// [PushService] backed by Firebase Cloud Messaging.
///
/// Foreground messages that carry a `notification` block are re-displayed via
/// [LocalNotificationService] because Android shows nothing on its own while
/// the app is open. Taps on those local notifications come back through
/// [onMessageOpened] with the FCM `data` payload.
class FirebasePushService implements PushService {
  FirebasePushService({required this._local, required this._talker});

  final LocalNotificationService _local;
  final Talker _talker;

  final _onMessage = StreamController<PushMessage>.broadcast();
  final _onOpened = StreamController<PushMessage>.broadcast();
  final _onToken = StreamController<String>.broadcast();
  final _subs = <StreamSubscription<dynamic>>[];
  bool _initialized = false;

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    await _local.init();
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _subs.addAll([
      FirebaseMessaging.onMessage.listen(_handleForeground),
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => _onOpened.add(_toPush(m)),
      ),
      _fcm.onTokenRefresh.listen(_onToken.add, onError: (Object e, StackTrace st) {
        _talker.handle(e, st, 'FCM onTokenRefresh');
      }),
      // Taps on the local notifications we showed for foreground messages.
      _local.onTapped.listen((data) => _onOpened.add(PushMessage(data: data))),
    ]);

    // App opened from a terminated state by tapping an FCM notification.
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _onOpened.add(_toPush(initial));
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final settings = await _fcm.requestPermission();
      final granted = switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized || AuthorizationStatus.provisional => true,
        _ => false,
      };
      // On Android 13+ the OS prompt is owned by the notifications plugin.
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _local.requestPermission();
      }
      return granted;
    } catch (e, st) {
      _talker.handle(e, st, 'FCM requestPermission');
      return false;
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e, st) {
      _talker.handle(e, st, 'FCM getToken');
      return null;
    }
  }

  @override
  Future<void> deleteToken() async {
    try {
      await _fcm.deleteToken();
    } catch (e, st) {
      _talker.handle(e, st, 'FCM deleteToken');
    }
  }

  @override
  Stream<PushMessage> get onMessage => _onMessage.stream;

  @override
  Stream<PushMessage> get onMessageOpened => _onOpened.stream;

  @override
  Stream<String> get onTokenRefresh => _onToken.stream;

  void _handleForeground(RemoteMessage message) {
    final push = _toPush(message);
    _onMessage.add(push);

    final n = message.notification;
    if (n != null && (n.title != null || n.body != null)) {
      _local.show(
        id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
        title: n.title ?? '',
        body: n.body ?? '',
        payload: message.data,
      );
    }
  }

  PushMessage _toPush(RemoteMessage m) => PushMessage(
    title: m.notification?.title,
    body: m.notification?.body,
    data: m.data,
  );
}
