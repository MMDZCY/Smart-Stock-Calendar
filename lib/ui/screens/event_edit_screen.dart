import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/event.dart';

class EventEditScreen extends StatefulWidget {
  final DateTime? selectedDate;
  final Event? event;
  final Function(Event) onEventSaved;
  final Function(Event)? onEventDeleted;

  const EventEditScreen({
    super.key,
    this.selectedDate,
    this.event,
    required this.onEventSaved,
    this.onEventDeleted,
  });

  @override
  State<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends State<EventEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _descriptionController;
  
  late DateTime _startTime;
  late DateTime _endTime;
  late bool _isAllDay;

  @override
  void initState() {
    super.initState();
    
    if (widget.event != null) {
      _titleController = TextEditingController(text: widget.event!.title);
      _locationController = TextEditingController(text: widget.event!.location ?? '');
      _descriptionController = TextEditingController(text: widget.event!.description ?? '');
      _startTime = widget.event!.startTime;
      _endTime = widget.event!.endTime;
      _isAllDay = widget.event!.isAllDay;
    } else {
      _titleController = TextEditingController();
      _locationController = TextEditingController();
      _descriptionController = TextEditingController();
      _startTime = widget.selectedDate ?? DateTime.now();
      // 默认设置为下一个整点，时长1小时
      final now = DateTime.now();
      if (widget.selectedDate != null) {
         // 如果从日历点击进来，默认设为当前时间（保留日期）
         _startTime = DateTime(widget.selectedDate!.year, widget.selectedDate!.month, widget.selectedDate!.day, now.hour, now.minute);
      }
      _endTime = _startTime.add(const Duration(hours: 1));
      _isAllDay = false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveEvent() async {
    if (_formKey.currentState != null && _formKey.currentState!.validate()) {
      try {
        final event = Event(
          id: widget.event?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
          title: _titleController.text.trim(),
          startTime: _startTime,
          endTime: _endTime,
          location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          isAllDay: _isAllDay,
        );
        
        if (!event.isAllDay && event.endTime.isBefore(event.startTime)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('结束时间不能早于开始时间'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
          return;
        }
        
        await widget.onEventSaved(event);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存失败: $e')),
          );
        }
      }
    }
  }

  void _deleteEvent() {
    if (widget.event == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除事件'),
        content: Text('确定要删除事件"${widget.event!.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (widget.onEventDeleted != null) {
                widget.onEventDeleted!(widget.event!);
              }
              Navigator.pop(context); // 关弹窗
              Navigator.pop(context); // 关页面
            },
            child: Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
      // 使用更现代的主题设置
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && mounted) {
      setState(() {
        final duration = _endTime.difference(_startTime);
        _startTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _startTime.hour,
          _startTime.minute,
        );
        // 保持原来的时长
        _endTime = _startTime.add(duration);
      });
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    
    if (picked != null && mounted) {
      setState(() {
        _startTime = DateTime(
          _startTime.year,
          _startTime.month,
          _startTime.day,
          picked.hour,
          picked.minute,
        );
        if (_endTime.isBefore(_startTime) || _endTime == _startTime) {
          _endTime = _startTime.add(const Duration(hours: 1));
        }
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endTime),
    );
    
    if (picked != null && mounted) {
      setState(() {
        _endTime = DateTime(
          _endTime.year,
          _endTime.month,
          _endTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event != null ? '编辑事件' : '新事件'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        scrolledUnderElevation: 0,
        actions: [
          if (widget.event != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: colorScheme.error),
              tooltip: '删除事件',
              onPressed: _deleteEvent,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 标题输入
              TextFormField(
                controller: _titleController,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: '事件标题',
                  hintText: '请输入标题',
                  prefixIcon: Icon(Icons.title, color: colorScheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (value) => value == null || value.isEmpty ? '请输入事件标题' : null,
              ),
              const SizedBox(height: 24),

              // 2. 全天事件开关 (Card样式)
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: EdgeInsets.zero,
                child: SwitchListTile(
                  title: const Text('全天事件'),
                  secondary: Icon(Icons.access_time_filled, color: colorScheme.primary),
                  value: _isAllDay,
                  onChanged: (value) => setState(() => _isAllDay = value),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),

              // 3. 日期时间选择区域
              // 日期
              _buildSelectionTile(
                icon: Icons.calendar_month,
                label: '日期',
                value: DateFormat('yyyy年MM月dd日 (EEE)', 'zh_CN').format(_startTime),
                onTap: _selectDate,
                colorScheme: colorScheme,
              ),
              
              // 时间选择 (带动画显隐)
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity), // 全天模式下隐藏时间
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSelectionTile(
                          icon: Icons.schedule,
                          label: '开始',
                          value: DateFormat('HH:mm').format(_startTime),
                          onTap: _selectStartTime,
                          colorScheme: colorScheme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSelectionTile(
                          icon: Icons.update,
                          label: '结束',
                          value: DateFormat('HH:mm').format(_endTime),
                          onTap: _selectEndTime,
                          colorScheme: colorScheme,
                        ),
                      ),
                    ],
                  ),
                ),
                crossFadeState: _isAllDay ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 300),
              ),
              
              const SizedBox(height: 24),

              // 4. 地点输入
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: '地点',
                  prefixIcon: Icon(Icons.location_on_outlined, color: colorScheme.onSurfaceVariant),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 5. 描述输入
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: '备注',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 60), // 图标顶对齐
                    child: Icon(Icons.notes, color: colorScheme.onSurfaceVariant),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),

              // 6. 保存按钮
              FilledButton.icon(
                onPressed: _saveEvent,
                icon: const Icon(Icons.check),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    widget.event != null ? '保存修改' : '创建事件',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              
              // 底部键盘避让
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }

  // 自定义选择块组件
  Widget _buildSelectionTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}