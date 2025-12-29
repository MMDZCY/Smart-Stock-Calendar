import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/calendar_subscription.dart';
import '../../utils/import_export.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  final SubscriptionManager subscriptionManager;
  
  const SubscriptionManagementScreen({
    super.key,
    required this.subscriptionManager,
  });

  @override
  State<SubscriptionManagementScreen> createState() => _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState extends State<SubscriptionManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _intervalController = TextEditingController(text: '24');
  
  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _intervalController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('订阅管理'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.sync, color: colorScheme.primary),
            onPressed: _syncAllSubscriptions,
            tooltip: '同步所有订阅',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. 添加订阅表单区域
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "添加新订阅",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 订阅名称
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: '名称',
                            hintText: '例如：公司日历',
                            prefixIcon: const Icon(Icons.label_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          validator: (value) => value == null || value.isEmpty ? '请输入订阅名称' : null,
                        ),
                        const SizedBox(height: 12),
                        // URL
                        TextFormField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            labelText: 'URL (ICS文件)',
                            hintText: 'https://example.com/calendar.ics',
                            prefixIcon: const Icon(Icons.link),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return '请输入URL';
                            if (!value.startsWith('http')) return '请输入有效的URL';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        // 同步间隔
                        TextFormField(
                          controller: _intervalController,
                          decoration: InputDecoration(
                            labelText: '自动同步间隔 (小时)',
                            prefixIcon: const Icon(Icons.update),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final i = int.tryParse(value ?? '');
                            return (i == null || i <= 0) ? '请输入正整数' : null;
                          },
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _addSubscription,
                          icon: const Icon(Icons.add),
                          label: const Text('添加订阅'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // 2. 标题
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                "已订阅列表",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),

          // 3. 订阅列表
          ValueListenableBuilder<Box<CalendarSubscription>>(
            valueListenable: Hive.box<CalendarSubscription>('subscriptions').listenable(),
            builder: (context, box, _) {
              final subscriptions = box.values.toList();
              
              if (subscriptions.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.rss_feed, size: 48, color: colorScheme.outlineVariant),
                          const SizedBox(height: 12),
                          Text('暂无订阅', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                );
              }
              
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildSubscriptionCard(subscriptions[index], colorScheme, theme),
                  childCount: subscriptions.length,
                ),
              );
            },
          ),
          
          // 底部留白
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
  
  Widget _buildSubscriptionCard(CalendarSubscription subscription, ColorScheme colorScheme, ThemeData theme) {
    final hasSynced = subscription.lastSync.year != 1970;
    final lastSyncText = hasSynced 
        ? '上次同步: ${_formatDateTime(subscription.lastSync)}' 
        : '从未同步';
    
    final needsSync = subscription.needsSync();
    
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: subscription.isEnabled ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
          child: Icon(
            subscription.isEnabled ? Icons.rss_feed : Icons.rss_feed_outlined,
            color: subscription.isEnabled ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
        title: Text(
          subscription.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: subscription.isEnabled ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              subscription.url,
              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (needsSync && subscription.isEnabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text("需要同步", style: TextStyle(fontSize: 10, color: colorScheme.onErrorContainer)),
                  ),
                Text(
                  lastSyncText,
                  style: TextStyle(
                    fontSize: 11,
                    color: needsSync && subscription.isEnabled ? colorScheme.error : colorScheme.onSurfaceVariant.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
        // 操作按钮区域
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 启用/禁用 开关
                Row(
                  children: [
                    Text(
                      subscription.isEnabled ? "已启用" : "已禁用",
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 4),
                    Switch(
                      value: subscription.isEnabled,
                      onChanged: (_) => _toggleSubscription(subscription),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                const Spacer(),
                // 立即同步按钮
                FilledButton.tonalIcon(
                  onPressed: subscription.isEnabled ? () => _syncSubscription(subscription) : null,
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('同步'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                // 删除按钮
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colorScheme.error),
                  onPressed: () => _deleteSubscription(subscription),
                  tooltip: '删除',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}月${dateTime.day}日 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  void _addSubscription() async {
    if (_formKey.currentState != null && _formKey.currentState!.validate()) {
      try {
        await widget.subscriptionManager.addSubscription(
          name: _nameController.text,
          url: _urlController.text,
          syncIntervalHours: int.parse(_intervalController.text),
        );
        _nameController.clear();
        _urlController.clear();
        _intervalController.text = '24';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('订阅添加成功')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('添加订阅失败: $e')));
      }
    }
  }
  
  void _syncSubscription(CalendarSubscription subscription) async {
    try {
      final count = await widget.subscriptionManager.syncSubscription(subscription);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('同步成功，导入 $count 个事件')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('同步失败: $e')));
    }
  }
  
  void _syncAllSubscriptions() async {
    try {
      final results = await widget.subscriptionManager.syncAllSubscriptions();
      if (mounted) {
        String message = '同步完成：\n';
        results.forEach((name, count) => message += count >= 0 ? '$name: $count 个事件\n' : '$name: 同步失败\n');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('同步失败: $e')));
    }
  }
  
  void _toggleSubscription(CalendarSubscription subscription) async {
    subscription.isEnabled = !subscription.isEnabled;
    await subscription.save();
    if (mounted) setState(() {}); // 刷新 UI
  }
  
  void _deleteSubscription(CalendarSubscription subscription) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除订阅"${subscription.name}"？\n这将同时删除该订阅导入的所有事件。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await widget.subscriptionManager.deleteSubscription(subscription.id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('订阅删除成功')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }
}