import 'package:flutter/material.dart';
import 'package:mona/data/model/medication_schedule.dart';
import 'package:mona/data/model/scheduling_strategy.dart';
import 'package:mona/data/providers/medication_schedule_provider.dart';
import 'package:mona/l10n/build_context_extensions.dart';
import 'package:mona/ui/constants/dimensions.dart';
import 'package:provider/provider.dart';

class EditScheduleNotificationsPage extends StatefulWidget {
  final MedicationSchedule schedule;
  final bool isNewSchedule;

  EditScheduleNotificationsPage(
      {required this.schedule, this.isNewSchedule = false});

  @override
  State<EditScheduleNotificationsPage> createState() =>
      _EditScheduleNotificationsPageState();
}

class _EditScheduleNotificationsPageState
    extends State<EditScheduleNotificationsPage> {
  late IntervalDaysSchedule _scheduling;
  TimeOfDay? _notificationTime;
  late MedicationScheduleProvider _medicationScheduleProvider;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _notificationTime = picked;
      });
    }
  }

  void _saveChanges() {
    if (!mounted) return;

    final updatedSchedule = widget.schedule.copyWith(
      scheduling: IntervalDaysSchedule(
        intervalDays: _scheduling.intervalDays,
        notificationTime: _notificationTime,
      ),
    );

    if (widget.isNewSchedule) {
      _medicationScheduleProvider.add(updatedSchedule);
      Navigator.of(context)
        ..pop()
        ..pop()
        ..pop();
      return;
    }

    _medicationScheduleProvider.updateSchedule(updatedSchedule);
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    _scheduling = widget.schedule.scheduling as IntervalDaysSchedule;
    _notificationTime = _scheduling.notificationTime;
    _medicationScheduleProvider =
        Provider.of<MedicationScheduleProvider>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    final medicationScheduleProvider =
        context.watch<MedicationScheduleProvider>();
    final localizations = context.l10n;

    if (medicationScheduleProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations.scheduleNotifications),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.scheduleNotifications),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton(
              onPressed: _saveChanges,
              child: Text(localizations.save),
            ),
          ),
        ],
      ),
      floatingActionButton: _notificationTime == null
          ? FloatingActionButton(
              onPressed: _pickTime,
              tooltip: localizations.addNotification,
              child: Icon(Icons.add),
            )
          : null,
      resizeToAvoidBottomInset: false,
      body: _notificationTime == null
          ? Center(
              child: Padding(
                padding: pagePadding,
                child: Text(
                  localizations
                      .noNotificationsForSchedule(widget.schedule.name),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : SafeArea(
              child: ListTile(
                title: Text(_notificationTime!.format(context)),
                leading: Icon(Icons.alarm),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: _pickTime,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        setState(() {
                          _notificationTime = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
