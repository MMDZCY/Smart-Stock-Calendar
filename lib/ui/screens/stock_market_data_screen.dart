import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import '../../data/models/event.dart';
import '../../utils/lunar_utils.dart'; // [新增] 引入日期工具类用于判断节假日

// AkShare API服务类
class AkShareApiService {
  final String baseUrl;
  final http.Client client;

  AkShareApiService({
    this.baseUrl = 'http://139.196.103.184:8000',
    http.Client? client,
  }) : client = client ?? http.Client();

  Future<List<Map<String, dynamic>>> getIndexData(DateTime date) async {
    try {
      String dateStr = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
      final response = await client.get(
        Uri.parse('$baseUrl/api/index?date=$dateStr'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('data') && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('获取指数数据失败: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getIndustryData(DateTime date) async {
    try {
      String dateStr = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
      final response = await client.get(
        Uri.parse('$baseUrl/api/industry?date=$dateStr'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('data') && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('获取行业板块数据失败: $e');
      return [];
    }
  }

  Future<bool> checkServiceAvailability() async {
    try {
      final response = await client.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    client.close();
  }
}

class StockMarketDataScreen extends StatefulWidget {
  final DateTime selectedDate;
  final Box<Event>? eventsBox;

  const StockMarketDataScreen({
    super.key, 
    required this.selectedDate,
    this.eventsBox,
  });

  @override
  State<StockMarketDataScreen> createState() => _StockMarketDataScreenState();
}

class _StockMarketDataScreenState extends State<StockMarketDataScreen> {
  List<Map<String, dynamic>> _majorIndices = [];
  List<Map<String, dynamic>> _hotSectors = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  bool _dataFetchFailed = false;
  final String _errorMessage = '数据获取失败，请稍后重试';
  late AkShareApiService _akShareApiService;
  
  Box<Event>? _eventsBox;
  List<Event> _todayEvents = [];

  @override
  void initState() {
    super.initState();
    _akShareApiService = AkShareApiService(baseUrl: 'http://139.196.103.184:8000');
    _eventsBox = widget.eventsBox ?? Hive.box<Event>('events');
    _loadTodayEvents();
    _initializeBasicData();
    _loadStockData();
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _akShareApiService.dispose();
    super.dispose();
  }

  void _loadTodayEvents() {
    if (_eventsBox == null) return;
    final date = widget.selectedDate;
    final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    _todayEvents = _eventsBox!.values
        .where((event) => '${event.startTime.year}-${event.startTime.month.toString().padLeft(2, '0')}-${event.startTime.day.toString().padLeft(2, '0')}' == dateString)
        .toList();
    if (mounted) setState(() {});
  }
  
  Future<void> _addNewEvent() async {
    if (_eventsBox == null) return;
    final result = await Navigator.pushNamed(
      context, '/event_edit', arguments: {'selectedDate': widget.selectedDate},
    );
    if (result == true && mounted) _loadTodayEvents();
  }
  
  Future<void> _editEvent(Event event) async {
    final result = await Navigator.pushNamed(
      context, '/event_edit', arguments: {'event': event},
    );
    if (result == true && mounted) _loadTodayEvents();
  }
  
  Future<void> _deleteEvent(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除事件"${event.title}"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    
    if (confirmed == true && _eventsBox != null) {
      await event.delete();
      _loadTodayEvents();
    }
  }

  void _initializeBasicData() {
    if (mounted) {
      setState(() {
        _majorIndices = [
          {'name': '上证指数', 'value': '加载中...', 'change': '--', 'changeColor': Colors.grey},
          {'name': '深证成指', 'value': '加载中...', 'change': '--', 'changeColor': Colors.grey},
          {'name': '创业板指', 'value': '加载中...', 'change': '--', 'changeColor': Colors.grey},
        ];
        _hotSectors = [{'name': '数据获取中...', 'change': '--', 'changeColor': Colors.grey, 'type': 'loading'}];
        _isLoading = false; 
        _dataFetchFailed = false;
      });
    }
  }

  Future<void> _loadStockData() async {
    try {
      _majorIndices = [];
      _hotSectors = [];
      _dataFetchFailed = false;
      await _fetchRealTimeStockData();
    } catch (e) {
      _handleDataFetchFailure();
    }
  }
  
  void _handleDataFetchFailure() {
    _dataFetchFailed = true;
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchRealTimeStockData() async {
    try {
      if (mounted) setState(() => _dataFetchFailed = false);
      
      bool isServiceAvailable = await _akShareApiService.checkServiceAvailability();
      if (!isServiceAvailable) {
        await Future.delayed(const Duration(seconds: 1));
        isServiceAvailable = await _akShareApiService.checkServiceAvailability();
      }
      
      final results = await Future.wait([
        _fetchIndicesFromAkShare(widget.selectedDate),
        _fetchSectorsDataFromAkShare(widget.selectedDate),
      ]);
      
      if (!results[0] && !results[1]) _handleDataFetchFailure();
    } catch (e) {
      _handleDataFetchFailure();
    }
  }

  void _initializeIndices() {
    if (mounted) {
      setState(() {
        _majorIndices = [
          {'name': '上证指数', 'value': '0.00', 'change': '0.00%', 'changeColor': Colors.black},
          {'name': '深证成指', 'value': '0.00', 'change': '0.00%', 'changeColor': Colors.black},
          {'name': '创业板指', 'value': '0.00', 'change': '0.00%', 'changeColor': Colors.black},
        ];
      });
    }
  }

  Future<bool> _fetchIndicesFromAkShare(DateTime targetDate) async {
    try {
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      DateTime checkDate = DateTime(targetDate.year, targetDate.month, targetDate.day);
      
      if (checkDate.isAfter(today)) {
        if (mounted) {
          setState(() {
            _majorIndices = [
              {'name': '上证指数', 'value': '----', 'change': '----', 'changeColor': Colors.grey},
              {'name': '深证成指', 'value': '----', 'change': '----', 'changeColor': Colors.grey},
              {'name': '创业板指', 'value': '----', 'change': '----', 'changeColor': Colors.grey},
            ];
          });
        }
        return true;
      }
      
      _initializeIndices();
      List<Map<String, dynamic>> indexData = await _akShareApiService.getIndexData(targetDate);
      
      if (indexData.isNotEmpty) {
        for (var data in indexData) {
          String name = data['name'] ?? '';
          String value = data['close']?.toStringAsFixed(2) ?? '0.00';
          double changePercent = data['change_percent'] ?? 0.0;
          
          int index = -1;
          if (name.contains('上证')) index = 0;
          else if (name.contains('深证')) index = 1;
          else if (name.contains('创业板')) index = 2;
          
          if (index != -1 && double.tryParse(value) != null) {
            if (mounted) {
              setState(() {
                _majorIndices[index]['name'] = name;
                _majorIndices[index]['value'] = value;
                _majorIndices[index]['change'] = '${changePercent > 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%';
                _majorIndices[index]['changeColor'] = changePercent > 0 ? Colors.red : Colors.green;
              });
            }
          }
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _fetchSectorsDataFromAkShare(DateTime targetDate) async {
    try {
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      DateTime checkDate = DateTime(targetDate.year, targetDate.month, targetDate.day);
      
      if (checkDate.isAfter(today)) {
        if (mounted) {
          setState(() {
            _hotSectors = [
              {'name': '未来日期无数据', 'change': '--', 'changeColor': Colors.grey, 'type': 'future'},
            ];
          });
        }
        return true;
      }
      
      List<Map<String, dynamic>> industryData = await _akShareApiService.getIndustryData(targetDate);
      
      if (industryData.isNotEmpty) {
        industryData.sort((a, b) => (b['change_percent'] ?? 0.0).compareTo(a['change_percent'] ?? 0.0));
        
        List<Map<String, dynamic>> sectors = [];
        for (int i = 0; i < industryData.length && i < 5; i++) {
          var sector = industryData[i];
          double changePercent = sector['change_percent'] ?? 0.0;
          sectors.add({
            'name': sector['name'] ?? '未知',
            'change': '${changePercent > 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
            'changeColor': changePercent > 0 ? Colors.red : Colors.green,
            'type': 'top_performer',
          });
        }
        
        for (int i = industryData.length - 5; i < industryData.length && i >= 0; i++) {
          if (i < 0) continue; 
          var sector = industryData[i];
          double changePercent = sector['change_percent'] ?? 0.0;
          sectors.add({
            'name': sector['name'] ?? '未知',
            'change': '${changePercent > 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
            'changeColor': changePercent > 0 ? Colors.red : Colors.green,
            'type': 'worst_performer',
          });
        }
        
        if (mounted) setState(() => _hotSectors = sectors);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  String _getWeekday(int weekday) {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return days[weekday - 1];
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    String formattedDate = "${widget.selectedDate.year}年${widget.selectedDate.month}月${widget.selectedDate.day}日";
    String weekday = _getWeekday(widget.selectedDate.weekday);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('市场概览'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: colorScheme.primary),
            tooltip: '刷新数据',
            onPressed: () {
              setState(() {
                _isLoading = true;
                _dataFetchFailed = false;
              });
              _loadStockData();
            },
          ),
        ],
      ),
      body: _dataFetchFailed ? _buildErrorView(colorScheme) : _buildContent(formattedDate, weekday, theme, colorScheme),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewEvent,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildErrorView(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: colorScheme.error),
          const SizedBox(height: 16),
          Text(_errorMessage, style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              setState(() { _isLoading = true; _dataFetchFailed = false; });
              _loadStockData();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(String formattedDate, String weekday, ThemeData theme, ColorScheme colorScheme) {
    // [修改] 增加交易日判断逻辑
    bool isWeekend = widget.selectedDate.weekday == 6 || widget.selectedDate.weekday == 7;
    bool isHoliday = LunarUtils.isHoliday(widget.selectedDate);
    // 简单判断：非周末且非节假日为交易日
    // (注：这不包含调休补班的情况，但已足够准确覆盖大部分场景)
    bool isTradingDay = !isWeekend && !isHoliday;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.calendar_today, color: colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text("星期$weekday", style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                        const SizedBox(width: 12),
                        
                        // [修改] 动态显示 交易日/休市
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isTradingDay 
                                ? colorScheme.secondaryContainer // 交易日：高亮
                                : colorScheme.surfaceDim,        // 休市：灰色
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isTradingDay) ...[
                                Icon(Icons.access_time, size: 12, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                isTradingDay ? "交易日" : "休市", 
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isTradingDay 
                                      ? colorScheme.onSecondaryContainer 
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                )
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        Text(" 主要指数", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: _majorIndices.map((indexData) {
            Color changeColor = indexData['changeColor'] == Colors.red 
                ? colorScheme.error 
                : Colors.green;
            
            return Expanded(
              child: Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Column(
                    children: [
                      Text(indexData['name'], style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Text(
                        indexData['value'], 
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 4),
                      Text(
                        indexData['change'],
                        style: TextStyle(color: changeColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
        Text(" 热门概念板块", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_hotSectors.isEmpty && !_dataFetchFailed)
           const Center(child: CircularProgressIndicator())
        else ...[
           if (_hotSectors.any((s) => s['type'] == 'top_performer')) ...[
              _buildSectionHeader("涨幅榜", Icons.trending_up, colorScheme.error, theme),
              ..._hotSectors.where((s) => s['type'] == 'top_performer').map((s) => _buildSectorItem(s, theme, colorScheme)),
              const SizedBox(height: 16),
           ],
           if (_hotSectors.any((s) => s['type'] == 'worst_performer')) ...[
              _buildSectionHeader("跌幅榜", Icons.trending_down, Colors.green, theme),
              ..._hotSectors.where((s) => s['type'] == 'worst_performer').map((s) => _buildSectorItem(s, theme, colorScheme)),
           ],
        ],

        const SizedBox(height: 24),
        Text(" 当日事件", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_todayEvents.isEmpty)
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_available, size: 48, color: colorScheme.outlineVariant),
                    const SizedBox(height: 8),
                    Text("暂无事件", style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          )
        else
          ..._todayEvents.map((event) => Card(
            elevation: 0,
            color: colorScheme.surfaceContainer,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: colorScheme.primaryContainer, shape: BoxShape.circle),
                child: Icon(Icons.event, size: 20, color: colorScheme.onPrimaryContainer),
              ),
              title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                "${event.startTime.hour.toString().padLeft(2, '0')}:${event.startTime.minute.toString().padLeft(2, '0')} ${event.description ?? ''}",
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _editEvent(event),
              ),
              onTap: () => _editEvent(event),
            ),
          )),
          
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(title, style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSectorItem(Map<String, dynamic> sector, ThemeData theme, ColorScheme colorScheme) {
    Color changeColor = sector['changeColor'] == Colors.red ? colorScheme.error : Colors.green;
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12)
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(sector['name'], style: theme.textTheme.bodyLarge),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: changeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sector['change'],
                style: TextStyle(color: changeColor, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}