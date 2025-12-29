import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/event.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final box = Hive.box<Event>('events');
    
    // 1. 基础数据统计
    final allEvents = box.values.toList();
    final totalCount = allEvents.length;
    
    // 2. 关键词统计
    int buyCount = 0;
    int sellCount = 0;
    int winCount = 0;
    int lossCount = 0;

    for (var e in allEvents) {
      final t = e.title;
      if (t.contains('买') || t.contains('入') || t.contains('加仓')) buyCount++;
      if (t.contains('卖') || t.contains('出') || t.contains('止盈') || t.contains('止损')) sellCount++;
      if (t.contains('盈') || t.contains('赚')) winCount++;
      if (t.contains('亏') || t.contains('损')) lossCount++;
    }

    // 3. 计算本月数据
    final now = DateTime.now();
    final thisMonthCount = allEvents.where((e) => 
      e.startTime.year == now.year && e.startTime.month == now.month
    ).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('交易统计'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部总览卡片
            _buildSummaryCard(context, totalCount, thisMonthCount),
            
            const SizedBox(height: 24),
            Text(' 操作分布', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            // 买卖比例条
            _buildRatioBar(context, '买入 vs 卖出', buyCount, sellCount, Colors.red.shade400, Colors.green.shade400),
            const SizedBox(height: 16),
            
            // 盈亏提及次数（基于标题文本）
            _buildRatioBar(context, '记录: 止盈 vs 止损', winCount, lossCount, Colors.red, Colors.green),

            const SizedBox(height: 24),
            Text(' 详细数据', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            _buildStatGrid(context, buyCount, sellCount, winCount, lossCount),
            
            const SizedBox(height: 40),
            Center(
              child: Text(
                '统计基于日程标题中的关键词\n(如"买入"、"卖出"、"止盈"等)',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.outline, fontSize: 12),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, int total, int month) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(total.toString(), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer)),
                Text('总记录数', style: TextStyle(color: colorScheme.onPrimaryContainer.withOpacity(0.8))),
              ],
            ),
            Container(width: 1, height: 40, color: colorScheme.onPrimaryContainer.withOpacity(0.2)),
            Column(
              children: [
                Text(month.toString(), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer)),
                Text('本月记录', style: TextStyle(color: colorScheme.onPrimaryContainer.withOpacity(0.8))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatioBar(BuildContext context, String title, int v1, int v2, Color c1, Color c2) {
    if (v1 == 0 && v2 == 0) return const SizedBox();
    
    final total = v1 + v2;
    final pct1 = v1 / total;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('${v1}次 / ${v2}次', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: c2.withOpacity(0.2), // 背景色
          ),
          child: Row(
            children: [
              Expanded(
                flex: (pct1 * 100).toInt(),
                child: Container(
                  decoration: BoxDecoration(
                    color: c1,
                    borderRadius: BorderRadius.horizontal(left: const Radius.circular(6), right: v2 == 0 ? const Radius.circular(6) : Radius.zero),
                  ),
                ),
              ),
              Expanded(
                flex: ((1 - pct1) * 100).toInt(),
                child: Container(
                  decoration: BoxDecoration(
                    color: c2,
                    borderRadius: BorderRadius.horizontal(right: const Radius.circular(6), left: v1 == 0 ? const Radius.circular(6) : Radius.zero),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatGrid(BuildContext context, int buy, int sell, int win, int loss) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _buildStatItem(context, '买入/加仓', buy, Icons.add_circle_outline, Colors.red),
        _buildStatItem(context, '卖出/减仓', sell, Icons.remove_circle_outline, Colors.green),
        // 这里的逻辑是简单的关键词匹配，您可以根据需要调整
        _buildStatItem(context, '提及止盈', win, Icons.trending_up, Colors.red.shade700),
        _buildStatItem(context, '提及止损', loss, Icons.trending_down, Colors.green.shade700),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, String label, int count, IconData icon, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(count.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(label, style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}