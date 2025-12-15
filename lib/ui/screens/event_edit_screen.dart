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
    
    // 初始化表单数据
    if (widget.event != null) {
      // 编辑模式
      _titleController = TextEditingController(text: widget.event!.title);
      _locationController = TextEditingController(text: widget.event!.location ?? '');
      _descriptionController = TextEditingController(text: widget.event!.description ?? '');
      _startTime = widget.event!.startTime;
      _endTime = widget.event!.endTime;
      _isAllDay = widget.event!.isAllDay;
    } else {
      // 添加模式
      _titleController = TextEditingController();
      _locationController = TextEditingController();
      _descriptionController = TextEditingController();
      _startTime = widget.selectedDate ?? DateTime.now();
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
        
        // 验证结束时间不早于开始时间
        if (!event.isAllDay && event.endTime.isBefore(event.startTime)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('结束时间不能早于开始时间')),
            );
          }
          return;
        }
        
        // 调用保存回调
        await widget.onEventSaved(event);
      } catch (e) {
        print('保存事件时出错: $e');
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
              Navigator.pop(context);
              Navigator.pop(context); // 关闭编辑页面
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _selectStartTime() async {
    try {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_startTime),
        helpText: '选择开始时间',
        cancelText: '取消',
        confirmText: '确定',
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
          // 自动调整结束时间
          if (_endTime.isBefore(_startTime) || _endTime == _startTime) {
            _endTime = _startTime.add(const Duration(hours: 1));
          }
        });
      }
    } catch (e) {
      print('选择开始时间时出错: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择时间失败，请重试')),
        );
      }
    }
  }

  Future<void> _selectEndTime() async {
    try {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_endTime),
        helpText: '选择结束时间',
        cancelText: '取消',
        confirmText: '确定',
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
    } catch (e) {
      print('选择结束时间时出错: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择时间失败，请重试')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _startTime,
        firstDate: DateTime(2000),
        lastDate: DateTime(2050),
        helpText: '选择日期',
        cancelText: '取消',
        confirmText: '确定',
      );
      
      if (picked != null && mounted) {
        setState(() {
          _startTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _startTime.hour,
            _startTime.minute,
          );
          _endTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _endTime.hour,
            _endTime.minute,
          );
        });
      }
    } catch (e) {
      print('选择日期时出错: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择日期失败，请重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event != null ? '编辑事件' : '添加事件'),
        actions: [
          if (widget.event != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                _deleteEvent();
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '事件标题',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入事件标题';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // 全天事件开关
              Row(
                children: [
                  const Text('全天事件'),
                  const SizedBox(width: 8),
                  Switch(
                    value: _isAllDay,
                    onChanged: (value) {
                      setState(() {
                        _isAllDay = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 日期选择
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _selectDate,
                      child: Text(DateFormat('yyyy年MM月dd日').format(_startTime)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 时间选择（如果不是全天事件）
              if (!_isAllDay)
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _selectStartTime,
                            child: Text('开始: ${DateFormat('HH:mm').format(_startTime)}'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _selectEndTime,
                            child: Text('结束: ${DateFormat('HH:mm').format(_endTime)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: '地点（可选）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '描述（可选）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: _saveEvent,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(widget.event != null ? '保存修改' : '添加事件'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}