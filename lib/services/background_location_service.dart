import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

import '../models/memo_item.dart';

// ─────────────────────────────────────────────
// 백그라운드 isolate 진입점 (top-level, vm:entry-point 필수)
// ─────────────────────────────────────────────
@pragma('vm:entry-point')
void backgroundLocationCallback() {
  FlutterForegroundTask.setTaskHandler(_BackgroundLocationHandler());
}

/// 백그라운드 작업 핸들러 — 별도 isolate에서 실행됩니다.
class _BackgroundLocationHandler extends TaskHandler {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<Position>? _positionSub;
  List<MemoItem> _memos = [];
  final Set<String> _notifiedIds = {};

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _loadMemos();
    _startStream();
  }

  /// 30초마다 반복 — 메모 목록을 최신화
  @override
  void onRepeatEvent(DateTime timestamp) {
    _loadMemos();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _positionSub?.cancel();
  }

  /// 메인 isolate에서 `sendDataToTask('refresh')` 호출 시 실행
  @override
  void onReceiveData(Object data) {
    _loadMemos();
  }

  // ── 내부 메서드 ──────────────────────────────

  Future<void> _loadMemos() async {
    final raw =
        await FlutterForegroundTask.getData<String>(key: 'memos_json');
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _memos = list.map(MemoItem.fromJson).toList();
    } catch (_) {}
  }

  void _startStream() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen(_onPosition, onError: (_) {});
  }

  void _onPosition(Position position) {
    for (final memo in _memos) {
      if (!memo.isActive) continue;
      if (memo.triggerType != TriggerType.location) continue;
      if (memo.latitude == null || memo.longitude == null) continue;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        memo.latitude!,
        memo.longitude!,
      );

      if (distance <= memo.radius) {
        if (!_notifiedIds.contains(memo.id)) {
          _notifiedIds.add(memo.id);
          _sendNotification(memo);
        }
      } else {
        _notifiedIds.remove(memo.id); // 반경 이탈 → 재진입 시 재알림
      }
    }
  }

  Future<void> _sendNotification(MemoItem memo) async {
    final body = memo.description.isNotEmpty
        ? memo.description
        : '${memo.locationName} 근처에 도착했어요!';

    await _notifications.show(
      memo.id.hashCode,
      '📍 ${memo.title}',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'memo_ping_location_bg',
          '위치 알림',
          channelDescription: '지정 장소 근처 도착 알림 (백그라운드)',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 메인 isolate에서 사용하는 서비스 인터페이스
// ─────────────────────────────────────────────
class BackgroundLocationService {
  static const int _serviceId = 256;

  /// `main()` 또는 앱 시작 시 한 번만 호출
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'memo_ping_fg_channel',
        channelName: '위치 모니터링',
        channelDescription: '메모핑이 백그라운드에서 위치를 확인하고 있어요',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: true,
        allowWifiLock: false,
      ),
    );
  }

  /// 메모 목록을 SharedPreferences에 저장하고 실행 중인 태스크에 갱신 요청
  static Future<void> saveMemos(List<MemoItem> memos) async {
    final encoded = jsonEncode(memos.map((m) => m.toJson()).toList());
    await FlutterForegroundTask.saveData(key: 'memos_json', value: encoded);
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask('refresh');
    }
  }

  /// 백그라운드 서비스 시작 (이미 실행 중이면 메모만 갱신)
  static Future<void> start(List<MemoItem> memos) async {
    await saveMemos(memos);
    if (await FlutterForegroundTask.isRunningService) return;

    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      notificationTitle: '메모핑 실행 중',
      notificationText: '위치 기반 메모를 모니터링하고 있어요',
      callback: backgroundLocationCallback,
    );
  }

  /// 백그라운드 서비스 중지
  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }

  static Future<bool> get isRunning =>
      FlutterForegroundTask.isRunningService;
}
