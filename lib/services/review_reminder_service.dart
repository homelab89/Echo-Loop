import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:universal_io/io.dart' as io;

import 'notification_tap_router_bridge.dart';
import 'review_reminder_time_calculator.dart';

const int kDailyReviewSummaryNotificationId = 1001;
const String _reviewChannelId = 'daily_review_summary';
const String _reviewChannelName = 'Daily Review Reminder';
const String _reviewChannelDescription =
    'Daily summary reminder for review tasks';
const String _openStudyPayload = 'open_study_tasks';

/// 单条音频复习通知的 channel
const String _perAudioChannelId = 'per_audio_review';
const String _perAudioChannelName = 'Per-Audio Review Reminder';
const String _perAudioChannelDescription =
    'Individual reminder when an audio review is due';

/// `open_audio:` payload 前缀，后跟 audioId
const String _openAudioPrefix = 'open_audio:';

/// per-audio 通知 ID 范围：[_perAudioIdMin, _perAudioIdMax]
const int _perAudioIdMin = 2000;
const int _perAudioIdRange = 900000;
const int _perAudioIdMax = _perAudioIdMin + _perAudioIdRange - 1;

/// 单条音频复习提醒所需信息
class PerAudioReminderInfo {
  final String audioId;
  final String audioName;

  /// nextReviewAt — 到期时间
  final DateTime triggerAt;

  /// 1~7，用于文案「第 X 轮复习」
  final int reviewRound;

  const PerAudioReminderInfo({
    required this.audioId,
    required this.audioName,
    required this.triggerAt,
    required this.reviewRound,
  });
}

/// 后台点击回调占位（系统可能在后台 isolate 触发）。
@pragma('vm:entry-point')
void reviewReminderBackgroundNotificationTap(NotificationResponse response) {}

/// 每日复习 + 单条音频精准复习提醒服务
class ReviewReminderService {
  ReviewReminderService({
    required FlutterLocalNotificationsPlugin plugin,
    required NotificationTapRouterBridge bridge,
    required ReviewReminderTimeCalculator timeCalculator,
  }) : _plugin = plugin,
       _bridge = bridge,
       _timeCalculator = timeCalculator;

  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationTapRouterBridge _bridge;
  final ReviewReminderTimeCalculator _timeCalculator;

  bool _initialized = false;
  bool _timezoneReady = false;

  /// 已调度的单条音频通知 ID，下次同步时先逐个 cancel
  final Set<int> _scheduledPerAudioIds = {};

  /// 快照去重：`"$audioId|$triggerAtMs"` 集合不变则跳过（null 表示首次同步）
  Set<String>? _lastSnapshot;

  bool get _supportsSystemNotification {
    if (kIsWeb) return false;
    return io.Platform.isIOS || io.Platform.isAndroid || io.Platform.isMacOS;
  }

  Future<void> init() async {
    if (_initialized) return;
    if (!_supportsSystemNotification) return;

    try {
      await _ensureTimezoneReady();

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
        onDidReceiveBackgroundNotificationResponse:
            reviewReminderBackgroundNotificationTap,
      );

      await _requestPermissions();
      _initialized = true;

      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      final payload = launchDetails?.notificationResponse?.payload;
      _handlePayload(payload);
    } on MissingPluginException {
      debugPrint('ReviewReminderService: plugin unavailable on this runtime');
    } catch (e) {
      debugPrint('ReviewReminderService.init error: $e');
    }
  }

  Future<void> syncDailyReminder({required int pendingTaskCount}) async {
    if (!_supportsSystemNotification) return;

    await init();
    if (!_initialized) return;

    if (pendingTaskCount <= 0) {
      await cancelDailyReminder();
      return;
    }

    final now = DateTime.now();
    final next = _timeCalculator.nextTriggerAt(now);
    final nextTz = tz.TZDateTime.from(next, tz.local);

    try {
      await _plugin.cancel(kDailyReviewSummaryNotificationId);
      await _plugin.zonedSchedule(
        kDailyReviewSummaryNotificationId,
        'Fluency',
        'You have $pendingTaskCount study task(s) waiting.',
        nextTz,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _reviewChannelId,
            _reviewChannelName,
            channelDescription: _reviewChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: _openStudyPayload,
      );
    } on MissingPluginException {
      debugPrint('ReviewReminderService: plugin unavailable during schedule');
    } catch (e) {
      debugPrint('ReviewReminderService.syncDailyReminder error: $e');
    }
  }

  /// 全量覆盖式调度单条音频复习通知
  ///
  /// 每次调用先 cancel 上一轮调度的所有通知 ID，再为 [reminders]
  /// 中每条信息 zonedSchedule 一个新通知。快照不变时跳过。
  Future<void> syncPerAudioReminders(
    List<PerAudioReminderInfo> reminders,
  ) async {
    if (!_supportsSystemNotification) return;

    await init();
    if (!_initialized) return;

    // 构建快照
    final newSnapshot = <String>{
      for (final r in reminders)
        '${r.audioId}|${r.triggerAt.millisecondsSinceEpoch}',
    };
    if (_lastSnapshot != null && setEquals(newSnapshot, _lastSnapshot)) return;
    _lastSnapshot = newSnapshot;

    try {
      // cancel 旧通知（含跨重启残留的 per-audio 通知）
      await _cancelStalePerAudioNotifications(reminders);

      // 调度新通知
      for (final r in reminders) {
        final nid = _perAudioNotificationId(r.audioId);
        final scheduledTz = tz.TZDateTime.from(r.triggerAt, tz.local);

        await _plugin.zonedSchedule(
          nid,
          'Fluency',
          '${r.audioName} · 第${r.reviewRound}轮复习时间到了',
          scheduledTz,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _perAudioChannelId,
              _perAudioChannelName,
              channelDescription: _perAudioChannelDescription,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
            macOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: '$_openAudioPrefix${r.audioId}',
        );
        _scheduledPerAudioIds.add(nid);
      }
    } on MissingPluginException {
      debugPrint(
        'ReviewReminderService: plugin unavailable during per-audio schedule',
      );
    } catch (e) {
      debugPrint('ReviewReminderService.syncPerAudioReminders error: $e');
    }
  }

  Future<void> cancelDailyReminder() async {
    if (!_supportsSystemNotification) return;
    try {
      await _plugin.cancel(kDailyReviewSummaryNotificationId);
    } on MissingPluginException {
      debugPrint('ReviewReminderService: plugin unavailable during cancel');
    } catch (e) {
      debugPrint('ReviewReminderService.cancelDailyReminder error: $e');
    }
  }

  /// 取消所有不在本次 [reminders] 中的 per-audio 通知
  ///
  /// 查询系统 pending 通知，过滤出 per-audio ID 范围内的，
  /// 将不在本次调度列表中的全部 cancel。解决跨重启残留问题。
  Future<void> _cancelStalePerAudioNotifications(
    List<PerAudioReminderInfo> reminders,
  ) async {
    final newIds = {for (final r in reminders) _perAudioNotificationId(r.audioId)};

    // 查询系统中所有 pending 通知
    final pending = await _plugin.pendingNotificationRequests();
    for (final n in pending) {
      if (n.id >= _perAudioIdMin && n.id <= _perAudioIdMax && !newIds.contains(n.id)) {
        await _plugin.cancel(n.id);
      }
    }

    // 同时清理内存中的旧 ID 集合
    for (final id in _scheduledPerAudioIds.toList()) {
      if (!newIds.contains(id)) {
        await _plugin.cancel(id);
      }
    }
    _scheduledPerAudioIds.clear();
  }

  Future<void> _requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    final macos = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    await macos?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _ensureTimezoneReady() async {
    if (_timezoneReady) return;
    tz_data.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (e) {
      debugPrint('ReviewReminderService: fallback timezone due to $e');
    }
    _timezoneReady = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    _handlePayload(response.payload);
  }

  /// 解析 payload 并发射对应意图
  void _handlePayload(String? payload) {
    if (payload == null) return;
    if (payload == _openStudyPayload) {
      _bridge.emit(const OpenStudyTasks());
      return;
    }
    if (payload.startsWith(_openAudioPrefix)) {
      final audioId = payload.substring(_openAudioPrefix.length);
      if (audioId.isNotEmpty) {
        _bridge.emit(OpenAudioLearningPlan(audioId));
      }
    }
  }

  /// 为 audioId 生成确定性通知 ID（FNV-1a hash，范围 2000~901999）
  static int _perAudioNotificationId(String audioId) {
    // FNV-1a 32-bit
    var hash = 0x811c9dc5;
    for (var i = 0; i < audioId.length; i++) {
      hash ^= audioId.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return _perAudioIdMin + (hash % _perAudioIdRange);
  }
}
