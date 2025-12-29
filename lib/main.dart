import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'ui/screens/calendar_screen.dart';
import 'ui/screens/event_edit_screen.dart';
import 'data/models/event.dart';
import 'data/models/calendar_subscription.dart';
import 'package:intl/date_symbol_data_local.dart';

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
  await initializeDateFormatting('zh_CN', null);
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
    // 定义种子颜色：使用专业的靛蓝色 (Indigo) 作为主色调
    const seedColor = Color(0xFF6366F1); 

    return MaterialApp(
      title: 'Smart Stock Calendar', // 升级应用名称
      debugShowCheckedModeBanner: false, // 移除 debug 标签
      
      // 1. 亮色主题配置 (Material 3)
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        // 统一 AppBar 样式：透明背景，居中标题
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
        ),
        // 统一卡片样式
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          surfaceTintColor: Colors.white, // 减少 M3 默认的混色层
        ),
      ),

      // 2. 深色主题配置 (自动适配夜间模式)
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark, // 生成深色配色方案
        ),
        // 深色模式下使用纯黑偏灰背景，减少对比度刺激
        scaffoldBackgroundColor: const Color(0xFF121212), 
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: const Color(0xFF1E1E1E), // 深灰卡片背景
        ),
      ),

      // 跟随系统自动切换亮/暗模式
      themeMode: ThemeMode.system,

      home: const CalendarScreen(),
      routes: {
        '/event_edit': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          final Event? event = args?['event'];
          final DateTime? selectedDate = args?['selectedDate'];
          
          return EventEditScreen(
            selectedDate: selectedDate,
            event: event,
            onEventSaved: (event) async {
              final eventsBox = Hive.box<Event>('events');
              await eventsBox.put(event.id, event);
              Navigator.of(context).pop(true);
            },
            onEventDeleted: (event) async {
              await event.delete();
              Navigator.of(context).pop(true);
            },
          );
        },
      },
    );
  }
}