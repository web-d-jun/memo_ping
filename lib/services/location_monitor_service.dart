import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

import '../models/memo_item.dart';

/// 앱이 포그라운드에 있는 동안 실시간으로 위치를 감시하고,
/// 활성화된 위치 기반 메모의 반경 안에 진입하면 알림을 보냅니다.
class LocationMonitorService {
  final FlutterLocalNotificationsPlugin _notifications;

  StreamSubscription<Position>? _positionSub;

  /// 이미 알림을 보낸 메모 ID 집합 (중복 방지)
  final Set<String> _notifiedIds = {};

  /// 반경 밖으로 나간 메모 ID 집합 (재진입 시 재알림을 위해)
  final Set<String> _exitedIds = {};

  List<MemoItem> _memos = [];

  LocationMonitorService(this._notifications);

  /// 위치 모니터링 시작 또는 메모 목록 갱신
  void start(List<MemoItem> memos) {
    _memos = List.unmodifiable(memos);
    if (_positionSub != null) return; // 이미 실행 중이면 목록만 갱신

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15, // 15m 이상 이동했을 때만 이벤트
      ),
    ).listen(_onPosition, onError: (_) {});
  }

  /// 메모 목록이 변경될 때 호출
  void updateMemos(List<MemoItem> memos) {
    _memos = List.unmodifiable(memos);
  }

  /// 모니터링 중지
  void stop() {
    _positionSub?.cancel();
    _positionSub = null;
    _notifiedIds.clear();
    _exitedIds.clear();
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
        // 반경 안 — 아직 알림을 보내지 않은 경우에만 발송
        if (!_notifiedIds.contains(memo.id)) {
          _notifiedIds.add(memo.id);
          _exitedIds.remove(memo.id);
          _sendNotification(memo);
        }
      } else {
        // 반경 밖 — 다음 재진입 시 다시 알림 가능하도록 초기화
        if (_notifiedIds.contains(memo.id)) {
          _notifiedIds.remove(memo.id);
          _exitedIds.add(memo.id);
        }
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
          'memo_ping_location_fg',
          '위치 알림 (포그라운드)',
          channelDescription: '앱 사용 중 지정 장소 근처에 도착하면 알림',
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
