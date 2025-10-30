import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
// 已移除未使用的导入 'package:icalendar/icalendar.dart'
import '../data/models/event.dart';
import '../data/models/calendar_subscription.dart';

class ImportExportManager {
  final Box<Event> eventsBox;
  
  ImportExportManager(this.eventsBox);
  
  // 导出所有事件为ICS格式
  Future<String> exportEventsToICS() async {
    final events = eventsBox.values.toList();
    
    // 构建ICS内容
    final icsContent = StringBuffer();
    icsContent.writeln('BEGIN:VCALENDAR');
    icsContent.writeln('VERSION:2.0');
    icsContent.writeln('PRODID:-//Calendar App//EN');
    
    for (final event in events) {
      icsContent.writeln(event.toICalendarString());
    }
    
    icsContent.writeln('END:VCALENDAR');
    return icsContent.toString();
  }
  
  // 导出为JSON格式（简单备份）
  Future<String> exportEventsToJSON() async {
    final events = eventsBox.values.toList();
    final eventsList = events.map((event) => {
      'id': event.id,
      'title': event.title,
      'startTime': event.startTime.toIso8601String(),
      'endTime': event.endTime.toIso8601String(),
      'location': event.location,
      'description': event.description,
      'isAllDay': event.isAllDay,
    }).toList();
    
    return jsonEncode({
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'events': eventsList,
    });
  }
  
  // 从ICS文件导入事件
  Future<int> importEventsFromICS(String icsContent) async {
    try {
      // 简化解析逻辑 - 实际项目中应使用更完善的ICS解析库
      // 这里仅作基本示例，解析VEVENT块
      final lines = icsContent.split('\n');
      int importedCount = 0;
      
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].trim() == 'BEGIN:VEVENT') {
          // 解析VEVENT块
          String? uid, title, location, description;
          DateTime? startTime, endTime;
          
          for (int j = i + 1; j < lines.length; j++) {
            final line = lines[j].trim();
            if (line == 'END:VEVENT') break;
            
            if (line.startsWith('UID:')) {
              uid = line.substring(4).trim();
            } else if (line.startsWith('SUMMARY:')) {
              title = line.substring(8).trim();
            } else if (line.startsWith('DTSTART:')) {
              final dateStr = line.substring(8).trim();
              startTime = _parseICalendarDateTime(dateStr);
            } else if (line.startsWith('DTEND:')) {
              final dateStr = line.substring(6).trim();
              endTime = _parseICalendarDateTime(dateStr);
            } else if (line.startsWith('LOCATION:')) {
              location = line.substring(9).trim();
            } else if (line.startsWith('DESCRIPTION:')) {
              description = line.substring(12).trim();
            }
          }
          
          if (title != null && startTime != null) {
            final event = Event(
              id: uid ?? DateTime.now().microsecondsSinceEpoch.toString(),
              title: title,
              startTime: startTime,
              endTime: endTime ?? startTime.add(const Duration(hours: 1)),
              location: location,
              description: description,
              isAllDay: false,
            );
            
            await eventsBox.add(event);
            importedCount++;
          }
        }
      }
      
      return importedCount;
    } catch (e) {
      throw Exception('ICS文件解析失败: $e');
    }
  }
  
  // 解析iCalendar日期时间格式
  DateTime _parseICalendarDateTime(String dateStr) {
    try {
      // 处理基本格式：yyyyMMddTHHmmss 或 yyyyMMdd
      if (dateStr.contains('T')) {
        // 带时间格式：yyyyMMddTHHmmss
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));
        final hour = int.parse(dateStr.substring(9, 11));
        final minute = int.parse(dateStr.substring(11, 13));
        final second = int.parse(dateStr.substring(13, 15));
        
        return DateTime(year, month, day, hour, minute, second);
      } else {
        // 仅日期格式：yyyyMMdd
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));
        
        return DateTime(year, month, day);
      }
    } catch (e) {
      return DateTime.now();
    }
  }
  
  // 从JSON文件导入事件
  Future<int> importEventsFromJSON(String jsonContent) async {
    try {
      final data = jsonDecode(jsonContent);
      final eventsList = data['events'] as List;
      int importedCount = 0;
      
      for (final eventData in eventsList) {
        final event = Event(
          id: eventData['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
          title: eventData['title'],
          startTime: DateTime.parse(eventData['startTime']),
          endTime: DateTime.parse(eventData['endTime']),
          location: eventData['location'],
          description: eventData['description'],
          isAllDay: eventData['isAllDay'] ?? false,
        );
        
        await eventsBox.add(event);
        importedCount++;
      }
      
      return importedCount;
    } catch (e) {
      throw Exception('JSON文件解析失败: $e');
    }
  }
}

// 网络订阅管理器
class SubscriptionManager {
  final Box<CalendarSubscription> subscriptionsBox;
  final Box<Event> eventsBox;
  
  SubscriptionManager(this.subscriptionsBox, this.eventsBox);
  
  // 添加订阅
  Future<void> addSubscription({
    required String name,
    required String url,
    int syncIntervalHours = 24,
    String? color,
  }) async {
    final subscription = CalendarSubscription(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      url: url,
      lastSync: DateTime(1970), // 初始化为很久以前，强制第一次同步
      syncIntervalHours: syncIntervalHours,
      color: color,
    );
    
    await subscriptionsBox.add(subscription);
  }
  
  // 删除订阅
  Future<void> deleteSubscription(String subscriptionId) async {
    final subscription = subscriptionsBox.values
        .firstWhere((sub) => sub.id == subscriptionId);
    await subscription.delete();
    
    // 删除该订阅的所有事件
    final eventsToDelete = eventsBox.values
        .where((event) => event.id.startsWith('sub_${subscription.id}_'))
        .toList();
    
    for (final event in eventsToDelete) {
      await event.delete();
    }
  }
  
  // 同步所有订阅
  Future<Map<String, int>> syncAllSubscriptions() async {
    final results = <String, int>{};
    
    for (final subscription in subscriptionsBox.values) {
      if (subscription.isEnabled && subscription.needsSync()) {
        try {
          final count = await syncSubscription(subscription);
          results[subscription.name] = count;
          subscription.updateLastSync();
          await subscription.save();
        } catch (e) {
          results[subscription.name] = -1; // 错误标记
        }
      }
    }
    
    return results;
  }
  
  // 同步单个订阅
  Future<int> syncSubscription(CalendarSubscription subscription) async {
    try {
      final response = await http.get(Uri.parse(subscription.url));
      
      if (response.statusCode == 200) {
        final icsContent = response.body;
        
        // 删除该订阅的旧事件
        final oldEvents = eventsBox.values
            .where((event) => event.id.startsWith('sub_${subscription.id}_'))
            .toList();
        
        for (final event in oldEvents) {
          await event.delete();
        }
        
        // 解析ICS并导入新事件
        final lines = icsContent.split('\n');
        int importedCount = 0;
        
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].trim() == 'BEGIN:VEVENT') {
            String? uid, title, location, description;
            DateTime? startTime, endTime;
            
            for (int j = i + 1; j < lines.length; j++) {
              final line = lines[j].trim();
              if (line == 'END:VEVENT') break;
              
              if (line.startsWith('UID:')) {
                uid = line.substring(4).trim();
              } else if (line.startsWith('SUMMARY:')) {
                title = line.substring(8).trim();
              } else if (line.startsWith('DTSTART:')) {
                final dateStr = line.substring(8).trim();
                startTime = _parseICalendarDateTime(dateStr);
              } else if (line.startsWith('DTEND:')) {
                final dateStr = line.substring(6).trim();
                endTime = _parseICalendarDateTime(dateStr);
              } else if (line.startsWith('LOCATION:')) {
                location = line.substring(9).trim();
              } else if (line.startsWith('DESCRIPTION:')) {
                description = line.substring(12).trim();
              }
            }
            
            if (title != null && startTime != null) {
              final event = Event(
                id: 'sub_${subscription.id}_${uid ?? DateTime.now().microsecondsSinceEpoch.toString()}',
                title: title,
                startTime: startTime,
                endTime: endTime ?? startTime.add(const Duration(hours: 1)),
                location: location,
                description: description,
                isAllDay: false,
              );
              
              await eventsBox.add(event);
              importedCount++;
            }
          }
        }
        
        return importedCount;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('同步失败: $e');
    }
  }
  
  // 解析iCalendar日期时间格式（复用现有方法）
  DateTime _parseICalendarDateTime(String dateStr) {
    try {
      // 处理基本格式：yyyyMMddTHHmmss 或 yyyyMMdd
      if (dateStr.contains('T')) {
        // 带时间格式：yyyyMMddTHHmmss
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));
        final hour = int.parse(dateStr.substring(9, 11));
        final minute = int.parse(dateStr.substring(11, 13));
        final second = int.parse(dateStr.substring(13, 15));
        
        return DateTime(year, month, day, hour, minute, second);
      } else {
        // 仅日期格式：yyyyMMdd
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));
        
        return DateTime(year, month, day);
      }
    } catch (e) {
      return DateTime.now();
    }
  }
}