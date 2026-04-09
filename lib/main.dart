import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/home_screen.dart';
import 'services/background_location_service.dart';

/// 앱 전체에서 공유하는 알림 플러그인 인스턴스
final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await notificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestSoundPermission: true,
        requestBadgePermission: true,
      ),
    ),
  );

  // 백그라운드 포그라운드 서비스 초기화 (방식 2)
  BackgroundLocationService.init();

  runApp(const MemoPingApp());
}

class MemoPingApp extends StatelessWidget {
  const MemoPingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '메모핑',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C6BC0),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

