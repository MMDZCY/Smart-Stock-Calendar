import 'package:flutter/material.dart';
import 'package:calender_1/utils/lunar_utils.dart';
import 'dart:async';

class YearView extends StatefulWidget {
  final DateTime focusedDay;
  final Function(DateTime)? onMonthSelected;

  const YearView({
    super.key,
    required this.focusedDay,
    this.onMonthSelected,
  });

  @override
  State<YearView> createState() => _YearViewState();
}

class _YearViewState extends State<YearView> {
  late ScrollController _scrollController;
  late int _focusedYear;
  final int _startYear = 2020;
  final int _endYear = 2035;
  bool _isScrolling = false; // 防止重复滚动
  Timer? _scrollTimer; // 滚动防抖计时器
  
  @override
  void initState() {
    super.initState();
    _focusedYear = widget.focusedDay.year.clamp(_startYear, _endYear);
    // 创建ScrollController时设置一个初始估计值
    // 这是一个临时值，会在didChangeDependencies中更新
    _scrollController = ScrollController(initialScrollOffset: 0.0);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // 简化的滚动位置设置
    final targetIndex = _focusedYear - _startYear;
    final itemHeight = MediaQuery.of(context).size.height * 0.95;
    final correctScrollOffset = targetIndex * itemHeight;
    
    // 只在需要时设置滚动位置
    if (!_scrollController.hasClients) {
      _scrollController.dispose();
      _scrollController = ScrollController(initialScrollOffset: correctScrollOffset);
    }
  }
  
  @override
  void didUpdateWidget(covariant YearView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusedDay.year != oldWidget.focusedDay.year) {
      _focusedYear = widget.focusedDay.year.clamp(_startYear, _endYear);
      _safeScrollToYear(_focusedYear);
    }
  }
  
  // 安全的滚动方法，使用jumpTo实现瞬间定位
  void _safeScrollToYear(int year) {
    // 直接计算并设置滚动位置，不使用动画
    if (!_isScrolling && _scrollController.hasClients && 
        year >= _startYear && year <= _endYear) {
      _isScrolling = true;
      
      final double itemHeight = MediaQuery.of(context).size.height * 0.95;
      final int yearIndex = year - _startYear;
      final double targetPosition = yearIndex * itemHeight;
      
      _scrollController.jumpTo(targetPosition);
      _isScrolling = false;
    }
  }
  


  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  String getLunarYear(int year) {
    final zodiac = ['鼠', '牛', '虎', '兔', '龙', '蛇', '马', '羊', '猴', '鸡', '狗', '猪'];
    final heavenlyStems = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
    final earthlyBranches = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];
    
    int stemIndex = (year - 4) % 10;
    int branchIndex = (year - 4) % 12;
    
    return '${heavenlyStems[stemIndex]}${earthlyBranches[branchIndex]}${zodiac[branchIndex]}年';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return RepaintBoundary(
      child: Container(
        color: Colors.white, // 白色背景，与月视图统一
        width: double.infinity,
        height: double.infinity,
        child: ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          itemCount: _endYear - _startYear + 1,
          // 优化预加载范围，只预加载当前页和前后各一页
          cacheExtent: screenHeight * 1.5,
          // 启用自动保活，避免滚动时重复构建
          addAutomaticKeepAlives: true,
          // 启用重绘边界，减少不必要的重建
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final year = _startYear + index;
            // 缓存农历年份计算结果
            final lunarYear = getLunarYear(year);
            return _YearPage(
              year: year,
              lunarYear: lunarYear,
              onMonthSelected: widget.onMonthSelected,
            );
          },
        ),
      ),
    );
  }
}

class _YearPage extends StatelessWidget {
  final int year;
  final String lunarYear;
  final Function(DateTime)? onMonthSelected;

  const _YearPage({
    required this.year,
    required this.lunarYear,
    required this.onMonthSelected,
  });

  @override
  Widget build(BuildContext context) {
    // 获取屏幕高度并设置每个年份页面的固定高度
    final screenHeight = MediaQuery.of(context).size.height;
    // 设置一个接近屏幕高度但稍小的值，确保内容完全显示且无多余空白
    final fixedHeight = screenHeight * 0.95;
    
    return SizedBox(
      height: fixedHeight,
      child: Container(
        padding: const EdgeInsets.all(2.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$year年',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black, 
                  ),
                ),
                const Spacer(), 
                Text(
                  lunarYear,
                  style: TextStyle(
                    fontSize: 16,
                    color: const Color.fromARGB(255, 109, 48, 48), 
                  ),
                ),
              ],
            ),
            SizedBox(height: 2),
            Expanded(
              child: GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.85, // 恢复为更紧凑的宽高比
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final month = index + 1;
                  return _MonthView(
                    year: year,
                    month: month,
                    onMonthSelected: onMonthSelected,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthView extends StatelessWidget {
  final int year;
  final int month;
  final Function(DateTime)? onMonthSelected;

  const _MonthView({
    required this.year,
    required this.month,
    required this.onMonthSelected,
  });

  void _onMonthTap() {
    if (onMonthSelected != null) {
      final selectedDate = DateTime(year, month, 1);
      onMonthSelected!(selectedDate);
    }
  }

  bool isSameMonth(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month;
  }

  bool isSpecialDate(DateTime date) {
    return LunarUtils.isHoliday(date);
  }
  
  
  Color getMonthColor(int month) {
    return Colors.white; 
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _onMonthTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white, 
          border: Border.all(color: Colors.grey.shade300, width: 1), // 添加边框
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(8), 
        child: SizedBox.expand( 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, 
            mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
            children: [
              Center(
                child: Text(
                  '$month月',
                  style: TextStyle(
                    color: Colors.black, 
                    fontWeight: FontWeight.bold,
                    fontSize: 14, 
                  ),
                ),
              ),
              const _WeekDaysRow(),
              Expanded( 
                child: _SimpleMonthDays(year: year, month: month),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _WeekDaysRow extends StatelessWidget {
  const _WeekDaysRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: const [
        Text('日', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
        Text('一', style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
        Text('二', style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
        Text('三', style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
        Text('四', style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
        Text('五', style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
        Text('六', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
      ],
    );
  }
}


class _SimpleMonthDays extends StatelessWidget {
  final int year;
  final int month;

  const _SimpleMonthDays({
    required this.year,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayOfMonth = DateTime(year, month, 1);
    final firstDayOffset = firstDayOfMonth.weekday % 7;
    final rows = ((firstDayOffset + daysInMonth) / 7).ceil();
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
      children: List.generate(rows, (rowIndex) {
        return Expanded( 
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (colIndex) {
              final dayIndex = rowIndex * 7 + colIndex;
              
              if (dayIndex < firstDayOffset || dayIndex >= firstDayOffset + daysInMonth) {
                return Expanded( 
                  child: Container(
                    alignment: Alignment.center,
                    child: const Text(''),
                  ),
                );
              }
              
              final day = dayIndex - firstDayOffset + 1;
              final date = DateTime(year, month, day);
              final special = LunarUtils.isHoliday(date);
              
              return Expanded( 
                child: Container(
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: special ? FontWeight.bold : FontWeight.normal,
                      color: special ? Colors.red : Colors.black, 
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}
