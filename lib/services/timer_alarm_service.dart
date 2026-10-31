import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../theme/app_theme.dart';

/// Global navigator so alarm UI can appear after a background notification tap.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Looping alarm + vibration until the user taps 「关闭」.
/// Also schedules a high-importance local notification so lock-screen / background
/// still gets a prompt within normal Android limits (exact alarm when allowed).
class TimerAlarmService {
  TimerAlarmService._();
  static final TimerAlarmService instance = TimerAlarmService._();

  static const _notifId = 73001;
  static const _channelId = 'howto_cook_timer_alarm';
  static const _payload = 'timer_alarm';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _player = AudioPlayer();

  bool _initialized = false;
  bool _ringing = false;
  bool _dialogVisible = false;
  Timer? _vibrateTimer;
  String _message = '计时结束';

  bool get isRinging => _ringing;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    } catch (_) {
      // Keep default; schedule still uses device wall clock via TZDateTime.from.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        '步骤计时提醒',
        description: '做饭步骤计时结束时的响铃提醒',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('timer_alarm'),
      ),
    );
    await android?.requestNotificationsPermission();
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {
      // Older Android / OEM without the API.
    }

    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(1);
    try {
      await _player.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.duckOthers},
          ),
        ),
      );
    } catch (_) {
      // Audio context is best-effort.
    }

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true &&
        launch?.notificationResponse?.payload == _payload) {
      // Defer until first frame so navigator exists.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(ringUntilDismissed(message: '⏰ 计时结束！请关闭铃声'));
      });
    }

    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    if (response.payload == _payload) {
      unawaited(ringUntilDismissed(message: '⏰ 计时结束！请关闭铃声'));
    }
  }

  /// Call when a countdown starts so background/lock screen still gets a ping.
  Future<void> scheduleEndNotification(
    Duration duration, {
    required String body,
  }) async {
    await init();
    await cancelScheduled();
    if (duration.inSeconds < 1) return;

    final when = tz.TZDateTime.now(tz.local).add(duration);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        '步骤计时提醒',
        channelDescription: '做饭步骤计时结束时的响铃提醒',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        sound: const RawResourceAndroidNotificationSound('timer_alarm'),
        visibility: NotificationVisibility.public,
        ticker: body,
      ),
    );

    try {
      await WakelockPlus.enable();
    } catch (_) {}

    try {
      await _plugin.zonedSchedule(
        id: _notifId,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: '程序员做饭指南',
        body: body,
        payload: _payload,
      );
    } catch (_) {
      // Exact alarm may be denied — inexact fallback.
      try {
        await _plugin.zonedSchedule(
          id: _notifId,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: '程序员做饭指南',
          body: body,
          payload: _payload,
        );
      } catch (_) {}
    }
  }

  Future<void> cancelScheduled() async {
    try {
      await _plugin.cancel(id: _notifId);
    } catch (_) {}
  }

  /// Start looping sound + vibration and show a blocking 「关闭」 dialog.
  Future<void> ringUntilDismissed({String message = '⏰ 计时结束！'}) async {
    await init();
    _message = message;
    if (!_ringing) {
      _ringing = true;
      try {
        await WakelockPlus.enable();
      } catch (_) {}
      try {
        await _player.stop();
        await _player.play(AssetSource('sounds/timer_alarm.wav'));
      } catch (_) {
        // Still vibrate + dialog if audio fails.
      }
      _vibrateTimer?.cancel();
      _vibrateTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      });
      HapticFeedback.heavyImpact();
    }
    await cancelScheduled();
    await _showDialogIfNeeded();
  }

  Future<void> _showDialogIfNeeded() async {
    if (_dialogVisible) return;
    final nav = appNavigatorKey.currentState;
    final ctx = nav?.overlay?.context ?? appNavigatorKey.currentContext;
    if (ctx == null) {
      // Retry shortly — app may still be launching from notification.
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (_ringing) unawaited(_showDialogIfNeeded());
      });
      return;
    }
    _dialogVisible = true;
    try {
      await showDialog<void>(
        context: ctx,
        barrierDismissible: false,
        builder: (dialogCtx) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text(
                '计时结束',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: Text(
                '$_message\n\n铃声与震动会持续提醒，点「关闭」后才会停止。',
                style: const TextStyle(height: 1.45),
              ),
              actions: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.coral,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('关闭铃声'),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      _dialogVisible = false;
      await stop();
    }
  }

  Future<void> stop() async {
    _ringing = false;
    _vibrateTimer?.cancel();
    _vibrateTimer = null;
    try {
      await _player.stop();
    } catch (_) {}
    await cancelScheduled();
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}
