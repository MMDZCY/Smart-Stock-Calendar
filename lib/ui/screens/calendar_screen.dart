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
    
    // 初始化通知服务
    _initNotifications();
    
    // 安排事件提醒
    _scheduleEventReminders();
    
    // 监听事件变化，当有新事件时安排提醒
    _eventsBox.listenable().addListener(_scheduleEventReminders);
    
    // 启动时自动同步订阅（延迟执行以确保初始化完成）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSyncSubscriptions();
    });
  }
  

  

  
  // 初始化通知服务
  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(settings);
    
    // 创建通知渠道（仅Android）
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'event_reminder_channel',
      '事件提醒',
      description: '日历事件提醒通知',
      importance: Importance.high,
    );
    
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // 安排事件提醒
  void _scheduleEventReminders() {
    // 检查通知服务是否已初始化
    try {
      _notifications;
    } catch (e) {
      return;
    }
    
    // 取消所有之前的提醒
    _notifications.cancelAll();
    
    // 为每个事件安排提醒
    for (final event in _eventsBox.values) {
      _scheduleEventReminder(event);
    }
  }
  
  // 为单个事件安排提醒
  Future<void> _scheduleEventReminder(Event event) async {
    final now = DateTime.now();
    final eventStart = event.startTime;
    
    if (eventStart.isBefore(now)) return;
    
    // 安排多个提醒时间点
    final reminderTimes = [
      eventStart.subtract(const Duration(minutes: 30)), // 提前30分钟
      eventStart.subtract(const Duration(hours: 1)),    // 提前1小时
      eventStart.subtract(const Duration(hours: 24)),   // 提前24小时
    ];
    
    for (final reminderTime in reminderTimes) {
      // 如果提醒时间已经过去，跳过
      if (reminderTime.isBefore(now)) continue;
      
      // 计算延迟时间（毫秒）
      final delay = reminderTime.difference(now).inMilliseconds;
      
      // 生成唯一通知ID
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
  
  // 获取提醒文本
  String _getReminderText(DateTime reminderTime, DateTime eventTime) {
    final difference = eventTime.difference(reminderTime);
    if (difference.inMinutes == 30) return '30分钟后';
    if (difference.inHours == 1) return '1小时后';
    if (difference.inHours == 24) return '24小时后';
    return '${difference.inMinutes}分钟后';
  }
  
  // 自动同步订阅
  Future<void> _autoSyncSubscriptions() async {
    try {
      final results = await _subscriptionManager.syncAllSubscriptions();
      
      // 显示同步结果
      if (results.isNotEmpty && mounted) {
        String message = '订阅同步完成：\\n';
        results.forEach((name, count) {
          if (count >= 0) {
            message += '$name: $count 个事件\\n';
          } else {
            message += '$name: 同步失败\\n';
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('订阅同步失败: $e')),
        );
      }
    }
  }
  
  Future<void> _syncSubscriptions() async {
    try {
      final results = await _subscriptionManager.syncAllSubscriptions();
      
      if (mounted) {
        String message = '订阅同步完成：\\n';
        results.forEach((name, count) {
          if (count >= 0) {
            message += '$name: $count 个事件\\n';
          } else {
            message += '$name: 同步失败\\n';
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        
        setState(() {}); // 刷新界面
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('订阅同步失败: $e')),
        );
      }
    }
  }
  
  // 打开订阅管理界面
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
  
  // 导出事件为ICS格式
  Future<void> _exportEventsToICS() async {
    try {
      final icsContent = await _importExportManager.exportEventsToICS();
      await Clipboard.setData(ClipboardData(text: icsContent));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('事件已导出到剪贴板（ICS格式）')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }
  
  // 导出事件为JSON格式
  Future<void> _exportEventsToJSON() async {
    try {
      final jsonContent = await _importExportManager.exportEventsToJSON();
      await Clipboard.setData(ClipboardData(text: jsonContent));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('事件已导出到剪贴板（JSON格式）')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }
  
  // 从ICS格式导入事件
  Future<void> _importEventsFromICS() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData?.text == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('剪贴板中没有有效数据')),
          );
        }
        return;
      }
      
      final importedCount = await _importExportManager.importEventsFromICS(clipboardData!.text!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入 $importedCount 个事件')),
        );
        setState(() {}); // 刷新界面
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }
  
  // 从JSON格式导入事件
  Future<void> _importEventsFromJSON() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData?.text == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('剪贴板中没有有效数据')),
          );
        }
        return;
      }
      
      final importedCount = await _importExportManager.importEventsFromJSON(clipboardData!.text!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入 $importedCount 个事件')),
        );
        setState(() {}); // 刷新界面
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }
  
  // 测试通知功能
  Future<void> _testNotification() async {
    // 检查通知服务是否已初始化
    try {
      _notifications;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知服务尚未初始化，请稍后再试')),
        );
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
  
  // 处理视图切换动画
  void _handleViewChange(int newIndex) {
    if (newIndex == _currentViewIndex) return;
    
    _opacityController.reverse().then((_) {
      // 更新视图索引
      setState(() {
        _currentViewIndex = newIndex;
        // 确保切换到年视图时始终显示当前年份
        if (newIndex == 0) {
          _focusedDay = DateTime.now();
        }
      });

      _scaleController.value = 0.8;
      _scaleController.forward();
      _opacityController.forward();
    });
  }
  
  // 处理月份选择
  void _handleMonthSelected(DateTime selectedMonth) {
    final firstDay = DateTime(2000);
    if (selectedMonth.isBefore(firstDay)) {
      _focusedDay = firstDay;
    } else {
      _focusedDay = selectedMonth;
    }
    _handleViewChange(1);
  }
  
  // 处理双击日期，跳转到行情数据页面
  void _handleDoubleTapDay(DateTime day) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StockMarketDataScreen(selectedDate: day),
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

  // 新事件
  void _addNewEvent() {
    if (_selectedDay == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventEditScreen(
          selectedDate: _selectedDay!,
          onEventSaved: (event) {
            _eventsBox.add(event);
            setState(() {});
          },
        ),
      ),
    );
  }

  // 编辑事件
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

  // 删除事件
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
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  // 获取当前视图
  Widget _getCurrentView() {
    switch (_currentViewIndex) {
      case 0: // 年视图
        return YearView(
          focusedDay: _focusedDay,
          onMonthSelected: _handleMonthSelected,
        );
      case 1: // 月视图
        return TableCalendar(
          firstDay: DateTime(2000),
          lastDay: DateTime(2050),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {CalendarFormat.month: '月'},
          
          calendarStyle: const CalendarStyle(),
          
          // 头部样式 
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
            leftChevronIcon: Icon(Icons.chevron_left, color: Colors.black),
            rightChevronIcon: Icon(Icons.chevron_right, color: Colors.black),
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1)),
            ),
            leftChevronMargin: EdgeInsets.only(left: 8),
            rightChevronMargin: EdgeInsets.only(right: 8),
            headerMargin: EdgeInsets.symmetric(vertical: 12),
          ),
          
          
          // 星期
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            weekendStyle: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            decoration: BoxDecoration(
              color: Colors.transparent,
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
            defaultBuilder: (context, day, focusedDay) {
              bool isHoliday = LunarUtils.isHoliday(day);
              return GestureDetector(
                onDoubleTap: () => _handleDoubleTapDay(day),
                child: Container(
                  alignment: Alignment.center,
                  child: Text(
                    day.day.toString(),
                    style: TextStyle(
                      color: isSameDay(_selectedDay, day) ? Colors.white : (isHoliday ? Colors.red : Colors.black),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
            todayBuilder: (context, day, focusedDay) {
              bool isHoliday = LunarUtils.isHoliday(day);
              return GestureDetector(
                onDoubleTap: () => _handleDoubleTapDay(day),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    day.day.toString(),
                    style: TextStyle(
                      color: isHoliday ? Colors.red : Colors.blue[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
            selectedBuilder: (context, day, focusedDay) {
              return GestureDetector(
                onDoubleTap: () => _handleDoubleTapDay(day),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    day.day.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
            outsideBuilder: (context, day, focusedDay) {
              bool isHoliday = LunarUtils.isHoliday(day);
              return GestureDetector(
                onDoubleTap: () => _handleDoubleTapDay(day),
                child: Container(
                  alignment: Alignment.center,
                  child: Text(
                    day.day.toString(),
                    style: TextStyle(
                      color: isHoliday ? Colors.red.withValues(alpha: 0.6) : Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
            // 自定义星期标题显示为中文
            dowBuilder: (context, date) {
              // 获取星期几（0-6，0是周日）
              final int weekday = date.weekday % 7;
              final List<String> weekdays = ['日', '一', '二', '三', '四', '五', '六'];
              return Container(
                alignment: Alignment.center,
                child: Text(
                  weekdays[weekday],
                  style: weekday == 0 || weekday == 6 
                    ? const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
                    : const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        );
      case 2: // 周视图
        return TableCalendar(
          firstDay: DateTime(2000),
          lastDay: DateTime(2050),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: CalendarFormat.week,
          availableCalendarFormats: const {
            CalendarFormat.month: '月',
            CalendarFormat.week: '周',
          },
          
          // 紧凑的日历样式 - 减少空白
          calendarStyle: CalendarStyle(
            // 减少单元格内边距
            cellPadding: EdgeInsets.zero,
            // 紧凑的今日样式
            todayDecoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            // 选中样式
            selectedDecoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            // 周末样式
            weekendTextStyle: TextStyle(color: Colors.red),
            // 默认文本样式
            defaultTextStyle: TextStyle(fontSize: 14),
            // 今日文本样式
            todayTextStyle: TextStyle(
              color: Colors.blue.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            // 选中文本样式
            selectedTextStyle: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            // 外部日期样式
            outsideTextStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
            ),
            // 周末装饰
            weekendDecoration: BoxDecoration(
              color: Colors.grey.shade50,
            ),
            // 紧凑的行高
            cellAlignment: Alignment.center,
          ),
          
          // 紧凑的头部样式 - 移除格式切换按钮以避免错误
          headerStyle: HeaderStyle(
            formatButtonVisible: false, // 禁用格式切换按钮
            titleCentered: true,
            titleTextStyle: TextStyle(
              color: Colors.black, 
              fontSize: 16, 
              fontWeight: FontWeight.bold
            ),
            leftChevronIcon: Icon(Icons.chevron_left, size: 20, color: Colors.black),
            rightChevronIcon: Icon(Icons.chevron_right, size: 20, color: Colors.black),
          ),
          
          // 添加农历显示功能
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              // 转换为农历日期
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
                          color: isSameDay(_selectedDay, day) ? Colors.white : (isHoliday ? Colors.red : Colors.black),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        lunarDate.getShortDescription().split('月')[1], // 只显示农历日
                        style: TextStyle(
                          fontSize: 10,
                          color: isSameDay(_selectedDay, day) ? Colors.white70 : (isHoliday ? Colors.red.withValues(alpha: 0.8) : Colors.grey.shade600),
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
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day.day.toString(),
                        style: TextStyle(
                          color: isHoliday ? Colors.red : Colors.blue[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        lunarDate.getShortDescription().split('月')[1],
                        style: TextStyle(
                          fontSize: 10,
                          color: isHoliday ? Colors.red.withValues(alpha: 0.8) : Colors.blue.shade600,
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
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day.day.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        lunarDate.getShortDescription().split('月')[1],
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            outsideBuilder: (context, day, focusedDay) {
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
                          color: isHoliday ? Colors.red.withValues(alpha: 0.6) : Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        lunarDate.getShortDescription().split('月')[1],
                        style: TextStyle(
                          fontSize: 8,
                          color: isHoliday ? Colors.red.withValues(alpha: 0.4) : Colors.grey.shade300,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('日历'),
        actions: [
          // 订阅管理按钮
          IconButton(
            icon: const Icon(Icons.rss_feed),
            onPressed: _openSubscriptionManagement,
            tooltip: '订阅管理',
          ),
          // 导入导出按钮
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
            icon: const Icon(Icons.notifications),
            onPressed: _testNotification,
            tooltip: '测试通知',
          ),
          // 视图切换按钮
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
                    ? const Center(child: Text('请选择日期'))
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
                            return const Center(child: Text('当天无事件'));
                          }
                          return ListView.builder(
                            itemCount: events.length,
                            itemBuilder: (context, index) => GestureDetector(
                              onTap: () => _editEvent(events[index]),
                              child: Dismissible(
                                key: Key(events[index].id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(Icons.delete, color: Colors.white),
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
      floatingActionButton: (_currentViewIndex == 1 || _currentViewIndex == 2) ? FloatingActionButton(
        onPressed: _addNewEvent,
        child: const Icon(Icons.add),
      ) : null,
    );
  }
}
