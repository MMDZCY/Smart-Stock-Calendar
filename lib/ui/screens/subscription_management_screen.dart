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
    return Scaffold(
      appBar: AppBar(
        title: const Text('订阅管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncAllSubscriptions,
            tooltip: '同步所有订阅',
          ),
        ],
      ),
      body: Column(
        children: [
          // 添加订阅表单
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '订阅名称',
                        hintText: '例如：公司日历',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入订阅名称';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'ICS文件URL',
                        hintText: '例如：https://example.com/calendar.ics',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入ICS文件URL';
                        }
                        if (!value.startsWith('http')) {
                          return '请输入有效的URL';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _intervalController,
                      decoration: const InputDecoration(
                        labelText: '同步间隔（小时）',
                        hintText: '24',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入同步间隔';
                        }
                        final interval = int.tryParse(value);
                        if (interval == null || interval <= 0) {
                          return '请输入正整数';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _addSubscription,
                      icon: const Icon(Icons.add),
                      label: const Text('添加订阅'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 订阅列表
          Expanded(
            child: ValueListenableBuilder<Box<CalendarSubscription>>(
              valueListenable: Hive.box<CalendarSubscription>('subscriptions').listenable(),
              builder: (context, box, _) {
                final subscriptions = box.values.toList();
                
                if (subscriptions.isEmpty) {
                  return const Center(
                    child: Text('暂无订阅，请添加第一个订阅'),
                  );
                }
                
                return ListView.builder(
                  itemCount: subscriptions.length,
                  itemBuilder: (context, index) {
                    final subscription = subscriptions[index];
                    return _buildSubscriptionCard(subscription);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSubscriptionCard(CalendarSubscription subscription) {
    final lastSyncText = subscription.lastSync.year == 1970 
        ? '从未同步' 
        : '最后同步: ${_formatDateTime(subscription.lastSync)}';
    
    final needsSync = subscription.needsSync();
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(
          subscription.isEnabled ? Icons.rss_feed : Icons.rss_feed_outlined,
          color: subscription.isEnabled ? Colors.blue : Colors.grey,
        ),
        title: Text(subscription.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subscription.url,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              lastSyncText,
              style: TextStyle(
                fontSize: 12,
                color: needsSync ? Colors.orange : Colors.grey,
              ),
            ),
            if (needsSync)
              const Text(
                '需要同步',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.sync, size: 20),
              onPressed: () => _syncSubscription(subscription),
              tooltip: '同步此订阅',
            ),
            IconButton(
              icon: Icon(
                subscription.isEnabled ? Icons.visibility : Icons.visibility_off,
                size: 20,
              ),
              onPressed: () => _toggleSubscription(subscription),
              tooltip: subscription.isEnabled ? '禁用订阅' : '启用订阅',
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _deleteSubscription(subscription),
              tooltip: '删除订阅',
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  void _addSubscription() async {
    if (_formKey.currentState != null && _formKey.currentState!.validate()) {
      try {
        await widget.subscriptionManager.addSubscription(
          name: _nameController.text,
          url: _urlController.text,
          syncIntervalHours: int.parse(_intervalController.text),
        );
        
        // 清空表单
        _nameController.clear();
        _urlController.clear();
        _intervalController.text = '24';
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('订阅添加成功')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加订阅失败: $e')),
          );
        }
      }
    }
  }
  
  void _syncSubscription(CalendarSubscription subscription) async {
    try {
      final count = await widget.subscriptionManager.syncSubscription(subscription);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步成功，导入 $count 个事件')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: $e')),
        );
      }
    }
  }
  
  void _syncAllSubscriptions() async {
    try {
      final results = await widget.subscriptionManager.syncAllSubscriptions();
      
      if (mounted) {
        String message = '同步完成：\n';
        results.forEach((name, count) {
          if (count >= 0) {
            message += '$name: $count 个事件\n';
          } else {
            message += '$name: 同步失败\n';
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: $e')),
        );
      }
    }
  }
  
  void _toggleSubscription(CalendarSubscription subscription) async {
    subscription.isEnabled = !subscription.isEnabled;
    await subscription.save();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(subscription.isEnabled ? '订阅已启用' : '订阅已禁用'),
        ),
      );
    }
  }
  
  void _deleteSubscription(CalendarSubscription subscription) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除订阅"${subscription.name}"？\n这将同时删除该订阅导入的所有事件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await widget.subscriptionManager.deleteSubscription(subscription.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('订阅删除成功')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }
}