import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:fluency/services/notification_tap_router_bridge.dart';
import 'package:fluency/services/review_reminder_service.dart';
import 'package:fluency/services/review_reminder_time_calculator.dart';

// --- Mocks ---

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

class MockReviewReminderTimeCalculator extends Mock
    implements ReviewReminderTimeCalculator {}

class FakeInitializationSettings extends Fake
    implements InitializationSettings {}

class FakeNotificationDetails extends Fake implements NotificationDetails {}

class FakeTZDateTime extends Fake implements tz.TZDateTime {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
    registerFallbackValue(FakeInitializationSettings());
    registerFallbackValue(FakeNotificationDetails());
    registerFallbackValue(FakeTZDateTime());
    registerFallbackValue(AndroidScheduleMode.exactAllowWhileIdle);
    registerFallbackValue(DateTimeComponents.time);
  });

  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late NotificationTapRouterBridge bridge;
  late MockReviewReminderTimeCalculator mockTimeCalc;

  /// 创建 service 并 stub plugin（含指定的 launch payload）
  ReviewReminderService createService({String? launchPayload}) {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    bridge = NotificationTapRouterBridge();
    mockTimeCalc = MockReviewReminderTimeCalculator();

    // Stub init / permissions
    when(
      () => mockPlugin.initialize(
        any(),
        onDidReceiveNotificationResponse:
            any(named: 'onDidReceiveNotificationResponse'),
        onDidReceiveBackgroundNotificationResponse:
            any(named: 'onDidReceiveBackgroundNotificationResponse'),
      ),
    ).thenAnswer((_) async => true);

    // Stub launch details
    when(() => mockPlugin.getNotificationAppLaunchDetails()).thenAnswer(
      (_) async => launchPayload != null
          ? NotificationAppLaunchDetails(
              true,
              notificationResponse: NotificationResponse(
                notificationResponseType:
                    NotificationResponseType.selectedNotification,
                payload: launchPayload,
              ),
            )
          : null,
    );

    when(() => mockPlugin.cancel(any())).thenAnswer((_) async {});
    when(() => mockPlugin.pendingNotificationRequests())
        .thenAnswer((_) async => <PendingNotificationRequest>[]);
    when(
      () => mockPlugin.zonedSchedule(
        any(),
        any(),
        any(),
        any(),
        any(),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => mockPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>(),
    ).thenReturn(null);
    when(
      () => mockPlugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>(),
    ).thenReturn(null);
    when(
      () => mockPlugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>(),
    ).thenReturn(null);

    // Stub FlutterTimezone
    const channel = MethodChannel('flutter_timezone');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getLocalTimezone') return 'America/New_York';
      return null;
    });

    return ReviewReminderService(
      plugin: mockPlugin,
      bridge: bridge,
      timeCalculator: mockTimeCalc,
    );
  }

  group('syncPerAudioReminders', () {
    test('调度通知数量等于传入 reminders 数', () async {
      final service = createService();
      final reminders = [
        PerAudioReminderInfo(
          audioId: 'audio-1',
          audioName: 'Test Audio 1',
          triggerAt: DateTime.now().add(const Duration(hours: 6)),
          reviewRound: 1,
        ),
        PerAudioReminderInfo(
          audioId: 'audio-2',
          audioName: 'Test Audio 2',
          triggerAt: DateTime.now().add(const Duration(days: 1)),
          reviewRound: 2,
        ),
      ];

      await service.syncPerAudioReminders(reminders);

      verify(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      ).called(2);
    });

    test('快照不变时跳过调度', () async {
      final service = createService();
      final triggerAt = DateTime.now().add(const Duration(hours: 6));
      final reminders = [
        PerAudioReminderInfo(
          audioId: 'audio-1',
          audioName: 'Test Audio 1',
          triggerAt: triggerAt,
          reviewRound: 1,
        ),
      ];

      await service.syncPerAudioReminders(reminders);
      clearInteractions(mockPlugin);

      // 重新 stub（clearInteractions 清除 stub）
      when(() => mockPlugin.cancel(any())).thenAnswer((_) async {});
    when(() => mockPlugin.pendingNotificationRequests())
        .thenAnswer((_) async => <PendingNotificationRequest>[]);
      when(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});

      // 相同 reminders 再次同步
      await service.syncPerAudioReminders(reminders);

      verifyNever(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      );
    });

    test('快照变化时先 cancel 旧通知再调度新通知', () async {
      final service = createService();

      await service.syncPerAudioReminders([
        PerAudioReminderInfo(
          audioId: 'audio-1',
          audioName: 'Test 1',
          triggerAt: DateTime.now().add(const Duration(hours: 6)),
          reviewRound: 1,
        ),
      ]);
      clearInteractions(mockPlugin);
      when(() => mockPlugin.cancel(any())).thenAnswer((_) async {});
    when(() => mockPlugin.pendingNotificationRequests())
        .thenAnswer((_) async => <PendingNotificationRequest>[]);
      when(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});

      await service.syncPerAudioReminders([
        PerAudioReminderInfo(
          audioId: 'audio-2',
          audioName: 'Test 2',
          triggerAt: DateTime.now().add(const Duration(days: 1)),
          reviewRound: 2,
        ),
      ]);

      // cancel 旧的 audio-1 通知 ID
      verify(() => mockPlugin.cancel(any())).called(1);
      // 调度新的 audio-2
      verify(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
        ),
      ).called(1);
    });

    test('payload 包含 open_audio: 前缀和 audioId', () async {
      final service = createService();
      await service.syncPerAudioReminders([
        PerAudioReminderInfo(
          audioId: 'my-audio-123',
          audioName: 'Test',
          triggerAt: DateTime.now().add(const Duration(hours: 6)),
          reviewRound: 1,
        ),
      ]);

      verify(
        () => mockPlugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: 'open_audio:my-audio-123',
        ),
      ).called(1);
    });

    test('空列表清除旧通知', () async {
      final service = createService();
      await service.syncPerAudioReminders([
        PerAudioReminderInfo(
          audioId: 'audio-1',
          audioName: 'Test',
          triggerAt: DateTime.now().add(const Duration(hours: 6)),
          reviewRound: 1,
        ),
      ]);
      clearInteractions(mockPlugin);
      when(() => mockPlugin.cancel(any())).thenAnswer((_) async {});
    when(() => mockPlugin.pendingNotificationRequests())
        .thenAnswer((_) async => <PendingNotificationRequest>[]);

      await service.syncPerAudioReminders([]);

      verify(() => mockPlugin.cancel(any())).called(1);
    });

    test('清除系统中残留的 per-audio 通知（跨重启场景）', () async {
      final service = createService();

      // 模拟系统中已有一个 per-audio 范围内的 pending 通知（上次启动遗留）
      when(() => mockPlugin.pendingNotificationRequests()).thenAnswer(
        (_) async => [
          const PendingNotificationRequest(5000, 'Fluency', 'old', 'old_payload'),
        ],
      );

      // 同步空列表——应该 cancel 掉残留的 ID 5000
      await service.syncPerAudioReminders([]);

      verify(() => mockPlugin.cancel(5000)).called(1);
    });

    test('不误删 per-audio 范围外的通知', () async {
      final service = createService();

      // 模拟系统中有 daily reminder（ID 1001，范围外）
      when(() => mockPlugin.pendingNotificationRequests()).thenAnswer(
        (_) async => [
          const PendingNotificationRequest(1001, 'Fluency', 'daily', 'open_study_tasks'),
        ],
      );

      await service.syncPerAudioReminders([]);

      // 不应 cancel ID 1001
      verifyNever(() => mockPlugin.cancel(1001));
    });
  });

  group('NotificationIntent payload 解析（通过 launch payload）', () {
    test('open_study_tasks payload 产生 OpenStudyTasks', () async {
      final service = createService(launchPayload: 'open_study_tasks');

      // 先注册监听，再 init（init 内 _handlePayload 同步发射）
      final intents = <NotificationIntent>[];
      bridge.intents.listen(intents.add);

      await service.init();

      // init 可能因为 FlutterTimezone 失败而 catch——检查 pending intent 作为备选
      if (intents.isEmpty) {
        final pending = bridge.takePendingIntent();
        expect(pending, isA<OpenStudyTasks>());
      } else {
        expect(intents, hasLength(1));
        expect(intents.first, isA<OpenStudyTasks>());
      }
    });

    test('open_audio:<id> payload 产生 OpenAudioLearningPlan', () async {
      final service = createService(launchPayload: 'open_audio:abc-123');

      final intents = <NotificationIntent>[];
      bridge.intents.listen(intents.add);

      await service.init();

      if (intents.isEmpty) {
        final pending = bridge.takePendingIntent();
        expect(pending, isA<OpenAudioLearningPlan>());
        expect(
          (pending! as OpenAudioLearningPlan).audioId,
          equals('abc-123'),
        );
      } else {
        expect(intents, hasLength(1));
        expect(intents.first, isA<OpenAudioLearningPlan>());
        expect(
          (intents.first as OpenAudioLearningPlan).audioId,
          equals('abc-123'),
        );
      }
    });

    test('null payload 不产生任何意图', () async {
      final service = createService(launchPayload: null);

      final intents = <NotificationIntent>[];
      bridge.intents.listen(intents.add);

      await service.init();

      expect(intents, isEmpty);
      expect(bridge.takePendingIntent(), isNull);
    });
  });
}
