import 'package:hive/hive.dart';

part 'calendar_subscription.g.dart';

// 网络订阅模型
@HiveType(typeId: 1)
class CalendarSubscription extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  String name;
  
  @HiveField(2)
  String url;
  
  @HiveField(3)
  DateTime lastSync;
  
  @HiveField(4)
  bool isEnabled;
  
  @HiveField(5)
  int syncIntervalHours;
  
  @HiveField(6)
  String? color;
  
  CalendarSubscription({
    required this.id,
    required this.name,
    required this.url,
    required this.lastSync,
    this.isEnabled = true,
    this.syncIntervalHours = 24,
    this.color,
  });
  
  // 检查是否需要同步
  bool needsSync() {
    return DateTime.now().difference(lastSync).inHours >= syncIntervalHours;
  }
  
  // 更新最后同步时间
  void updateLastSync() {
    lastSync = DateTime.now();
  }
}