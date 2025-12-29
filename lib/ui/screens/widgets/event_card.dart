import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/event.dart';

class EventCard extends StatelessWidget {
  final Event event;

  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      // 使用 Theme 中统一定义的 elevation 和 shape
      // 调整 margin 以符合新布局
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      // 使用 M3 的 Surface Container 颜色，区分层级
      color: colorScheme.surfaceContainerLow, 
      child: InkWell(
        // 添加点击波纹效果（如果需要点击事件）
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // 这里可以透传点击事件，或者由上层 ListView 处理
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 左侧添加一个彩色指示条，增加视觉识别度
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      event.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 时间行
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${timeFormat.format(event.startTime)} - ${timeFormat.format(event.endTime)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              // 地点行 (如果有)
              if (event.location != null && event.location!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: colorScheme.secondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        event.location!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              // 描述行 (如果有)
              if (event.description != null && event.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface, // 在卡片内再用一层背景区分
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    event.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}