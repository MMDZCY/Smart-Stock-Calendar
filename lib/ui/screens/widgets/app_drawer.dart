import 'package:flutter/material.dart';
import '../about_screen.dart'; // 引入关于页面

class AppDrawer extends StatelessWidget {
  final VoidCallback onSubscriptionTap;
  final Function(String) onImportExportTap;
  final VoidCallback onTestNotificationTap;

  const AppDrawer({
    super.key,
    required this.onSubscriptionTap,
    required this.onImportExportTap,
    required this.onTestNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return NavigationDrawer(
      selectedIndex: 0,
      onDestinationSelected: (index) {
        // 关闭侧边栏
        Navigator.pop(context);

        // 处理点击逻辑
        // 注意：index 是根据 NavigationDrawerDestination 的顺序来的
        switch (index) {
          case 0:
            // 主页 - 不做操作
            break;
          case 1:
            // 订阅管理
            onSubscriptionTap();
            break;
          case 2:
            // 导入数据
            // 延迟一点显示弹窗，等待 Drawer 关闭动画完成
            Future.delayed(const Duration(milliseconds: 200), () {
              if (context.mounted) _showImportDialog(context);
            });
            break;
          case 3:
            // 导出数据
            Future.delayed(const Duration(milliseconds: 200), () {
              if (context.mounted) _showExportDialog(context);
            });
            break;
          case 4:
            // 测试通知
            onTestNotificationTap();
            break;
          case 5:
            // 关于页面
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutScreen()),
            );
            break;
        }
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
          child: Text(
            'Smart Stock Calendar',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // Index 0
        const NavigationDrawerDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: Text('日历主页'),
        ),
        
        const Divider(indent: 28, endIndent: 28),
        
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
          child: Text(
            '数据管理',
            style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.secondary),
          ),
        ),

        // Index 1
        const NavigationDrawerDestination(
          icon: Icon(Icons.rss_feed_outlined),
          selectedIcon: Icon(Icons.rss_feed),
          label: Text('订阅管理'),
        ),

        // Index 2
        const NavigationDrawerDestination(
          icon: Icon(Icons.file_upload_outlined),
          label: Text('导入数据'),
        ),
        
        // Index 3
        const NavigationDrawerDestination(
          icon: Icon(Icons.file_download_outlined),
          label: Text('导出数据'),
        ),

        const Divider(indent: 28, endIndent: 28),
        
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
          child: Text(
            '其他',
            style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.secondary),
          ),
        ),
        
        // Index 4
        const NavigationDrawerDestination(
          icon: Icon(Icons.notifications_active_outlined),
          label: Text('测试通知'),
        ),

        // Index 5
        const NavigationDrawerDestination(
          icon: Icon(Icons.info_outline),
          label: Text('关于应用'),
        ),
      ],
    );
  }

  void _showImportDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('从 ICS 文件导入'),
              onTap: () {
                Navigator.pop(context);
                onImportExportTap('import_ics');
              },
            ),
            ListTile(
              leading: const Icon(Icons.javascript),
              title: const Text('从 JSON 文件导入'),
              onTap: () {
                Navigator.pop(context);
                onImportExportTap('import_json');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('导出为 ICS'),
              onTap: () {
                Navigator.pop(context);
                onImportExportTap('export_ics');
              },
            ),
            ListTile(
              leading: const Icon(Icons.javascript),
              title: const Text('导出为 JSON'),
              onTap: () {
                Navigator.pop(context);
                onImportExportTap('export_json');
              },
            ),
          ],
        ),
      ),
    );
  }
}