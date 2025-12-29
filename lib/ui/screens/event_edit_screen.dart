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
    final initialDate = isStart ? _startTime : _endTime;
    FocusScope.of(context).unfocus(); // 打开弹窗前先收起键盘

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // [关键修改] 彻底移除了 MediaQuery.of(context).viewInsets.bottom
    // 这样键盘动的时候，页面绝对不会重绘，从根源上杜绝闪退

    return Scaffold(
      // [关键配置] 禁止页面随键盘顶起
      resizeToAvoidBottomInset: false,
      
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
          // [关键配置] 这里的 padding 是固定的，不再随键盘变化
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                TextFormField(
                  controller: _titleController,
                  style: theme.textTheme.headlineSmall,
                  decoration: const InputDecoration(
                    hintText: '输入标题',
                    border: InputBorder.none,
                  ),
                  validator: (value) => value == null || value.isEmpty ? '请输入标题' : null,
                ),
                
                const Divider(),
                
                // 全天开关
                SwitchListTile(
                  title: const Text('全天'),
                  value: _isAllDay,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    FocusScope.of(context).unfocus(); // 点击开关收起键盘
                    setState(() => _isAllDay = val);
                  },
                ),
                
                // 时间选择
                _buildDateTimeField('开始时间', _startTime, true, colorScheme),
                const SizedBox(height: 12),
                _buildDateTimeField('结束时间', _endTime, false, colorScheme),
                
                const Divider(height: 32),
                
                // 地点
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: '地点',
                    prefixIcon: Icon(Icons.location_on_outlined, color: colorScheme.outline),
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
                    labelText: '备注',
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

                // [关键修改] 手动加一个超级大的底部垫片
                // 这样当键盘弹出来挡住下面的输入框时，你可以手动滑动屏幕，把内容顶上去
                const SizedBox(height: 400), 
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
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 20, color: colorScheme.outline),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 16, color: colorScheme.onSurface)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _isAllDay 
                  ? DateFormat('yyyy年MM月dd日').format(dt)
                  : DateFormat('MM月dd日 HH:mm').format(dt),
                style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}