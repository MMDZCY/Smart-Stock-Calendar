import 'package:flutter/material.dart';
import '../statistics_screen.dart'; // [新增] 引入统计页面

class AppDrawer extends StatelessWidget {
  final VoidCallback onSubscriptionTap;
  final VoidCallback onTestNotificationTap;
  final Function(String) onImportExportTap;

  const AppDrawer({
    super.key,
    required this.onSubscriptionTap,
    required this.onTestNotificationTap,
    required this.onImportExportTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 头部
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: colorScheme.primary,
              image: DecorationImage(
                image: const NetworkImage('https://picsum.photos/seed/stock/800/400'), // 随机风景图，也可以换成您本地的 asset
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.4), 
                  BlendMode.darken
                ),
              ),
            ),
            accountName: const Text(
              '股市日历',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            accountEmail: const Text('记录每一笔交易与心得'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: colorScheme.surface,
              child: Icon(Icons.trending_up, size: 36, color: colorScheme.primary),
            ),
          ),

          // --- 功能菜单 ---
          
          // [新增] 交易统计入口
          ListTile(
            leading: Icon(Icons.bar_chart, color: colorScheme.primary),
            title: const Text('交易统计'),
            onTap: () {
              Navigator.pop(context); // 关闭侧边栏
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatisticsScreen()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.rss_feed),
            title: const Text('日历订阅管理'),
            onTap: () {
              Navigator.pop(context);
              onSubscriptionTap();
            },
          ),
          
          const Divider(),

          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('测试通知'),
            subtitle: const Text('发送一条立即显示的测试通知'),
            onTap: () {
              Navigator.pop(context);
              onTestNotificationTap();
            },
          ),

          const Divider(),
          
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Text('数据备份与恢复', style: TextStyle(color: colorScheme.outline, fontSize: 12)),
          ),

          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('导出日历 (ICS)'),
            onTap: () {
              Navigator.pop(context);
              onImportExportTap('export_ics');
            },
          ),
          ListTile(
            leading: const Icon(Icons.javascript), // JSON icon substitute
            title: const Text('导出数据 (JSON)'),
            onTap: () {
              Navigator.pop(context);
              onImportExportTap('export_json');
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('导入日历 (ICS)'),
            onTap: () {
              Navigator.pop(context);
              onImportExportTap('import_ics');
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('恢复数据 (JSON)'),
            onTap: () {
              Navigator.pop(context);
              onImportExportTap('import_json');
            },
          ),
          
          const Divider(),
          
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            onTap: () {
              Navigator.pop(context);
              showAboutDialog(
                context: context,
                applicationName: '股市日历',
                applicationVersion: '1.0.0',
                applicationIcon: Icon(Icons.calendar_month, size: 48, color: colorScheme.primary),
                children: [
                  const Text('一个专为股民打造的日历应用，集成了农历、股市行情与交易记录功能。'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}