import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

// AkShare API服务类
class AkShareApiService {
  final String baseUrl;
  final http.Client client;

  AkShareApiService({
    this.baseUrl = 'http://10.161.183.140:8000',
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

  // 启动Python服务（移动设备不支持）
  Future<bool> _startPythonServer() async {
    print('❌ 移动设备无法直接启动Python服务');
    print('💡 请在开发机上手动启动Python服务');
    print('💡 命令: python lib\\akshare_api_server.py');
    return false;
  }
  
  // 桌面环境启动Python服务（保留原逻辑）
  Future<bool> _startPythonServerDesktop() async {
    bool isRunning = false;
    try {
      print('🔍 开始启动Python服务流程...');
      
      // 首先检查服务是否已经在运行
      isRunning = await checkServiceAvailability();
      if (isRunning) {
        print('✅ Python服务已经在运行');
        return true;
      }

      // 获取当前工作目录
      String currentDir = Directory.current.path;
      print('📁 当前工作目录: $currentDir');
      
      // 构建完整的脚本路径
      String scriptPath = 'lib/akshare_api_server.py';
      File scriptFile = File(scriptPath);
      
      // 检查脚本文件是否存在
      if (!await scriptFile.exists()) {
        print('❌ 脚本文件不存在: $scriptPath');
        // 尝试使用绝对路径
        String absoluteScriptPath = '$currentDir\\lib\\akshare_api_server.py';
        print('🔄 尝试使用绝对路径: $absoluteScriptPath');
        scriptFile = File(absoluteScriptPath);
        if (!await scriptFile.exists()) {
          print('❌ 绝对路径脚本文件也不存在: $absoluteScriptPath');
          return false;
        }
        scriptPath = absoluteScriptPath;
      }
      print('✅ 找到脚本文件: $scriptPath');
      
      // 验证Python是否可用
      String pythonCommand = Platform.isWindows ? 'python' : 'python3';
      try {
        ProcessResult pythonCheck = await Process.run(pythonCommand, ['--version']);
        print('✅ Python版本: ${pythonCheck.stdout}${pythonCheck.stderr}');
      } catch (e) {
        print('❌ 无法找到Python: $e');
        // 尝试使用python3作为备选（在某些Windows系统上可能也需要）
        pythonCommand = 'python3';
        try {
          ProcessResult pythonCheck = await Process.run(pythonCommand, ['--version']);
          print('✅ Python3版本: ${pythonCheck.stdout}${pythonCheck.stderr}');
        } catch (e) {
          print('❌ 无法找到Python3: $e');
          print('💡 请确保Python已正确安装并添加到系统PATH中');
          return false;
        }
      }
      
      // 启动Python服务
      print('🚀 正在启动Python服务...');
      if (Platform.isWindows) {
        // Windows系统使用cmd执行Python，添加更多的错误捕获和日志
        try {
          // 先尝试获取脚本所在目录
          String scriptDir = scriptFile.parent.path;
          print('📂 脚本所在目录: $scriptDir');
          
          // 使用完整路径执行Python
          ProcessResult result = await Process.run(
            'cmd', 
            ['/c', 'cd', scriptDir, '&&', 'start', '/B', pythonCommand, scriptFile.path],
            runInShell: true
          );
          print('Windows Python服务启动命令执行结果 - 退出码: ${result.exitCode}');
          print('命令输出: ${result.stdout}');
          print('错误输出: ${result.stderr}');
          
          // 额外的验证，尝试直接运行Python脚本来检查是否有语法错误
          try {
            ProcessResult validateResult = await Process.run(
              pythonCommand, 
              ['-c', 'import sys; sys.path.append("$scriptDir"); import akshare_api_server'],
              runInShell: true
            );
            print('✅ Python脚本导入验证通过');
          } catch (validateError) {
            print('⚠️ Python脚本导入验证失败: $validateError');
          }
        } catch (cmdError) {
          print('❌ Windows命令执行异常: $cmdError');
        }
      } else {
        // Linux/Mac系统
        try {
          String command = '$pythonCommand "$scriptPath" > /dev/null 2>&1 &';
          ProcessResult result = await Process.run('sh', ['-c', command]);
          print('Linux/Mac Python服务启动命令执行结果: ${result.exitCode}');
        } catch (shError) {
          print('❌ Linux/Mac命令执行异常: $shError');
        }
      }
      
      // 增加等待时间和重试机制
      const int maxRetries = 3;
      const int waitSeconds = 5;
      
      for (int retry = 1; retry <= maxRetries; retry++) {
        print('⏳ 等待Python服务启动 (尝试 $retry/$maxRetries)...');
        await Future.delayed(Duration(seconds: waitSeconds));
        
        // 检查服务是否成功启动
        isRunning = await checkServiceAvailability();
        if (isRunning) {
          print('✅ Python服务启动成功');
          return true;
        }
        print('⚠️ 服务尚未启动，准备重试...');
      }
      
      // 所有重试都失败
      print('❌ Python服务启动失败，请手动运行: $pythonCommand "$scriptPath"');
      print('💡 请确保已安装必要的Python依赖: pip install akshare pandas fastapi uvicorn');
      print('💡 请尝试手动运行脚本以查看详细错误信息');
    } catch (e) {
      print('❌ 启动Python服务异常: $e');
      print('❌ 异常类型: ${e.runtimeType}');
    }
    return false;
  }
}


class StockMarketDataScreen extends StatefulWidget {
  final DateTime selectedDate;

  const StockMarketDataScreen({super.key, required this.selectedDate});

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

  @override
  void initState() {
    super.initState();
    // 初始化akshare API服务
    // 移动设备环境下，连接到开发机的Python服务
    _akShareApiService = AkShareApiService(
      baseUrl: 'http://10.161.183.140:8000', // 您的开发机IP地址
    );
    // 移动设备无法直接启动Python服务，跳过自动启动
    // _akShareApiService._startPythonServer();
    _loadStockData();
    
    // 移除自动定时刷新，只在页面加载时获取一次数据
  }
  
  @override
  void dispose() {
    // 取消定时器，防止内存泄漏和setState在dispose后调用
    _refreshTimer?.cancel();
    // 关闭akshare API服务连接
    _akShareApiService.dispose();
    super.dispose();
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
      // 重置状态
      if (mounted) {
        setState(() {
          _isLoading = true;
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      
      // 检查是否是交易日，如果不是则使用上一个交易日
      DateTime actualDate = targetDate;
      if (!_isTradingDay(targetDate)) {
        print('⚠️ ${targetDate.year}-${targetDate.month}-${targetDate.day} 不是交易日，查找上一个交易日');
        actualDate = _getPreviousTradingDay(targetDate);
        print('📅 使用上一个交易日数据: ${actualDate.year}-${actualDate.month}-${actualDate.day}');
      }
      
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
      
      // 检查是否是交易日，如果不是则使用上一个交易日
      DateTime actualDate = targetDate;
      if (!_isTradingDay(targetDate)) {
        print('⚠️ ${targetDate.year}-${targetDate.month}-${targetDate.day} 不是交易日，查找上一个交易日');
        actualDate = _getPreviousTradingDay(targetDate);
        print('📅 使用上一个交易日数据: ${actualDate.year}-${actualDate.month}-${actualDate.day}');
      }
      
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

  
  




  // 检查是否为交易日
  bool _isTradingDay(DateTime date) {
    // 周末不是交易日
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      print('⚠️ ${date.year}-${date.month}-${date.day} 是周末，不是交易日');
      return false;
    }
    
    // 简单检查一些主要节假日
    int month = date.month;
    int day = date.day;
    
    // 元旦
    if (month == 1 && day == 1) {
      print('⚠️ ${date.year}-${date.month}-${date.day} 是元旦，不是交易日');
      return false;
    }
    
    // 春节 (简化处理，实际需要更复杂的农历计算)
    if (month == 2 && (day >= 10 && day <= 17)) {
      print('⚠️ ${date.year}-${date.month}-${date.day} 可能是春节期间，不是交易日');
      return false;
    }
    
    // 国庆节
    if (month == 10 && (day >= 1 && day <= 7)) {
      print('⚠️ ${date.year}-${date.month}-${date.day} 是国庆节期间，不是交易日');
      return false;
    }
    
    print('✅ ${date.year}-${date.month}-${date.day} 是交易日');
    return true;
  }
  
  // 获取上一个交易日
  DateTime _getPreviousTradingDay(DateTime date) {
    DateTime previousDay = DateTime(date.year, date.month, date.day).subtract(const Duration(days: 1));
    
    // 最多查找7天，确保能找到上一个交易日
    for (int i = 0; i < 7; i++) {
      if (_isTradingDay(previousDay)) {
        print('✅ 找到上一个交易日: ${previousDay.year}-${previousDay.month}-${previousDay.day}');
        return previousDay;
      }
      previousDay = previousDay.subtract(const Duration(days: 1));
    }
    
    // 如果7天内都找不到交易日，返回原始日期
    print('⚠️ 7天内未找到交易日，使用原始日期');
    return date;
  }
  
  // 检查日期是否是最近的交易日
  bool _isRecentTradingDay(DateTime date) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime targetDate = DateTime(date.year, date.month, date.day);
    
    // 计算日期差
    int daysDifference = today.difference(targetDate).inDays;
    
    // 如果日期差超过7天，可能不是最近的交易日
    if (daysDifference > 7) {
      print('⚠️ ${date.year}-${date.month}-${date.day} 距离今天超过7天，可能不是最近的交易日');
      return false;
    }
    
    print('✅ ${date.year}-${date.month}-${date.day} 是最近的交易日');
    return true;
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
  
  // 构建指数行
  Widget _buildIndexRow(String name, String value, String change, Color changeColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          flex: 2,
          child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          flex: 1,
          child: Text(change, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: changeColor)),
        ),
      ],
    );
  }
  
  // 构建板块行
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
  
  // 构建板块列表
  List<Widget> _buildSectorList(List<Map<String, dynamic>> sectors) {
    if (sectors.isEmpty) {
      return [
        const Text(
          "暂无数据",
          style: TextStyle(color: Colors.grey, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ];
    }
    
    return sectors.map((sector) {
      return Column(
        children: [
          _buildSectorRow(
            sector['name'],
            sector['change'],
          ),
          if (sector != sectors.last) const Divider(),
        ],
      );
    }).toList();
  }
  @override
  Widget build(BuildContext context) {
    // 获取交易日状态
    bool isTradingDay = _isTradingDay(widget.selectedDate);
    
    // 格式化日期显示
    String formattedDate = "${widget.selectedDate.year}年${widget.selectedDate.month}月${widget.selectedDate.day}日";
    String weekday = _getWeekday(widget.selectedDate.weekday);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('行情数据'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dataFetchFailed
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      style: const TextStyle(fontSize: 18, color: Colors.red),
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
                      child: const Text('重新获取数据'),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期信息卡片
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formattedDate, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("星期$weekday", style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isTradingDay ? Colors.green.shade100 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isTradingDay ? "交易日" : "非交易日",
                        style: TextStyle(
                          color: isTradingDay ? Colors.green[700] : Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 主要指数数据
            const Text("主要指数数据", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    for (int i = 0; i < _majorIndices.length; i++)
                      Column(
                        children: [
                          _buildIndexRow(
                            _majorIndices[i]['name'],
                            _majorIndices[i]['value'],
                            _majorIndices[i]['change'],
                            _majorIndices[i]['changeColor'],
                          ),
                          if (i < _majorIndices.length - 1) const Divider(),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 行业板块
            const Text("热门概念板块", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_hotSectors.isEmpty && !_dataFetchFailed)
                      const Text(
                        "概念板块数据获取中...",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    if (_hotSectors.isEmpty && _dataFetchFailed)
                      const Text(
                        "概念板块数据获取失败",
                        style: TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    if (_hotSectors.isNotEmpty) ...[
                      // 涨跌幅最高的前五个板块
                      Text(
                        "涨跌幅榜",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._buildSectorList(_hotSectors.where((sector) => sector['type'] == 'top_performer').toList()),
                      
                      const SizedBox(height: 16),
                      
                      // 涨跌幅最差的前五个板块
                      Text(
                        "------------------------",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 221, 207, 4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._buildSectorList(_hotSectors.where((sector) => sector['type'] == 'worst_performer').toList()),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
