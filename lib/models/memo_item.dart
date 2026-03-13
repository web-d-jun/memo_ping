import 'package:flutter/material.dart';

enum TriggerType { location, time }

class MemoItem {
  final String id;
  final String title;
  final String description;
  final TriggerType triggerType;
  // Location fields
  final String locationName;
  final double radius; // meters
  // Time fields
  final TimeOfDay? triggerTime;
  final List<bool> repeatDays; // 0=월 ~ 6=일
  bool isActive;

  MemoItem({
    required this.id,
    required this.title,
    this.description = '',
    required this.triggerType,
    this.locationName = '',
    this.radius = 200,
    this.triggerTime,
    List<bool>? repeatDays,
    this.isActive = true,
  }) : repeatDays = repeatDays ?? List.filled(7, false);

  String get triggerLabel {
    if (triggerType == TriggerType.location) {
      if (locationName.isEmpty) return '위치 미설정';
      return '$locationName · ${radius.toInt()}m 이내';
    } else {
      if (triggerTime == null) return '시간 미설정';
      final h = triggerTime!.hour;
      final m = triggerTime!.minute;
      final period = h < 12 ? '오전' : '오후';
      final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      final displayMin = m.toString().padLeft(2, '0');
      return '$period $displayHour:$displayMin$_daysSummary';
    }
  }

  String get _daysSummary {
    const names = ['월', '화', '수', '목', '금', '토', '일'];
    final active = [for (int i = 0; i < 7; i++) if (repeatDays[i]) names[i]];
    if (active.isEmpty) return '';
    if (active.length == 7) return ' · 매일';
    if (active.length == 5 && !repeatDays[5] && !repeatDays[6]) return ' · 평일';
    if (active.length == 2 && repeatDays[5] && repeatDays[6]) return ' · 주말';
    return ' · ${active.join(', ')}';
  }

  MemoItem copyWith({
    String? title,
    String? description,
    TriggerType? triggerType,
    String? locationName,
    double? radius,
    TimeOfDay? triggerTime,
    List<bool>? repeatDays,
    bool? isActive,
  }) {
    return MemoItem(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      triggerType: triggerType ?? this.triggerType,
      locationName: locationName ?? this.locationName,
      radius: radius ?? this.radius,
      triggerTime: triggerTime ?? this.triggerTime,
      repeatDays: repeatDays ?? List.from(this.repeatDays),
      isActive: isActive ?? this.isActive,
    );
  }
}
