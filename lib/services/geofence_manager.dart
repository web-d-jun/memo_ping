import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geofencing_api/geofencing_api.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/memo_item.dart';

class GeofenceManager {
  GeofenceManager._();
  static final GeofenceManager instance = GeofenceManager._();

  final _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // 알림 초기화
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(initSettings);

    // foreground task 초기화
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'memo_ping_geofence',
        channelName: '메모핑 위치 알림',
        channelDescription: '주변 메모 위치를 감지합니다.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        allowWifiLock: false,
      ),
    );

    _initialized = true;
  }

  // 권한 요청 순서: 위치(foreground) → 위치(background) → 알림
  Future<bool> requestPermissions(BuildContext context) async {
    // 1. 정밀 위치 권한
    var locationStatus = await Permission.locationWhenInUse.request();
    if (!locationStatus.isGranted) return false;

    // 2. 백그라운드 위치 권한 (항상 허용 - 설정 앱 안내)
    var bgStatus = await Permission.locationAlways.status;
    if (!bgStatus.isGranted) {
      if (context.mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('백그라운드 위치 권한 필요'),
            content: const Text(
              '주변 장소에 가까워지면 자동으로 알림을 받으려면\n"항상 허용"으로 위치 권한을 설정해 주세요.\n\n설정 앱 → 앱 → 메모핑 → 권한 → 위치 → 항상 허용',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(_, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(_, true);
                  await openAppSettings();
                },
                child: const Text('설정 열기'),
              ),
            ],
          ),
        );
        if (confirmed != true) return false;
      }
      return false;
    }

    // 3. 알림 권한 (Android 13+)
    await Permission.notification.request();

    return true;
  }

  // Geofence 전체 재등록 (메모 목록이 변경될 때마다 호출)
  Future<void> syncGeofences(List<MemoItem> memos) async {
    await initialize();

    // 서비스 중지 후 재등록
    await GeofencingApi.instance.stopAll();

    final locationMemos = memos.where(
      (m) =>
          m.isActive &&
          m.triggerType == TriggerType.location &&
          m.latitude != null &&
          m.longitude != null,
    );

    if (locationMemos.isEmpty) return;

    // 위치 권한 확인
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    for (final memo in locationMemos) {
      await _registerGeofence(memo);
    }
  }

  Future<void> _registerGeofence(MemoItem memo) async {
    try {
      await GeofencingApi.instance.addGeofenceRegion(
        GeofenceRegion.circular(
          id: memo.id,
          data: memo.title,
          center: LatLng(memo.latitude!, memo.longitude!),
          radius: memo.radius,
          loiteringDelay: 0,
        ),
        onStatusChanged: (region, status, position) {
          if (status == GeofenceStatus.enter) {
            _sendNotification(memo);
          }
        },
      );
    } catch (_) {}
  }

  Future<void> removeGeofence(String memoId) async {
    try {
      await GeofencingApi.instance.removeGeofenceRegionById(memoId);
    } catch (_) {}
  }

  Future<void> _sendNotification(MemoItem memo) async {
    const androidDetails = AndroidNotificationDetails(
      'memo_ping_channel',
      '메모핑 위치 알림',
      channelDescription: '주변 장소에 도착했을 때 알림',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);

    final body = memo.description.isNotEmpty
        ? memo.description
        : '${memo.locationName} 근처입니다!';

    await _notifications.show(
      memo.id.hashCode,
      '📍 ${memo.title}',
      body,
      details,
    );
  }
}
