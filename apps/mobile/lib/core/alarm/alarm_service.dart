import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

/// Plays the loud, looping anchor-drift alarm: a bundled sound (kept playing in
/// the background via the `audio` background mode), sustained vibration, and a
/// high-importance local notification (full-screen intent on Android) so the
/// alert surfaces even when the phone is locked.
///
/// Every method degrades gracefully and never throws — a missing audio asset or
/// an unsupported vibrator must not take the anchor watch down. NOTE: this is
/// intentionally NOT an iOS Critical Alert (which would sound through
/// silent/Do-Not-Disturb) — that needs a special Apple entitlement and is
/// deferred to a later version.
class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  static const _channelId = 'anchor-alarm';
  static const _notificationId = 42001;
  static const _assetPath = 'sounds/anchor_alarm.wav';

  final AudioPlayer _player = AudioPlayer();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _playing = false;

  /// One-time setup: notification channel + audio context. Safe to call
  /// unconditionally at startup; never throws.
  Future<void> init() async {
    if (_initialized) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _notifications.initialize(
        const InitializationSettings(
          android: androidInit,
          iOS: darwinInit,
        ),
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              'Anchor alarm',
              description: 'Loud alert when the boat drifts off anchor',
              importance: Importance.max,
            ),
          );

      // Keep the alarm audible while backgrounded/locked, and duck (don't
      // silence) other audio rather than requiring exclusive focus.
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
          android: const AudioContextAndroid(
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
      await _player.setReleaseMode(ReleaseMode.loop);
      _initialized = true;
    } catch (e) {
      debugPrint('alarm: init failed: $e');
    }
  }

  /// Requests the OS notification permission (best-effort). Called before the
  /// first arm so the drift notification can actually show.
  Future<void> requestPermission() async {
    try {
      if (Platform.isAndroid) {
        await _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        await _notifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, sound: true, badge: true);
      }
    } catch (e) {
      debugPrint('alarm: requestPermission failed: $e');
    }
  }

  /// Starts the alarm: looping sound + repeating vibration + a sticky
  /// high-importance notification. Idempotent while already firing.
  Future<void> trigger({required String title, required String body}) async {
    if (_playing) return;
    _playing = true;
    await init();

    try {
      await _player.stop();
      await _player.play(AssetSource(_assetPath), volume: 1);
    } catch (e) {
      debugPrint('alarm: audio failed: $e');
    }

    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(
          pattern: const [0, 600, 300, 600, 300, 600],
          repeat: 1,
        );
      }
    } catch (e) {
      debugPrint('alarm: vibration failed: $e');
    }

    try {
      await _notifications.show(
        _notificationId,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Anchor alarm',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            ongoing: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
      );
    } catch (e) {
      debugPrint('alarm: notification failed: $e');
    }
  }

  /// Stops the alarm and clears its notification.
  Future<void> stop() async {
    _playing = false;
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await Vibration.cancel();
    } catch (_) {}
    try {
      await _notifications.cancel(_notificationId);
    } catch (_) {}
  }

  bool get isPlaying => _playing;
}

final alarmServiceProvider = Provider<AlarmService>(
  (ref) => AlarmService.instance,
);
