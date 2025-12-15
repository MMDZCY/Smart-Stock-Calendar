import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import '../../data/models/event.dart';

// AkShare API服务类
class AkShareApiService {
  final String baseUrl;
  final http.Client client;

  AkShareApiService({
    this.baseUrl = 'http://139.196.103.184:8000',
    http.Client? client,
  }) : client = client ?? http.Client();

  // 获取指数数据
  Future<List<Map<String, dynamic>>> getIndexData(DateTime date) async {
    try {
      String dateStr = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
      final response = await client.get(
        Uri.parse('$baseUrl/api/index?date=$dateStr'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('data') && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('获取指数数据失败: $e');
      return [];
    }
  }

  // 获取行业板块数据
  Future<List<Map<String, dynamic>>> getIndustryData(DateTime date) async {
    try {
      String dateStr = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
      final response = await client.get(
        Uri.parse('$baseUrl/api/industry?date=$dateStr'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('data') && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('获取行业板块数据失败: $e');
      return [];
    }
  }






  // 检查服务是否可用
  Future<bool> checkServiceAvailability() async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('检查akshare服务可用性失败: $e');
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
  String _errorMessage = '数据获取失败，请稍后重试';
  // 添加akshare API服务实例
  late AkShareApiService _akShareApiService;
  
  // 事件管理相关状态
  Box<Event>? _eventsBox;
  List<Event> _todayEvents = [];

  @override
  void initState() {
    super.initState();
    
    // 初始化akshare API服务
    _akShareApiService = AkShareApiService(
      baseUrl: 'http://139.196.103.184:8000',
    );
    
    // 初始化事件管理
    _eventsBox = widget.eventsBox ?? Hive.box<Event>('events');
    _loadTodayEvents();
    
    // 初始化基础数据
    _initializeBasicData();
    _loadStockData();
  }
  
  @override
  void dispose() {
    // 取消定时器，防止内存泄漏和setState在dispose后调用
    _refreshTimer?.cancel();
    // 关闭akshare API服务连接
    _akShareApiService.dispose();
    super.dispose();
  }




  // 加载当日事件
  void _loadTodayEvents() {
    if (_eventsBox == null) return;
    
    final date = widget.selectedDate;
    final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    _todayEvents = _eventsBox!.values
        .where((event) => 
            '${event.startTime.year}-${event.startTime.month.toString().padLeft(2, '0')}-${event.startTime.day.toString().padLeft(2, '0')}' == dateString)
        .toList();
        
    if (mounted) {
      setState(() {});
    }
  }
  
  // 添加新事件
  Future<void> _addNewEvent() async {
    if (_eventsBox == null) {
      print('错误：事件箱未初始化');
      return;
    }
    
    try {
      print('打开事件编辑页面...');
      final result = await Navigator.pushNamed(
        context,
        '/event_edit',
        arguments: {'selectedDate': widget.selectedDate},
      );
      
      print('事件编辑页面返回结果: $result');
      
      if (result == true && mounted) {
        _loadTodayEvents();
      }
    } catch (e) {
      print('添加事件时出错: $e');
      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加事件失败: $e')),
        );
      }
    }
  }
  
  // 编辑事件
  Future<void> _editEvent(Event event) async {
    final result = await Navigator.pushNamed(
      context,
      '/event_edit',
      arguments: {'event': event},
    );
    
    if (result == true && mounted) {
      _loadTodayEvents();
    }
  }
  
  // 删除事件
  Future<void> _deleteEvent(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除事件"${event.title}"吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
    
    if (confirmed == true && _eventsBox != null) {
      await event.delete();
      _loadTodayEvents();
    }
  }

  // 初始化基础数据，显示页面框架
  void _initializeBasicData() {
    if (mounted) {
      setState(() {
        _majorIndices = [
          {'name': '上证指数', 'value': '加载中...', 'change': '--', 'changeColor': Colors.grey},
          {'name': '深证成指', 'value': '加载中...', 'change': '--', 'changeColor': Colors.grey},
          {'name': '创业板指', 'value': '加载中...', 'change': '--', 'changeColor': Colors.grey},
        ];
        _hotSectors = [
          {'name': '概念板块数据获取中...', 'change': '--', 'changeColor': Colors.grey, 'type': 'loading'},
        ];
        _isLoading = false; // 显示页面框架，不显示全屏加载
        _dataFetchFailed = false;
      });
    }
  }

  Future<void> _loadStockData() async {
    try {
      // 初始化空数据
      _majorIndices = List.empty(growable: true);
      _hotSectors = List.empty(growable: true);
      _dataFetchFailed = false;
      
      // 尝试获取真实数据
      await _fetchRealTimeStockData();
    } catch (e) {
      print('加载股票数据失败: $e');
      _handleDataFetchFailure();
    }
  }
  
  void _handleDataFetchFailure() {
    _dataFetchFailed = true;
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchRealTimeStockData() async {
    bool indicesSuccess = false;
    bool sectorsSuccess = false;
    
    try {
      // 更新为加载状态，但不在全屏显示（只更新部分数据）
      if (mounted) {
        setState(() {
          _dataFetchFailed = false;
        });
      }
      
      // 检查akshare服务是否可用
      bool isServiceAvailable = await _akShareApiService.checkServiceAvailability();
      if (!isServiceAvailable) {
        print('⚠️ AkShare服务不可用');
        print('💡 请确保Python服务已在开发机上启动');
        print('💡 命令: python lib\\akshare_api_server.py');
        print('💡 并确保移动设备和开发机在同一网络下');
        // 移动设备无法自动启动Python服务
        // await _akShareApiService._startPythonServer();
        // 再次检查服务是否可用（给手动启动的时间）
        await Future.delayed(Duration(seconds: 3));
        isServiceAvailable = await _akShareApiService.checkServiceAvailability();
      }
      
      
      
      // 并行获取指数和板块数据
      final results = await Future.wait([
        _fetchIndicesFromAkShare(widget.selectedDate),
        _fetchSectorsDataFromAkShare(widget.selectedDate),
      ]);
      
      indicesSuccess = results[0];
      sectorsSuccess = results[1];
      
      // 如果所有数据获取都失败，标记为失败
      if (!indicesSuccess && !sectorsSuccess) {
        _handleDataFetchFailure();
      }
    } catch (e) {
      _handleDataFetchFailure();
    }
  }

  
  // 初始化指数列表
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



  // 使用akshare API获取指数数据
  Future<bool> _fetchIndicesFromAkShare(DateTime targetDate) async {
    try {
      // 检查是否是未来日期
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      DateTime checkDate = DateTime(targetDate.year, targetDate.month, targetDate.day);
      
      if (checkDate.isAfter(today)) {
        print('⚠️ ${targetDate.year}-${targetDate.month}-${targetDate.day} 是未来日期，显示----');
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
      
      DateTime actualDate = targetDate;
      
      print('📊 正在尝试使用AkShare API获取三大指数数据...');
      _initializeIndices();
      
      // 调用akshare API获取指数数据
      List<Map<String, dynamic>> indexData = await _akShareApiService.getIndexData(actualDate);
      
      if (indexData.isNotEmpty) {
        // 解析指数数据
        for (var data in indexData) {
          String name = data['name'] ?? '';
          String value = data['close']?.toStringAsFixed(2) ?? '0.00';
          double changePercent = data['change_percent'] ?? 0.0;
          
          // 确定指数在列表中的位置
          int index = -1;
          if (name.contains('上证')) index = 0;
          else if (name.contains('深证')) index = 1;
          else if (name.contains('创业板')) index = 2;
          
          if (index != -1 && double.tryParse(value) != null && double.parse(value) > 0) {
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
        print('✅ 三大指数数据获取成功');
        return true;
      } else {
        print('❌ 三大指数数据获取失败，返回空数据');
        return false;
      }
    } catch (e) {
      print('❌ 指数数据获取异常: $e');
      return false;
    }
  }

  
  // 使用akshare API获取板块数据
  Future<bool> _fetchSectorsDataFromAkShare(DateTime targetDate) async {
    try {
      // 检查是否是未来日期
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      DateTime checkDate = DateTime(targetDate.year, targetDate.month, targetDate.day);
      
      if (checkDate.isAfter(today)) {
        print('⚠️ ${targetDate.year}-${targetDate.month}-${targetDate.day} 是未来日期，显示----');
        if (mounted) {
          setState(() {
            _hotSectors = [
              {'name': '概念板块1', 'change': '----', 'changeColor': Colors.grey, 'type': 'future'},
              {'name': '概念板块2', 'change': '----', 'changeColor': Colors.grey, 'type': 'future'},
              {'name': '概念板块3', 'change': '----', 'changeColor': Colors.grey, 'type': 'future'},
              {'name': '概念板块4', 'change': '----', 'changeColor': Colors.grey, 'type': 'future'},
              {'name': '概念板块5', 'change': '----', 'changeColor': Colors.grey, 'type': 'future'},
            ];
          });
        }
        return true;
      }
      
      DateTime actualDate = targetDate;
      
      print('🏢 正在使用AkShare API获取行业板块数据...');
      
      // 直接获取行业板块数据
      List<Map<String, dynamic>> industryData = await _akShareApiService.getIndustryData(actualDate);
      
      if (industryData.isNotEmpty) {
        // 按涨跌幅排序
        industryData.sort((a, b) {
          double changeA = a['change_percent'] ?? 0.0;
          double changeB = b['change_percent'] ?? 0.0;
          return changeB.compareTo(changeA); // 降序排列
        });
        
        List<Map<String, dynamic>> sectors = [];
        
        // 获取涨跌幅最高的前五个板块
        int topPerformersCount = 0;
        for (int i = 0; i < industryData.length && topPerformersCount < 5; i++) {
          var sector = industryData[i];
          double changePercent = sector['change_percent'] ?? 0.0;
          String name = sector['name'] ?? '未知板块';
          
          sectors.add({
            'name': name,
            'change': '${changePercent > 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
            'changeColor': changePercent > 0 ? Colors.red : Colors.green,
            'type': 'top_performer',
          });
          topPerformersCount++;
        }
        
        // 获取涨跌幅最差的前五个板块
        int worstPerformersCount = 0;
        for (int i = industryData.length - 5; i < industryData.length && worstPerformersCount < 5; i++) {
          var sector = industryData[i];
          double changePercent = sector['change_percent'] ?? 0.0;
          String name = sector['name'] ?? '未知板块';
          
          sectors.add({
            'name': name,
            'change': '${changePercent > 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
            'changeColor': changePercent > 0 ? Colors.red : Colors.green,
            'type': 'worst_performer',
          });
          worstPerformersCount++;
        }
        
        if (mounted) {
          setState(() {
            _hotSectors = sectors;
          });
        }
        print('✅ 行业板块数据获取成功，共 ${sectors.length} 个板块');
        return true;
      } else {
        print('❌ 行业板块数据获取失败，返回空数据');
        return false;
      }
    } catch (e) {
      print('❌ 板块数据获取异常: $e');
      return false;
    }
  }

  
  





  
  // 获取星期几的中文表示
  String _getWeekday(int weekday) {
    switch (weekday) {
      case 1: return '一';
      case 2: return '二';
      case 3: return '三';
      case 4: return '四';
      case 5: return '五';
      case 6: return '六';
      case 7: return '日';
      default: return '';
    }
  }
  
  // 构建现代化的指数行
  Widget _buildModernIndexRow(String name, String value, String change, Color changeColor) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: changeColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: changeColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                change.startsWith('+') ? Icons.trending_up : Icons.trending_down,
                size: 16,
                color: changeColor,
              ),
              const SizedBox(width: 4),
              Text(
                change,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: changeColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  
  // 构建现代化的板块行
  Widget _buildModernSectorRow(String name, String change, bool isPositive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isPositive ? Colors.red : Colors.green).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              change,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isPositive ? Colors.red[300] : Colors.green[300],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建传统的板块行
  Widget _buildSectorRow(String name, String change) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name, style: const TextStyle(fontSize: 16)),
        Text(change, style: TextStyle(
          fontSize: 16, 
          fontWeight: FontWeight.bold, 
          color: change.startsWith("+") ? Colors.red : Colors.green
        )),
      ],
    );
  }
  
  // 构建现代化的板块列表
  List<Widget> _buildModernSectorList(List<Map<String, dynamic>> sectors) {
    if (sectors.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(32),
          child: const Text(
            "暂无数据",
            style: TextStyle(color: Colors.white54, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }
    
    return sectors.asMap().entries.map((entry) {
      int index = entry.key;
      Map<String, dynamic> sector = entry.value;
      bool isPositive = sector['change'].toString().startsWith("+");
      
      return AnimatedContainer(
        duration: Duration(milliseconds: 300 + index * 100),
        curve: Curves.easeOut,
        child: _buildModernSectorRow(
          sector['name'],
          sector['change'],
          isPositive,
        ),
      );
    }).toList();
  }


  @override
  Widget build(BuildContext context) {
    // 格式化日期显示
    String formattedDate = "${widget.selectedDate.year}年${widget.selectedDate.month}月${widget.selectedDate.day}日";
    String weekday = _getWeekday(widget.selectedDate.weekday);
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          '市场概览',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF667eea),
                Color(0xFF764ba2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.refresh, color: Colors.white),
              ),
              onPressed: () {
                if (mounted) {
                  setState(() {
                    _isLoading = true;
                    _dataFetchFailed = false;
                  });
                }
                _loadStockData();
              },
            ),
          ),
        ],
      ),
      body: _dataFetchFailed
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0f0c29),
                    Color(0xFF302b63),
                    Color(0xFF24243e),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: const TextStyle(fontSize: 18, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _dataFetchFailed = false;
                          });
                          _loadStockData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text('重新获取数据'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0f0c29),
                    Color(0xFF302b63),
                    Color(0xFF24243e),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 现代化的日期信息卡片
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOut,
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: Colors.blue[400],
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      formattedDate,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            "星期$weekday",
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            "交易日",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 现代化的主要指数数据卡片
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.trending_up,
                                color: Colors.green[400],
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "主要指数",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          for (int i = 0; i < _majorIndices.length; i++)
                            AnimatedContainer(
                              duration: Duration(milliseconds: 300 + i * 100),
                              curve: Curves.easeOut,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.15)),
                              ),
                              child: _buildModernIndexRow(
                                _majorIndices[i]['name'],
                                _majorIndices[i]['value'],
                                _majorIndices[i]['change'],
                                _majorIndices[i]['changeColor'],
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 现代化的热门概念板块卡片
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.dashboard,
                                color: Colors.blue[400],
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "热门概念板块",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (_hotSectors.isEmpty && !_dataFetchFailed)
                            Container(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[400]!),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "板块数据获取中...,加载数据较多，请稍加等候哦",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_hotSectors.isEmpty && _dataFetchFailed)
                            Container(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: Colors.red[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "概念板块数据获取失败",
                                    style: TextStyle(
                                      color: Colors.red[300],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_hotSectors.isNotEmpty) ...[
                            // 涨跌幅最高的前五个板块
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.trending_up,
                                    color: Colors.red[400],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "涨幅榜",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[300],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._buildModernSectorList(_hotSectors.where((sector) => sector['type'] == 'top_performer').toList()),
                            
                            const SizedBox(height: 20),
                            
                            // 涨跌幅最差的前五个板块
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.trending_down,
                                    color: Colors.green[400],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "跌幅榜",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[300],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._buildModernSectorList(_hotSectors.where((sector) => sector['type'] == 'worst_performer').toList()),
                          ],
                        ],
                      ),
                    ),
                    
                    // 事件管理区域
                    const SizedBox(height: 24),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.event,
                                color: Colors.orange[400],
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "当日事件",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_todayEvents.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.event_available,
                                    size: 48,
                                    color: Colors.orange[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "当日暂无事件",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_todayEvents.isNotEmpty)
                            ..._todayEvents.map((event) {
                              return AnimatedContainer(
                                duration: Duration(milliseconds: 200 + _todayEvents.indexOf(event) * 100),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.orange[400],
                                    child: Icon(
                                      Icons.event,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    event.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${event.startTime.hour.toString().padLeft(2, '0')}:${event.startTime.minute.toString().padLeft(2, '0')}",
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      if (event.description?.isNotEmpty == true)
                                        Text(
                                          event.description!,
                                          style: TextStyle(color: Colors.white70),
                                        ),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert, color: Colors.white70),
                                    onSelected: (value) async {
                                      switch (value) {
                                        case 'edit':
                                          await _editEvent(event);
                                          break;
                                        case 'delete':
                                          await _deleteEvent(event);
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: ListTile(
                                          leading: Icon(Icons.edit),
                                          title: Text('编辑'),
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: ListTile(
                                          leading: Icon(Icons.delete, color: Colors.red),
                                          title: Text('删除', style: TextStyle(color: Colors.red)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _editEvent(event),
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewEvent,
        backgroundColor: Colors.orange[500],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
