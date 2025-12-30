import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart'; // 用于震动反馈
import '../../data/models/event.dart';
import '../../data/models/calendar_subscription.dart';
import '../../utils/import_export.dart';
import '../../utils/lunar_utils.dart';
import 'widgets/event_card.dart';
import 'widgets/year_view.dart';
import 'widgets/app_drawer.dart';
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
  int _currentViewIndex = 1; // 0: 年视图, 1: 月视图, 2: 周视图
  
  late final AnimationController _scaleController;
  late final AnimationController _opacityController;
  
  final Box<Event> _eventsBox = Hive.box<Event>('events');
  final Box<CalendarSubscription> _subscriptionsBox = Hive.box<CalendarSubscription>('subscriptions');
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  late final ImportExportManager _importExportManager;
  late final SubscriptionManager _subscriptionManager;

  // 内存缓存
  Map<DateTime, List<Event>> _eventsCache = {};
  
  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..value = 1.0;
    
    _opacityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..value = 1.0;
    
    _importExportManager = ImportExportManager(_eventsBox);
    _subscriptionManager = SubscriptionManager(_subscriptionsBox, _eventsBox);
    
    _updateEventsCache();
    _eventsBox.listenable().addListener(_updateEventsCache);
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _initNotifications();
        _scheduleEventReminders();
        _eventsBox.listenable().addListener(_scheduleEventReminders);
      } catch (e) {
        debugPrint('初始化通知服务时出错: $e');
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _autoSyncSubscriptions();
      } catch (e) {
        debugPrint('自动同步订阅时出错: $e');
      }
    });
  }

  void _updateEventsCache() {
    final Map<DateTime, List<Event>> newCache = {};
    for (final event in _eventsBox.values) {
      DateTime rangeDate = event.startTime;
      final endDate = event.endTime;
      DateTime normalize(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
      final normEnd = normalize(endDate);
      DateTime current = normalize(rangeDate);
      
      do {
        if (newCache[current] == null) newCache[current] = [];
        newCache[current]!.add(event);
        current = current.add(const Duration(days: 1));
      } while (current.isBefore(normEnd) || isSameDay(current, normEnd));
    }
    if (mounted) setState(() => _eventsCache = newCache);
  }

  List<Event> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _eventsCache[normalizedDay] ?? [];
  }

  Future<void> _initNotifications() async {
    try {
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
      const InitializationSettings settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
      await _notifications.initialize(settings);
      
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'event_reminder_channel', '事件提醒', importance: Importance.high,
      );
      await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
    } catch (e) { debugPrint('初始化通知失败: $e'); }
  }

  void _scheduleEventReminders() {
    try { _notifications.resolvePlatformSpecificImplementation; } catch (e) { return; }
    try {
      _notifications.cancelAll();
      for (final event in _eventsBox.values) {
        _scheduleEventReminder(event);
      }
    } catch (e) { debugPrint('设置提醒出错: $e'); }
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
          notificationId, '事件提醒：${event.title}', '事件将在${_getReminderText(reminderTime, eventStart)}开始',
          const NotificationDetails(android: AndroidNotificationDetails('event_reminder_channel', '事件提醒', importance: Importance.high), iOS: DarwinNotificationDetails()),
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

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedDay = now;
      _selectedDay = now;
      _currentViewIndex = 1;
    });
    HapticFeedback.mediumImpact();
  }
  
  void _quickAddEvent() {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => EventEditScreen(
          selectedDate: _selectedDay ?? DateTime.now(),
          onEventSaved: (newEvent) async {
            await _eventsBox.add(newEvent);
          },
          onEventDeleted: (_) {},
        )
      )
    );
  }

  Future<void> _autoSyncSubscriptions() async { try { await _subscriptionManager.syncAllSubscriptions(); } catch (e) {} }
  Future<void> _syncSubscriptions() async {
    try {
      final results = await _subscriptionManager.syncAllSubscriptions();
      if (mounted) {
        String message = '订阅同步完成：\n';
        results.forEach((name, count) => message += count >= 0 ? '$name: $count 个事件\n' : '$name: 同步失败\n');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('同步失败: $e'))); }
  }
  void _openSubscriptionManagement() { Navigator.push(context, MaterialPageRoute(builder: (context) => SubscriptionManagementScreen(subscriptionManager: _subscriptionManager))).then((_) => _updateEventsCache()); }
  Future<void> _exportEventsToICS() async { try { final ics = await _importExportManager.exportEventsToICS(); await Clipboard.setData(ClipboardData(text: ics)); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ICS已复制'))); } catch(e){} }
  Future<void> _exportEventsToJSON() async { try { final json = await _importExportManager.exportEventsToJSON(); await Clipboard.setData(ClipboardData(text: json)); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON已复制'))); } catch(e){} }
  Future<void> _importEventsFromICS() async { try { final data = await Clipboard.getData('text/plain'); if(data?.text!=null) { await _importExportManager.importEventsFromICS(data!.text!); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导入完成'))); } } catch(e){} }
  Future<void> _importEventsFromJSON() async { try { final data = await Clipboard.getData('text/plain'); if(data?.text!=null) { await _importExportManager.importEventsFromJSON(data!.text!); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导入完成'))); } } catch(e){} }
  Future<void> _testNotification() async { try { await _notifications.show(9999, '测试通知', '通知功能正常', const NotificationDetails(android: AndroidNotificationDetails('event_reminder_channel', '事件提醒', importance: Importance.high), iOS: DarwinNotificationDetails())); } catch(e){} }

  @override
  void dispose() {
    _scaleController.dispose();
    _opacityController.dispose();
    _eventsBox.listenable().removeListener(_updateEventsCache);
    super.dispose();
  }
  
  void _handleViewChange(int newIndex) {
    if (newIndex == _currentViewIndex) return;
    HapticFeedback.selectionClick(); 
    _opacityController.reverse().then((_) {
      setState(() {
        _currentViewIndex = newIndex;
        if (newIndex == 0) _focusedDay = DateTime.now();
      });
      _scaleController.value = 0.8;
      _scaleController.forward();
      _opacityController.forward();
    });
  }
  
  void _handleMonthSelected(DateTime selectedMonth) {
    final firstDay = DateTime(2000);
    _focusedDay = selectedMonth.isBefore(firstDay) ? firstDay : selectedMonth;
    _handleViewChange(1);
  }
  
  void _handleDoubleTapDay(DateTime day) {
    HapticFeedback.mediumImpact(); 
    Navigator.push(context, MaterialPageRoute(builder: (context) => StockMarketDataScreen(selectedDate: day, eventsBox: _eventsBox)));
  }

  void _editEvent(Event event) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => EventEditScreen(event: event, onEventSaved: (updated) {
      event.save(); 
    }, onEventDeleted: (deleted) { deleted.delete(); })));
  }

  void _deleteEvent(Event event) {
    HapticFeedback.heavyImpact(); 
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('删除事件'), content: Text('确定要删除事件"${event.title}"吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        TextButton(onPressed: () { event.delete(); Navigator.pop(context); }, child: Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error))),
      ],
    ));
  }

  Widget _getCurrentView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    switch (_currentViewIndex) {
      case 0: return YearView(focusedDay: _focusedDay, onMonthSelected: _handleMonthSelected);
      case 1: return _buildMonthView(colorScheme, theme);
      case 2: return _buildWeekView(colorScheme, theme);
      default: return Container();
    }
  }

  Widget _buildMonthView(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: colorScheme.shadow.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: TableCalendar(
        locale: 'zh_CN', 
        daysOfWeekHeight: 30,
        shouldFillViewport: true,
        firstDay: DateTime(2000), lastDay: DateTime(2050), focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: CalendarFormat.month, availableCalendarFormats: const {CalendarFormat.month: '月'},
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(color: colorScheme.secondaryContainer, shape: BoxShape.circle),
          todayTextStyle: TextStyle(color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold, fontSize: 16),
          selectedDecoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
          selectedTextStyle: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          weekendTextStyle: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w600),
          defaultTextStyle: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500, fontSize: 16),
          outsideTextStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.5), fontSize: 14),
          markersMaxCount: 3,
          markersAnchor: 0.8,
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false, titleCentered: true,
          titleTextStyle: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
          leftChevronIcon: Container(decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, shape: BoxShape.circle), child: Icon(Icons.chevron_left, color: colorScheme.onSurfaceVariant, size: 24)),
          rightChevronIcon: Container(decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, shape: BoxShape.circle), child: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 24)),
          decoration: BoxDecoration(color: colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(weekdayStyle: TextStyle(color: colorScheme.secondary, fontWeight: FontWeight.w600), weekendStyle: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w600)),
        
        onDaySelected: (selectedDay, focusedDay) { 
          if (!isSameDay(_selectedDay, selectedDay)) {
            HapticFeedback.selectionClick(); 
            setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
          }
        },
        onPageChanged: (focusedDay) {
          HapticFeedback.lightImpact(); 
          _focusedDay = focusedDay;
        },
        
        eventLoader: _getEventsForDay, 
        
        calendarBuilders: CalendarBuilders(
          dowBuilder: (context, date) {
            final weekday = date.weekday % 7; final weekdays = ['日', '一', '二', '三', '四', '五', '六'];
            return Center(child: Text(weekdays[weekday], style: TextStyle(color: weekday == 0 || weekday == 6 ? colorScheme.error : colorScheme.onSurface.withOpacity(0.8), fontWeight: FontWeight.bold)));
          },
          defaultBuilder: (context, day, focusedDay) => _buildDayCell(day, colorScheme, false),
          todayBuilder: (context, day, focusedDay) => _buildDayCell(day, colorScheme, false, isToday: true),
          
          markerBuilder: (context, day, events) {
            if (events.isEmpty) return null;
            
            // [修复] 强制转换为 List<Event>，解决 title 为空的安全检查报错
            final safeEvents = events.cast<Event>();
            
            return Positioned(
              bottom: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: safeEvents.take(4).map((event) {
                  // 默认颜色
                  Color dotColor = colorScheme.secondary; 
                  
                  // 根据标题关键词变色
                  final title = event.title;
                  if (title.contains('买') || title.contains('入') || title.contains('加')) {
                    dotColor = Colors.red; 
                  } else if (title.contains('卖') || title.contains('出') || title.contains('止')) {
                    dotColor = Colors.green; 
                  } else if (title.contains('盈') || title.contains('赚')) {
                    dotColor = Colors.red.shade700; 
                  } else if (title.contains('亏') || title.contains('损')) {
                    dotColor = Colors.green.shade700; 
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: 6, 
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSameDay(_selectedDay, day) 
                          ? colorScheme.onPrimary 
                          : dotColor, 
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWeekView(ColorScheme colorScheme, ThemeData theme) {
    return TableCalendar(
      locale: 'zh_CN', daysOfWeekHeight: 30, shouldFillViewport: true,
      firstDay: DateTime(2000), lastDay: DateTime(2050), focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      calendarFormat: CalendarFormat.week, availableCalendarFormats: const {CalendarFormat.month: '月', CalendarFormat.week: '周'},
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(color: colorScheme.secondaryContainer, shape: BoxShape.circle),
        selectedDecoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
        weekendTextStyle: TextStyle(color: colorScheme.error),
        defaultTextStyle: TextStyle(color: colorScheme.onSurface),
        todayTextStyle: TextStyle(color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold),
        selectedTextStyle: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
      ),
      headerStyle: HeaderStyle(formatButtonVisible: false, titleCentered: true, titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold), leftChevronIcon: Icon(Icons.chevron_left, color: colorScheme.onSurface), rightChevronIcon: Icon(Icons.chevron_right, color: colorScheme.onSurface)),
      
      eventLoader: _getEventsForDay,
      
      onDaySelected: (selectedDay, focusedDay) {
        if (!isSameDay(_selectedDay, selectedDay)) {
          HapticFeedback.selectionClick();
          setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
        }
      },
      onPageChanged: (focusedDay) {
        HapticFeedback.lightImpact();
        _focusedDay = focusedDay;
      },
      
      calendarBuilders: CalendarBuilders(
          dowBuilder: (context, date) {
            final weekday = date.weekday % 7; final weekdays = ['日', '一', '二', '三', '四', '五', '六'];
            return Center(child: Text(weekdays[weekday], style: TextStyle(color: weekday == 0 || weekday == 6 ? colorScheme.error : colorScheme.onSurface.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 12)));
          },
        defaultBuilder: (context, day, focusedDay) => _buildDayCell(day, colorScheme, true),
        todayBuilder: (context, day, focusedDay) => _buildDayCell(day, colorScheme, true, isToday: true),
        selectedBuilder: (context, day, focusedDay) => _buildDayCell(day, colorScheme, true, isSelected: true),
        
        markerBuilder: (context, day, events) {
          if (events.isEmpty) return null;
          
          // [修复] 强制类型转换
          final safeEvents = events.cast<Event>();
          
          Color dotColor = colorScheme.secondary;
          for (var event in safeEvents) {
             final t = event.title;
             if (t.contains('买') || t.contains('入')) { dotColor = Colors.red; break; }
             if (t.contains('卖') || t.contains('出')) { dotColor = Colors.green; break; }
          }

          return Positioned(
            bottom: 4, 
            child: Container(
              width: 6, 
              height: 6, 
              decoration: BoxDecoration(
                shape: BoxShape.circle, 
                color: isSameDay(_selectedDay, day) ? colorScheme.onPrimary : dotColor
              )
            )
          );
        },
      ),
    );
  }

  Widget _buildDayCell(DateTime day, ColorScheme colorScheme, bool isWeekView, {bool isToday = false, bool isSelected = false}) {
    bool isHoliday = LunarUtils.isHoliday(day);
    bool isRestDay = day.weekday == 6 || day.weekday == 7 || isHoliday;
    
    final lunarDate = LunarUtils.solarToLunar(day);
    Color textColor;
    if (isSelected) textColor = colorScheme.onPrimary;
    else if (isToday) textColor = isHoliday ? colorScheme.error : colorScheme.primary;
    else textColor = isHoliday ? colorScheme.error : colorScheme.onSurface;

    return GestureDetector(
      onDoubleTap: () => _handleDoubleTapDay(day),
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.all(2), alignment: Alignment.center,
            decoration: isSelected 
              ? BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle) 
              : (isToday ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colorScheme.primary, width: 2), color: colorScheme.secondaryContainer) : null),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(day.day.toString(), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(lunarDate.getShortDescription().split('月')[1], style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7))),
              ],
            ),
          ),
          if (isRestDay && !isSelected && !isToday)
            Positioned(right: 8, top: 8, child: Text('休', style: TextStyle(fontSize: 8, color: colorScheme.outline.withOpacity(0.6)))),
          if (isHoliday && !isSelected && !isToday && !isRestDay) 
             Positioned(right: 8, top: 8, child: Container(width: 4, height: 4, decoration: BoxDecoration(color: colorScheme.error, shape: BoxShape.circle))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      drawer: AppDrawer(
        onSubscriptionTap: _openSubscriptionManagement,
        onTestNotificationTap: _testNotification,
        onImportExportTap: (value) {
          if (value == 'export_ics') _exportEventsToICS();
          else if (value == 'export_json') _exportEventsToJSON();
          else if (value == 'import_ics') _importEventsFromICS();
          else if (value == 'import_json') _importEventsFromJSON();
        },
      ),
      
      appBar: AppBar(
        title: const Text('日程'),
        centerTitle: true,
        
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: SizedBox(
              width: 300,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(value: 0, label: Text('年')),
                  ButtonSegment<int>(value: 1, label: Text('月')),
                  ButtonSegment<int>(value: 2, label: Text('周')),
                ],
                selected: {_currentViewIndex},
                onSelectionChanged: (Set<int> newSelection) {
                  _handleViewChange(newSelection.first);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.standard,
                  shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                ),
              ),
            ),
          ),
        ),
        
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: '回到今天',
            onPressed: _jumpToToday,
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: '同步所有订阅',
            onPressed: _syncSubscriptions,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _getCurrentView()),
          if (_currentViewIndex == 1 || _currentViewIndex == 2)
            SizedBox(
              height: screenHeight * 0.25,
              child: _selectedDay == null
                  ? Center(child: Text('请选择日期', style: TextStyle(color: colorScheme.onSurfaceVariant)))
                  : ValueListenableBuilder(
                      valueListenable: _eventsBox.listenable(),
                      builder: (context, box, _) {
                        final events = _getEventsForDay(_selectedDay!).cast<Event>();
                        if (events.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center, 
                              children: [
                                Icon(Icons.event_available, size: 48, color: colorScheme.outline.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                Text('当天无事件', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                                const SizedBox(height: 16),
                                FilledButton.tonalIcon(
                                  onPressed: _quickAddEvent,
                                  icon: const Icon(Icons.add),
                                  label: const Text('添加日程'),
                                )
                              ]
                            )
                          );
                        }
                        return ListView.builder(
                          itemCount: events.length,
                          itemBuilder: (context, index) => GestureDetector(
                            onTap: () => _editEvent(events[index]),
                            child: Dismissible(
                              key: Key(events[index].id),
                              direction: DismissDirection.endToStart,
                              background: Container(color: colorScheme.errorContainer, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: Icon(Icons.delete, color: colorScheme.onErrorContainer)),
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
    );
  }
}