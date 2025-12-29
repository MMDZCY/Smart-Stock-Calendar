import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import '../../data/models/event.dart';
import '../../data/models/calendar_subscription.dart';
import '../../utils/import_export.dart';
import '../../utils/lunar_utils.dart';
import 'widgets/event_card.dart';
import 'widgets/year_view.dart';
import 'event_edit_screen.dart';
import 'subscription_management_screen.dart';
import 'stock_market_data_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with TickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  int _currentViewIndex = 1; // 0: 年视图, 1: 月视图 (默认打开月视图)
  
  // 动画控制器
  late final AnimationController _scaleController;
  late final AnimationController _opacityController;
  
  // 获取Hive事件存储箱
  final Box<Event> _eventsBox = Hive.box<Event>('events');
  final Box<CalendarSubscription> _subscriptionsBox = Hive.box<CalendarSubscription>('subscriptions');
  
  // 通知服务
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  // 导入导出管理器
  late final ImportExportManager _importExportManager;
  late final SubscriptionManager _subscriptionManager;
  
  @override
  void initState() {
    super.initState();
    
    // 初始化动画控制器
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..value = 1.0;
    
    _opacityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..value = 1.0;
    
    // 初始化导入导出管理器
    _importExportManager = ImportExportManager(_eventsBox);
    
    // 初始化订阅管理器
    _subscriptionManager = SubscriptionManager(_subscriptionsBox, _eventsBox);
    
    // 延迟初始化通知服务
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _initNotifications();
        _scheduleEventReminders();
        _eventsBox.listenable().addListener(_scheduleEventReminders);
      } catch (e) {
        debugPrint('初始化通知服务时出错: $e');
      }
    });
    
    // 启动时自动同步订阅
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _autoSyncSubscriptions();
      } catch (e) {
        debugPrint('自动同步订阅时出错: $e');
      }
    });
  }

  Future<void> _initNotifications() async {
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings();
      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _notifications.initialize(settings);
      
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'event_reminder_channel',
        '事件提醒',
        description: '日历事件提醒通知',
        importance: Importance.high,
      );
      
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (e) {
      debugPrint('初始化通知服务失败: $e');
    }
  }

  void _scheduleEventReminders() {
    try {
      _notifications.resolvePlatformSpecificImplementation;
    } catch (e) {
      return;
    }
    
    try {
      _notifications.cancelAll();
      for (final event in _eventsBox.values) {
        _scheduleEventReminder(event);
      }
    } catch (e) {
      debugPrint('设置事件提醒时出错: $e');
    }
  }
  
  Future<void> _scheduleEventReminder(Event event) async {
    final now = DateTime.now();
    final eventStart = event.startTime;
    
    if (eventStart.isBefore(now)) return;
    
    final reminderTimes = [
      eventStart.subtract(const Duration(minutes: 30)),
      eventStart.subtract(const Duration(hours: 1)),
      eventStart.subtract(const Duration(hours: 24)),
    ];
    
    for (final reminderTime in reminderTimes) {
      if (reminderTime.isBefore(now)) continue;
      final delay = reminderTime.difference(now).inMilliseconds;
      final notificationId = (event.id.hashCode % 1000000) + (reminderTime.millisecondsSinceEpoch % 1000);
      
      Future.delayed(Duration(milliseconds: delay), () {
        _notifications.show(
          notificationId,
          '事件提醒：${event.title}',
          '事件将在${_getReminderText(reminderTime, eventStart)}开始',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'event_reminder_channel',
              '事件提醒',
              channelDescription: '日历事件提醒通知',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      });
    }
  }
  
  String _getReminderText(DateTime reminderTime, DateTime eventTime) {
    final difference = eventTime.difference(reminderTime);
    if (difference.inMinutes == 30) return '30分钟后';
    if (difference.inHours == 1) return '1小时后';
    if (difference.inHours == 24) return '24小时后';
    return '${difference.inMinutes}分钟后';
  }
  
  Future<void> _autoSyncSubscriptions() async {
    try {
      final results = await _subscriptionManager.syncAllSubscriptions();
      if (results.isNotEmpty && mounted) {
        String message = '订阅同步完成：\n';
        results.forEach((name, count) {
          if (count >= 0) {
            message += '$name: $count 个事件\n';
          } else {
            message += '$name: 同步失败\n';
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('订阅同步失败: $e')));
      }
    }
  }
  
  Future<void> _syncSubscriptions() async {
    try {
      final results = await _subscriptionManager.syncAllSubscriptions();
      if (mounted) {
        String message = '订阅同步完成：\n';
        results.forEach((name, count) {
          if (count >= 0) {
            message += '$name: $count 个事件\n';
          } else {
            message += '$name: 同步失败\n';
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('订阅同步失败: $e')));
      }
    }
  }
  
  void _openSubscriptionManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionManagementScreen(
          subscriptionManager: _subscriptionManager,
        ),
      ),
    ).then((_) => setState(() {})); 
  }
  
  Future<void> _exportEventsToICS() async {
    try {
      final icsContent = await _importExportManager.exportEventsToICS();
      await Clipboard.setData(ClipboardData(text: icsContent));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('事件已导出到剪贴板（ICS格式）')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }
  
  Future<void> _exportEventsToJSON() async {
    try {
      final jsonContent = await _importExportManager.exportEventsToJSON();
      await Clipboard.setData(ClipboardData(text: jsonContent));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('事件已导出到剪贴板（JSON格式）')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }
  
  Future<void> _importEventsFromICS() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData?.text == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('剪贴板中没有有效数据')));
        }
        return;
      }
      final importedCount = await _importExportManager.importEventsFromICS(clipboardData!.text!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('成功导入 $importedCount 个事件')));
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }
  
  Future<void> _importEventsFromJSON() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData?.text == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('剪贴板中没有有效数据')));
        }
        return;
      }
      final importedCount = await _importExportManager.importEventsFromJSON(clipboardData!.text!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('成功导入 $importedCount 个事件')));
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }
  
  Future<void> _testNotification() async {
    try {
      _notifications;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('通知服务尚未初始化，请稍后再试')));
      }
      return;
    }
    
    await _notifications.show(
      9999,
      '测试通知',
      '日程提醒功能正常工作',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'event_reminder_channel',
          '事件提醒',
          channelDescription: '日历事件提醒通知',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
  
  @override
  void dispose() {
    _scaleController.dispose();
    _opacityController.dispose();
    super.dispose();
  }
  
  void _handleViewChange(int newIndex) {
    if (newIndex == _currentViewIndex) return;
    
    _opacityController.reverse().then((_) {
      setState(() {
        _currentViewIndex = newIndex;
        if (newIndex == 0) {
          _focusedDay = DateTime.now();
        }
      });

      _scaleController.value = 0.8;
      _scaleController.forward();
      _opacityController.forward();
    });
  }
  
  void _handleMonthSelected(DateTime selectedMonth) {
    final firstDay = DateTime(2000);
    if (selectedMonth.isBefore(firstDay)) {
      _focusedDay = firstDay;
    } else {
      _focusedDay = selectedMonth;
    }
    _handleViewChange(1);
  }
  
  void _handleDoubleTapDay(DateTime day) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StockMarketDataScreen(
          selectedDate: day,
          eventsBox: _eventsBox,
        ),
      ),
    );
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _eventsBox.values.where((event) {
      final start = event.startTime;
      final end = event.endTime;
      return (start.year == day.year && start.month == day.month && start.day == day.day) ||
             (end.year == day.year && end.month == day.month && end.day == day.day) ||
             (start.isBefore(day) && end.isAfter(day));
    }).toList();
  }

  void _editEvent(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventEditScreen(
          event: event,
          onEventSaved: (updatedEvent) {
            event.title = updatedEvent.title;
            event.startTime = updatedEvent.startTime;
            event.endTime = updatedEvent.endTime;
            event.location = updatedEvent.location;
            event.description = updatedEvent.description;
            event.isAllDay = updatedEvent.isAllDay;
            event.save();
            setState(() {});
          },
          onEventDeleted: (deletedEvent) {
            deletedEvent.delete();
            setState(() {});
          },
        ),
      ),
    );
  }

  void _deleteEvent(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除事件'),
        content: Text('确定要删除事件"${event.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              event.delete();
              setState(() {});
              Navigator.pop(context);
            },
            child: Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  // 获取当前视图
  Widget _getCurrentView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    switch (_currentViewIndex) {
      case 0: // 年视图
        return YearView(
          focusedDay: _focusedDay,
          onMonthSelected: _handleMonthSelected,
        );
      case 1: // 月视图
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.08),
                spreadRadius: 0,
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TableCalendar(
            locale: 'zh_CN', // 1. 确保设置语言
            daysOfWeekHeight: 30, // 2. 确保显式设置高度
            
            firstDay: DateTime(2000),
            lastDay: DateTime(2050),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: '月'},
            
            calendarStyle: CalendarStyle(
              cellPadding: const EdgeInsets.all(4),
              todayDecoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              selectedDecoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              selectedTextStyle: TextStyle(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              weekendTextStyle: TextStyle(
                color: colorScheme.error, 
                fontWeight: FontWeight.w600
              ),
              defaultTextStyle: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
              outsideTextStyle: TextStyle(
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: theme.textTheme.titleLarge!.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              leftChevronIcon: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chevron_left, color: colorScheme.onSurfaceVariant, size: 24),
              ),
              rightChevronIcon: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 24),
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              headerMargin: const EdgeInsets.symmetric(vertical: 16),
            ),
            
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              weekendStyle: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              }
            },
            onPageChanged: (focusedDay) => _focusedDay = focusedDay,
            eventLoader: _getEventsForDay,
            
            calendarBuilders: CalendarBuilders(
              dowBuilder: (context, date) {
                final int weekday = date.weekday % 7;
                final List<String> weekdays = ['日', '一', '二', '三', '四', '五', '六'];
                return Center(
                  child: Text(
                    weekdays[weekday],
                    style: TextStyle(
                      color: weekday == 0 || weekday == 6 
                        ? colorScheme.error 
                        : colorScheme.onSurface.withOpacity(0.8),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                );
              },
              defaultBuilder: (context, day, focusedDay) {
                bool isHoliday = LunarUtils.isHoliday(day);
                return GestureDetector(
                  onDoubleTap: () => _handleDoubleTapDay(day),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          day.day.toString(),
                          style: TextStyle(
                            color: isHoliday ? colorScheme.error : colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        if (isHoliday)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
              todayBuilder: (context, day, focusedDay) {
                bool isHoliday = LunarUtils.isHoliday(day);
                return GestureDetector(
                  onDoubleTap: () => _handleDoubleTapDay(day),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.primary, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          day.day.toString(),
                          style: TextStyle(
                            color: isHoliday ? colorScheme.error : colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        if (isHoliday)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      case 2: // 周视图
        return TableCalendar(
          locale: 'zh_CN',
          daysOfWeekHeight: 30, // 显式高度
          
          firstDay: DateTime(2000),
          lastDay: DateTime(2050),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: CalendarFormat.week,
          availableCalendarFormats: const {
            CalendarFormat.month: '月',
            CalendarFormat.week: '周',
          },
          
          calendarStyle: CalendarStyle(
            cellPadding: EdgeInsets.zero,
            todayDecoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            weekendTextStyle: TextStyle(color: colorScheme.error),
            defaultTextStyle: TextStyle(fontSize: 14, color: colorScheme.onSurface),
            todayTextStyle: TextStyle(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            selectedTextStyle: TextStyle(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            outsideTextStyle: TextStyle(
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
          
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(
              color: colorScheme.onSurface, 
              fontSize: 16, 
              fontWeight: FontWeight.bold
            ),
            leftChevronIcon: Icon(Icons.chevron_left, size: 20, color: colorScheme.onSurface),
            rightChevronIcon: Icon(Icons.chevron_right, size: 20, color: colorScheme.onSurface),
          ),
          
          calendarBuilders: CalendarBuilders(
            dowBuilder: (context, date) {
              final int weekday = date.weekday % 7;
              final List<String> weekdays = ['日', '一', '二', '三', '四', '五', '六'];
              return Center(
                child: Text(
                  weekdays[weekday],
                  style: TextStyle(
                    color: weekday == 0 || weekday == 6 
                      ? colorScheme.error 
                      : colorScheme.onSurface.withOpacity(0.8),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              );
            },
            defaultBuilder: (context, day, focusedDay) {
              final lunarDate = LunarUtils.solarToLunar(day);
              bool isHoliday = LunarUtils.isHoliday(day);
              return GestureDetector(
                onDoubleTap: () => _handleDoubleTapDay(day),
                child: Container(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day.day.toString(),
                        style: TextStyle(
                          color: isSameDay(_selectedDay, day) 
                              ? colorScheme.onPrimary 
                              : (isHoliday ? colorScheme.error : colorScheme.onSurface),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        lunarDate.getShortDescription().split('月')[1],
                        style: TextStyle(
                          fontSize: 10,
                          color: isSameDay(_selectedDay, day) 
                              ? colorScheme.onPrimary.withOpacity(0.8) 
                              : (isHoliday ? colorScheme.error.withOpacity(0.8) : colorScheme.outline),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            todayBuilder: (context, day, focusedDay) {
              final lunarDate = LunarUtils.solarToLunar(day);
              bool isHoliday = LunarUtils.isHoliday(day);
              return GestureDetector(
                onDoubleTap: () => _handleDoubleTapDay(day),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day.day.toString(),
                        style: TextStyle(
                          color: isHoliday ? colorScheme.error : colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        lunarDate.getShortDescription().split('月')[1],
                        style: TextStyle(
                          fontSize: 10,
                          color: isHoliday ? colorScheme.error.withOpacity(0.8) : colorScheme.onSecondaryContainer.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            selectedBuilder: (context, day, focusedDay) {
              final lunarDate = LunarUtils.solarToLunar(day);
              return GestureDetector(
                onDoubleTap: () => _handleDoubleTapDay(day),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day.day.toString(),
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        lunarDate.getShortDescription().split('月')[1],
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onPrimary.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('日程'),
        actions: [
          IconButton(
            icon: const Icon(Icons.rss_feed),
            onPressed: _openSubscriptionManagement,
            tooltip: '订阅管理',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.import_export),
            onSelected: (value) {
              if (value == 'export_ics') {
                _exportEventsToICS();
              } else if (value == 'export_json') {
                _exportEventsToJSON();
              } else if (value == 'import_ics') {
                _importEventsFromICS();
              } else if (value == 'import_json') {
                _importEventsFromJSON();
              } else if (value == 'sync_subscriptions') {
                _syncSubscriptions();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_ics',
                child: Text('导出为ICS格式'),
              ),
              const PopupMenuItem(
                value: 'export_json',
                child: Text('导出为JSON格式'),
              ),
              const PopupMenuItem(
                value: 'import_ics',
                child: Text('从ICS文件导入'),
              ),
              const PopupMenuItem(
                value: 'import_json',
                child: Text('从JSON文件导入'),
              ),
              const PopupMenuItem(
                value: 'sync_subscriptions',
                child: Text('同步所有订阅'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _testNotification,
            tooltip: '测试通知',
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.view_agenda_outlined),
            onSelected: _handleViewChange,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 0,
                child: Text('年视图'),
              ),
              const PopupMenuItem(
                value: 1,
                child: Text('月视图'),
              ),
              const PopupMenuItem(
                value: 2,
                child: Text('周视图'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
          children: [
            Expanded(
              child: _getCurrentView(),
            ),
            if (_currentViewIndex == 1 || _currentViewIndex == 2)
              SizedBox(
                height: 200, 
                child: _selectedDay == null
                    ? Center(child: Text('请选择日期', style: TextStyle(color: colorScheme.onSurfaceVariant)))
                    : ValueListenableBuilder(
                        valueListenable: _eventsBox.listenable(),
                        builder: (context, box, _) {
                          final events = _eventsBox.values.where((event) {
                            final start = event.startTime;
                            return start.year == _selectedDay!.year &&
                                start.month == _selectedDay!.month &&
                                start.day == _selectedDay!.day;
                          }).toList();
                          
                          if (events.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_busy, size: 48, color: colorScheme.outline.withOpacity(0.5)),
                                  const SizedBox(height: 8),
                                  Text('当天无事件', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            );
                          }
                          return ListView.builder(
                            itemCount: events.length,
                            itemBuilder: (context, index) => GestureDetector(
                              onTap: () => _editEvent(events[index]),
                              child: Dismissible(
                                key: Key(events[index].id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: colorScheme.errorContainer,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: Icon(Icons.delete, color: colorScheme.onErrorContainer),
                                ),
                                onDismissed: (direction) => _deleteEvent(events[index]),
                                child: EventCard(event: events[index]),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      floatingActionButton: null,
    );
  }
}