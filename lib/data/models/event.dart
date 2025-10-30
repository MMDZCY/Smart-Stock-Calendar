import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

part 'event.g.dart';  // 由Hive生成的适配器代码

@HiveType(typeId: 0)
class Event extends HiveObject {
  // 事件ID（对应RFC5545的UID）
  @HiveField(0)
  final String id;

  // 事件标题（对应RFC5545的SUMMARY）
  @HiveField(1)
  String title;

  // 开始时间（对应RFC5545的DTSTART）
  @HiveField(2)
  DateTime startTime;

  // 结束时间（对应RFC5545的DTEND）
  @HiveField(3)
  DateTime endTime;

  // 地点（对应RFC5545的LOCATION）
  @HiveField(4)
  String? location;

  // 描述（对应RFC5545的DESCRIPTION）
  @HiveField(5)
  String? description;

  // 是否全天事件
  @HiveField(6)
  bool isAllDay;

  Event({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.location,
    this.description,
    this.isAllDay = false,
  });

  // 转换为RFC5545兼容的VEVENT字符串（简化版）
  String toICalendarString() {
    final dateFormat = DateFormat("yyyyMMdd'T'HHmmss");
    return '''BEGIN:VEVENT
UID:$id
SUMMARY:$title
DTSTART:${dateFormat.format(startTime)}
DTEND:${dateFormat.format(endTime)}
${location != null ? 'LOCATION:$location' : ''}
${description != null ? 'DESCRIPTION:$description' : ''}
END:VEVENT''';
  }

  // 从ICS解析（后续可扩展）
  static Event fromICalendar(String icsContent) {
    // 实际项目中需使用icalendar库解析，这里仅作示例
    return Event(
      id: '',
      title: '',
      startTime: DateTime.now(),
      endTime: DateTime.now(),
    );
  }
}
