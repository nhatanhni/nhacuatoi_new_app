import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:iot_app/bloc/scheduler/scheduler_bloc.dart';
import 'package:iot_app/bloc/scheduler/scheduler_event.dart';
import 'package:iot_app/bloc/scheduler/scheduler_state.dart';
import 'package:iot_app/models/device.dart';
import 'package:iot_app/repository/scheduler_repository.dart';
import 'package:iot_app/widgets/schedule_tag_widget.dart';
import 'package:numberpicker/numberpicker.dart';

class DeviceSchedulingScreen extends StatelessWidget {
  static const routeName = '/device_schedule';

  final Device device;

  const DeviceSchedulingScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SchedulerBloc(
        schedulerRepository: SchedulerRepository(),
      )..add(SchedulerLoadRequested(device.deviceSerial)),
      child: _DeviceSchedulingView(device: device),
    );
  }
}

class _DeviceSchedulingView extends StatelessWidget {
  final Device device;

  const _DeviceSchedulingView({required this.device});

  void _showScheduleSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ScheduleFormSheet(
        title: 'Thêm lịch hẹn giờ',
        onSubmit: (hour, minute, duration, repeat) {
          context.read<SchedulerBloc>().add(
                SchedulerCreateRequested(
                  serial: device.deviceSerial,
                  deviceName: device.deviceName,
                  hour: hour,
                  minute: minute,
                  duration: duration,
                  repeat: repeat,
                ),
              );
        },
      ),
    );
  }

  void _showEditSheet(
    BuildContext context,
    String id,
    int hour,
    int minute,
    int duration,
    int repeat,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ScheduleFormSheet(
        title: 'Sửa lịch hẹn giờ',
        initialHour: hour,
        initialMinute: minute,
        initialDuration: duration,
        initialRepeat: repeat,
        onSubmit: (h, m, dur, rep) {
          context.read<SchedulerBloc>().add(
                SchedulerUpdateRequested(
                  id: id,
                  serial: device.deviceSerial,
                  updates: {
                    "time":
                        "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}",
                    "numberTime": dur,
                    "repeat": rep,
                    "updateTime": DateTime.now().toIso8601String(),
                  },
                ),
              );
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog.adaptive(
          title: const Text("Xác nhận xóa"),
          content:
              const Text("Bạn có chắc chắn muốn xóa lịch hẹn này không?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Huỷ",
                  style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () {
                context.read<SchedulerBloc>().add(
                      SchedulerDeleteRequested(
                        id: id,
                        serial: device.deviceSerial,
                      ),
                    );
                Navigator.of(dialogContext).pop();
              },
              child: const Text("Xóa", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hẹn giờ thiết bị"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: BlocConsumer<SchedulerBloc, SchedulerState>(
          listenWhen: (previous, current) =>
              current is SchedulerActionSuccess ||
              current is SchedulerActionFailure ||
              current is SchedulerLoadFailure,
          listener: (context, state) {
            if (state is SchedulerActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Theme.of(context).primaryColor,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            } else if (state is SchedulerActionFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                ),
              );
            } else if (state is SchedulerLoadFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'Thử lại',
                    textColor: Colors.white,
                    onPressed: () => context.read<SchedulerBloc>().add(
                          SchedulerLoadRequested(device.deviceSerial),
                        ),
                  ),
                ),
              );
            }
          },
          buildWhen: (previous, current) =>
              current is SchedulerLoadInProgress ||
              current is SchedulerLoadSuccess ||
              current is SchedulerLoadFailure ||
              current is SchedulerActionInProgress ||
              current is SchedulerActionSuccess ||
              current is SchedulerActionFailure,
          builder: (context, state) {
            if (state is SchedulerLoadInProgress) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }

            final schedules = switch (state) {
              SchedulerLoadSuccess(:final schedules) => schedules,
              SchedulerActionInProgress(:final schedules) => schedules,
              SchedulerActionSuccess(:final schedules) => schedules,
              SchedulerActionFailure(:final schedules) => schedules,
              _ => <Map<String, dynamic>>[],
            };

            final isActionInProgress = state is SchedulerActionInProgress;

            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SchedulerHeader(
                      device: device,
                      scheduleCount: schedules.length,
                      onAddPressed: isActionInProgress
                          ? null
                          : () => _showScheduleSheet(context),
                    ),
                    if (schedules.isEmpty)
                      const Expanded(
                        child: Center(
                          child:
                              Text("Chưa có hẹn giờ cho thiết bị này."),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: schedules.length,
                          itemBuilder: (context, index) {
                            final schedule = schedules[index];
                            return _ScheduleItem(
                              schedule: schedule,
                              isDisabled: isActionInProgress,
                              onEdit: () => _showEditSheet(
                                context,
                                schedule['Id'],
                                int.parse(schedule['Time'].split(":")[0]),
                                int.parse(schedule['Time'].split(":")[1]),
                                schedule['NumberTime'],
                                schedule['Repeat'],
                              ),
                              onDelete: () => _showDeleteConfirmDialog(
                                  context, schedule['Id']),
                              onToggleStatus: (value) {
                                final updated =
                                    Map<String, dynamic>.from(schedule);
                                updated['Status'] = value ? 1 : 0;
                                context.read<SchedulerBloc>().add(
                                      SchedulerUpdateRequested(
                                        id: schedule['Id'],
                                        serial: device.deviceSerial,
                                        updates: updated,
                                      ),
                                    );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
                if (isActionInProgress)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black12,
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Form bottom sheet
// ---------------------------------------------------------------------------

class _ScheduleFormSheet extends StatefulWidget {
  final String title;
  final int initialHour;
  final int initialMinute;
  final int initialDuration;
  final int initialRepeat;
  final void Function(int hour, int minute, int duration, int repeat) onSubmit;

  const _ScheduleFormSheet({
    required this.title,
    required this.onSubmit,
    this.initialHour = 0,
    this.initialMinute = 0,
    this.initialDuration = 0,
    this.initialRepeat = 0,
  });

  @override
  State<_ScheduleFormSheet> createState() => _ScheduleFormSheetState();
}

class _ScheduleFormSheetState extends State<_ScheduleFormSheet> {
  late int _hour;
  late int _minute;
  late int _duration;
  late bool _repeat;
  late final TextEditingController _durationController;
  String? _durationError;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialHour;
    _minute = widget.initialMinute;
    _duration = widget.initialDuration;
    _repeat = widget.initialRepeat == 1;
    _durationController = TextEditingController(
      text: _duration > 0 ? _duration.toString() : '',
    );
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final parts = <String>[
      if (h > 0) '$h giờ',
      if (m > 0) '$m phút',
      if (s > 0) '$s giây',
    ];
    return parts.isEmpty ? '' : parts.join(' ');
  }

  void _onDurationChanged(String value) {
    final parsed = int.tryParse(value) ?? 0;
    setState(() {
      if (parsed > 86400) {
        _duration = 86400;
        _durationController.text = '86400';
        _durationController.selection = TextSelection.collapsed(
          offset: _durationController.text.length,
        );
      } else {
        _duration = parsed;
      }
      _durationError = null;
    });
  }

  void _submit() {
    if (_duration <= 0) {
      setState(() => _durationError = 'Vui lòng nhập thời lượng lớn hơn 0');
      return;
    }
    Navigator.of(context).pop();
    widget.onSubmit(_hour, _minute, _duration, _repeat ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final humanDuration = _formatDuration(_duration);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                widget.title,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              // Time preview banner
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.schedule,
                        color: colorScheme.onPrimaryContainer, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Lịch sẽ chạy lúc '
                      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Time pickers
              Text('Chọn giờ',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    NumberPicker(
                      itemHeight: 40,
                      textStyle: TextStyle(
                          fontSize: 15,
                          color: colorScheme.onSurfaceVariant),
                      selectedTextStyle: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary),
                      zeroPad: true,
                      haptics: true,
                      value: _hour,
                      infiniteLoop: true,
                      minValue: 0,
                      maxValue: 23,
                      onChanged: (v) => setState(() => _hour = v),
                    ),
                    Text(
                      ':',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary),
                    ),
                    NumberPicker(
                      itemHeight: 40,
                      textStyle: TextStyle(
                          fontSize: 15,
                          color: colorScheme.onSurfaceVariant),
                      selectedTextStyle: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary),
                      infiniteLoop: true,
                      zeroPad: true,
                      haptics: true,
                      value: _minute,
                      minValue: 0,
                      maxValue: 59,
                      onChanged: (v) => setState(() => _minute = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Duration field
              TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'Thời lượng (giây)',
                  errorText: _durationError,
                  helperText:
                      humanDuration.isNotEmpty ? humanDuration : null,
                  helperStyle:
                      TextStyle(color: colorScheme.primary),
                  suffixIcon: const Icon(Icons.timer_outlined),
                ),
                onChanged: _onDurationChanged,
              ),
              const SizedBox(height: 4),
              // Repeat toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Lặp lại hằng ngày'),
                subtitle: Text(
                  _repeat ? 'Chạy mỗi ngày' : 'Chỉ chạy một lần',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                value: _repeat,
                onChanged: (v) => setState(() => _repeat = v),
              ),
              const SizedBox(height: 8),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Huỷ'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Lưu lịch'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SchedulerHeader extends StatelessWidget {
  final Device device;
  final int scheduleCount;
  final VoidCallback? onAddPressed;

  const _SchedulerHeader({
    required this.device,
    required this.scheduleCount,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).focusColor),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Serial: ${device.deviceSerial}",
                  style: const TextStyle(fontSize: 16)),
              Text("Số lịch hẹn đã đặt: $scheduleCount",
                  style: const TextStyle(fontSize: 16)),
            ],
          ),
          ElevatedButton.icon(
            onPressed: onAddPressed,
            icon: const Icon(Icons.add, size: 18),
            label: const Text("Thêm"),
          ),
        ],
      ),
    );
  }
}

class _ScheduleItem extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final bool isDisabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleStatus;

  const _ScheduleItem({
    required this.schedule,
    required this.isDisabled,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: Key(schedule['Id'].toString()),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: isDisabled ? null : (_) => onEdit(),
            icon: Icons.edit,
            backgroundColor: Theme.of(context).primaryColor,
          ),
          SlidableAction(
            onPressed: isDisabled ? null : (_) => onDelete(),
            icon: Icons.delete,
            backgroundColor: Colors.deepOrangeAccent[100]!,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 1.0)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListTile(
          title: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              "Lịch chạy | ${schedule['Repeat'] == 1 ? 'Lặp lại hằng ngày' : 'Chỉ hôm nay'}",
            ),
          ),
          subtitle: Row(
            children: [
              ScheduleTag(
                icon: Icons.alarm,
                text: schedule["Time"],
                textColor: Colors.black,
                color: Theme.of(context).primaryColorLight,
              ),
              const SizedBox(width: 10),
              ScheduleTag(
                icon: Icons.timer,
                text: "${schedule['NumberTime']}s",
                textColor: Colors.black,
                color: Colors.deepOrangeAccent[100]!,
              ),
            ],
          ),
          trailing: Switch(
            value: schedule['Status'] == 1,
            onChanged: isDisabled ? null : onToggleStatus,
          ),
        ),
      ),
    );
  }
}
