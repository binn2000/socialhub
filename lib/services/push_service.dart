import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// What a push carries: the `data` the server sent (type, postId, ...).
class PushMessage {
  final Map<String, String> data;

  const PushMessage(this.data);
}

/// Push notifications. The app only talks to this interface, so tests and the
/// offline mock use [NoPushService].
abstract class PushService {
  /// Asks for permission and returns this phone's token, or null when push is
  /// unavailable (permission refused, no Firebase config, simulator).
  Future<String?> start();

  /// The token after [start] succeeded.
  String? get token;

  /// A new token to register (the old one stopped working).
  Stream<String> get tokenRefreshed;

  /// A push that arrived while the app is open.
  Stream<PushMessage> get foreground;

  /// The user tapped a push while the app was in the background.
  Stream<PushMessage> get opened;

  /// The push that launched the app from a closed state, if any.
  Future<PushMessage?> launchMessage();

  /// Forgets the token on the phone (sign-out).
  Future<void> stop();
}

class NoPushService implements PushService {
  const NoPushService();

  @override
  Future<String?> start() async => null;

  @override
  String? get token => null;

  @override
  Stream<String> get tokenRefreshed => const Stream.empty();

  @override
  Stream<PushMessage> get foreground => const Stream.empty();

  @override
  Stream<PushMessage> get opened => const Stream.empty();

  @override
  Future<PushMessage?> launchMessage() async => null;

  @override
  Future<void> stop() async {}
}

/// Firebase Cloud Messaging. Needs google-services.json (Android) and
/// GoogleService-Info.plist (iOS) from the Firebase project; without them
/// [start] returns null and the app works without push.
class FirebasePushService implements PushService {
  String? _token;
  bool _ready = false;

  @override
  String? get token => _token;

  @override
  Future<String?> start() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
      _token = await messaging.getToken();
      _ready = _token != null;
      return _token;
    } catch (error) {
      debugPrint('Push is not available: $error');
      return null;
    }
  }

  static PushMessage _message(RemoteMessage message) => PushMessage({
    for (final entry in message.data.entries) entry.key: '${entry.value}',
  });

  @override
  Stream<String> get tokenRefreshed =>
      _ready ? FirebaseMessaging.instance.onTokenRefresh : const Stream.empty();

  @override
  Stream<PushMessage> get foreground =>
      _ready ? FirebaseMessaging.onMessage.map(_message) : const Stream.empty();

  @override
  Stream<PushMessage> get opened => _ready
      ? FirebaseMessaging.onMessageOpenedApp.map(_message)
      : const Stream.empty();

  @override
  Future<PushMessage?> launchMessage() async {
    if (!_ready) return null;
    final message = await FirebaseMessaging.instance.getInitialMessage();
    return message == null ? null : _message(message);
  }

  @override
  Future<void> stop() async {
    if (!_ready) return;
    _ready = false;
    _token = null;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // Signing out must not fail because of push.
    }
  }
}
