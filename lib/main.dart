import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'ui/screens/calendar_screen.dart';
import 'data/models/event.dart';
import 'data/models/calendar_subscription.dart';

void main() async {
  // 初始化Hive本地数据库
  await Hive.initFlutter();
  // 注册事件模型适配器（用于Hive存储）
  Hive.registerAdapter(EventAdapter());
  // 注册CalendarSubscription适配器
  Hive.registerAdapter(CalendarSubscriptionAdapter());
  // 打开事件存储箱
  await Hive.openBox<Event>('events');
  // 打开订阅存储箱
  await Hive.openBox<CalendarSubscription>('subscriptions');
  
  // 初始化时区数据库
  tz_data.initializeTimeZones();
  
  // 初始化通知服务
  await _initNotifications();
  
  runApp(const MyApp());
}

// 全局通知初始化
Future<void> _initNotifications() async {
  final notifications = FlutterLocalNotificationsPlugin();
  
  // 请求通知权限
  await Permission.notification.request();
  
  // 初始化通知设置
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings();
  const InitializationSettings settings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  
  await notifications.initialize(settings);
  
  // 创建通知渠道（仅Android）
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'event_reminder_channel',
    '事件提醒',
    description: '日历事件提醒通知',
    importance: Importance.high,
  );
  
  await notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Calendar',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const CalendarScreen(),
    );
  }
}
