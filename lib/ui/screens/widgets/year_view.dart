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
  bool _isScrolling = false;
  Timer? _scrollTimer;
  
  @override
  void initState() {
    super.initState();
    _focusedYear = widget.focusedDay.year.clamp(_startYear, _endYear);
    _scrollController = ScrollController(initialScrollOffset: 0.0);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // 计算初始滚动位置
    // 注意：这里使用较小的系数来匹配 Item 的实际高度
    final itemHeight = MediaQuery.of(context).size.height * 0.90; 
    final targetIndex = _focusedYear - _startYear;
    final correctScrollOffset = targetIndex * itemHeight;
    
    if (!_scrollController.hasClients) {
      // 重新创建 Controller 以应用初始偏移量
      // _scrollController.dispose(); // 不需要 dispose 旧的，因为还没 attach
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
  
  void _safeScrollToYear(int year) {
    if (!_isScrolling && _scrollController.hasClients && 
        year >= _startYear && year <= _endYear) {
      _isScrolling = true;
      
      final double itemHeight = MediaQuery.of(context).size.height * 0.90;
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return RepaintBoundary(
      child: Container(
        color: colorScheme.surface, // [修改] 跟随主题背景色
        width: double.infinity,
        height: double.infinity,
        child: ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          itemCount: _endYear - _startYear + 1,
          cacheExtent: screenHeight * 1.5,
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final year = _startYear + index;
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    // 稍微调小一点高度占比，让年份之间有更自然的间隔
    final fixedHeight = screenHeight * 0.90;
    
    return SizedBox(
      height: fixedHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 年份标题栏
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$year',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '年',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(), 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      lunarYear,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12, // 增加间距
                  mainAxisSpacing: 12,  // 增加间距
                  childAspectRatio: 0.8, // 调整比例适配新样式
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: _onMonthTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // [修改] 使用 Surface Container 颜色，区分层级，去除边框
          color: colorScheme.surfaceContainerLow,
        ),
        padding: const EdgeInsets.all(8), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, 
          children: [
            // 月份标题
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Text(
                '$month月',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // 星期头
            const _WeekDaysRow(),
            const SizedBox(height: 4),
            // 日期格子
            Expanded( 
              child: _SimpleMonthDays(year: year, month: month),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDaysRow extends StatelessWidget {
  const _WeekDaysRow();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = TextStyle(
      fontSize: 9, 
      color: colorScheme.onSurfaceVariant, 
      fontWeight: FontWeight.w500
    );
    final weekendStyle = textStyle.copyWith(color: colorScheme.error);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Text('日', style: weekendStyle),
        Text('一', style: textStyle),
        Text('二', style: textStyle),
        Text('三', style: textStyle),
        Text('四', style: textStyle),
        Text('五', style: textStyle),
        Text('六', style: weekendStyle),
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
    final colorScheme = Theme.of(context).colorScheme;
    
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayOfMonth = DateTime(year, month, 1);
    final firstDayOffset = firstDayOfMonth.weekday % 7;
    final rows = ((firstDayOffset + daysInMonth) / 7).ceil();
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.start, // 顶部对齐
      children: List.generate(rows, (rowIndex) {
        return Expanded( 
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (colIndex) {
              final dayIndex = rowIndex * 7 + colIndex;
              
              if (dayIndex < firstDayOffset || dayIndex >= firstDayOffset + daysInMonth) {
                return const Expanded(child: SizedBox());
              }
              
              final day = dayIndex - firstDayOffset + 1;
              final date = DateTime(year, month, day);
              final isHoliday = LunarUtils.isHoliday(date);
              
              return Expanded( 
                child: Center(
                  child: Container(
                    width: 14, // 固定宽度确保对齐
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 9, 
                        fontWeight: isHoliday ? FontWeight.w900 : FontWeight.normal,
                        // 节假日用 Error 色，普通日期用 OnSurface
                        color: isHoliday ? colorScheme.error : colorScheme.onSurface,
                      ),
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