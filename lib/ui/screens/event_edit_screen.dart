import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/event.dart';

class EventEditScreen extends StatefulWidget {
  final DateTime? selectedDate;
  final Event? event;
  final Function(Event)? onEventSaved;
  final Function(Event)? onEventDeleted;

  const EventEditScreen({
    super.key,
    this.selectedDate,
    this.event,
    this.onEventSaved,
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
  bool _isAllDay = false;
  
  // [新增] 快速标签列表
  final List<String> _quickTags = ['买入', '卖出', '加仓', '止盈', '复盘', '打新'];
  // [新增] 选中的标签
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final initialDate = widget.selectedDate ?? DateTime.now();

    _titleController = TextEditingController(text: event?.title ?? '');
    _locationController = TextEditingController(text: event?.location ?? '');
    _descriptionController = TextEditingController(text: event?.description ?? '');
    
    if (event != null) {
      _startTime = event.startTime;
      _endTime = event.endTime;
      _isAllDay = event.isAllDay;
    } else {
      final now = DateTime.now();
      _startTime = DateTime(initialDate.year, initialDate.month, initialDate.day, now.hour, now.minute);
      _endTime = _startTime.add(const Duration(hours: 1));
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
    if (_formKey.currentState!.validate()) {
      final newEvent = Event(
        id: widget.event?.id ?? DateTime.now().toString(),
        title: _titleController.text,
        startTime: _startTime,
        endTime: _endTime,
        location: _locationController.text,
        description: _descriptionController.text,
        isAllDay: _isAllDay,
      );

      if (widget.onEventSaved != null) {
        widget.onEventSaved!(newEvent);
      }
      
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _pickDateTime(bool isStart) async {
    // 保持之前的逻辑...
    final initialDate = isStart ? _startTime : _endTime;
    FocusScope.of(context).unfocus();

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    
    if (date == null) return;

    TimeOfDay? time;
    if (!_isAllDay) {
      if (mounted) {
        time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(initialDate),
        );
      }
      if (time == null) return;
    } else {
      time = const TimeOfDay(hour: 0, minute: 0);
    }

    final newDateTime = DateTime(
      date.year, date.month, date.day, time.hour, time.minute
    );

    setState(() {
      if (isStart) {
        _startTime = newDateTime;
        if (_endTime.isBefore(_startTime)) {
          _endTime = _startTime.add(const Duration(hours: 1));
        }
      } else {
        _endTime = newDateTime;
      }
    });
  }

  // [新增] 标签点击处理
  void _onTagSelected(String tag) {
    setState(() {
      _selectedTag = tag;
      // 自动填入标题
      String currentText = _titleController.text;
      // 如果已经包含这个标签，就不重复加
      if (!currentText.contains(tag)) {
        _titleController.text = "$tag $currentText";
        // 光标移到最后
        _titleController.selection = TextSelection.fromPosition(TextPosition(offset: _titleController.text.length));
      }
    });
  }

  Color _getTagColor(String tag) {
    if (tag.contains('买') || tag.contains('加') || tag.contains('新')) return Colors.red.shade100;
    if (tag.contains('卖') || tag.contains('止')) return Colors.green.shade100;
    return Colors.blue.shade100;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      resizeToAvoidBottomInset: false, // 保持防闪退设置
      appBar: AppBar(
        title: Text(widget.event == null ? '新建日程' : '编辑日程'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saveEvent,
            child: const Text('保存', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // [新增] 快速标签区域
                Text('快速标签', style: TextStyle(fontSize: 12, color: colorScheme.outline, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickTags.map((tag) {
                    return ActionChip(
                      label: Text(tag),
                      backgroundColor: _getTagColor(tag),
                      side: BorderSide.none,
                      labelStyle: TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.bold
                      ),
                      onPressed: () => _onTagSelected(tag),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 标题输入
                TextFormField(
                  controller: _titleController,
                  style: theme.textTheme.headlineSmall,
                  decoration: const InputDecoration(
                    labelText: '标题',
                    hintText: '例如：买入茅台 100股',
                    border: OutlineInputBorder(), // 改回带边框的样式，更正式
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                  validator: (value) => value == null || value.isEmpty ? '请输入标题' : null,
                ),
                
                const SizedBox(height: 20),
                
                // 全天开关
                SwitchListTile(
                  title: const Text('全天事件'),
                  value: _isAllDay,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    FocusScope.of(context).unfocus(); 
                    setState(() => _isAllDay = val);
                  },
                ),
                
                const Divider(),
                
                // 时间选择
                _buildDateTimeField('开始时间', _startTime, true, colorScheme),
                const SizedBox(height: 8),
                _buildDateTimeField('结束时间', _endTime, false, colorScheme),
                
                const Divider(height: 32),
                
                // 地点
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: '股票代码 / 地点',
                    prefixIcon: Icon(Icons.show_chart, color: colorScheme.outline), // 图标换成股票趋势图
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 备注
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  minLines: 3,
                  decoration: InputDecoration(
                    labelText: '交易策略 / 备注',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes, color: colorScheme.outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 删除按钮
                if (widget.event != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        if (widget.onEventDeleted != null) {
                          widget.onEventDeleted!(widget.event!);
                        }
                        Navigator.pop(context, true);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('删除此日程'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.errorContainer,
                        foregroundColor: colorScheme.onErrorContainer,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                const SizedBox(height: 300), // 底部垫片防遮挡
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeField(String label, DateTime dt, bool isStart, ColorScheme colorScheme) {
    return InkWell(
      onTap: () => _pickDateTime(isStart),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 20, color: colorScheme.primary),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 16, color: colorScheme.onSurface)),
            const Spacer(),
            Text(
              _isAllDay 
                ? DateFormat('yyyy年MM月dd日').format(dt)
                : DateFormat('MM月dd日 HH:mm').format(dt),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}