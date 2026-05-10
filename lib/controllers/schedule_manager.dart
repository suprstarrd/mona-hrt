import 'package:flutter/material.dart';
import 'package:mona/data/model/date.dart';
import 'package:mona/data/model/medication_schedule.dart';
import 'package:mona/data/providers/medication_intake_provider.dart';
import 'package:mona/data/providers/medication_schedule_provider.dart';

enum ScheduleStatus { overdue, todayOverdue, today, upcoming, taken }

class ScheduleSlot {
  final MedicationSchedule schedule;
  final ScheduleStatus status;
  final TimeOfDay? time;
  final bool taken;

  ScheduleSlot({
    required this.schedule,
    required this.status,
    this.time,
    required this.taken,
  });
}

class ScheduleManager {
  final MedicationScheduleProvider _medicationScheduleProvider;
  final MedicationIntakeProvider _medicationIntakeProvider;

  ScheduleManager(
      this._medicationScheduleProvider, this._medicationIntakeProvider);

  List<IntervalDaysSchedule> getSchedulesByStatus(ScheduleStatus status) {
    final List<IntervalDaysSchedule> schedules = [];
    for (final schedule in _medicationScheduleProvider.schedules) {
      if (schedule is! IntervalDaysSchedule) continue;
      final Date? lastTaken = _medicationIntakeProvider
          .getLastIntakeLocalDateForSchedule(schedule.id);

      switch (status) {
        case ScheduleStatus.today:
          if (schedule.isScheduledForToday() &&
              !schedule.isLate(lastTaken) &&
              !schedule.isTakenTodayOrLater(lastTaken)) {
            schedules.add(schedule);
          }
          break;
        case ScheduleStatus.todayOverdue:
          if (schedule.isScheduledForToday() && schedule.isLate(lastTaken)) {
            schedules.add(schedule);
          }
          break;
        case ScheduleStatus.overdue:
          if (!schedule.isScheduledForToday() && schedule.isLate(lastTaken)) {
            schedules.add(schedule);
          }
          break;
        case ScheduleStatus.upcoming:
          if ((!schedule.isScheduledForToday() &&
              !schedule.isLate(lastTaken))) {
            schedules.add(schedule);
          }
          break;
        case ScheduleStatus.taken:
          if (schedule.isScheduledForToday() &&
              schedule.isTakenTodayOrLater(lastTaken)) {
            schedules.add(schedule);
          }
          break;
      }
    }
    return schedules;
  }

  List<ScheduleSlot> getSlots() {
    final List<ScheduleSlot> slots = [];
    for (final schedule in _medicationScheduleProvider.schedules) {
      if (schedule is! IntervalDaysSchedule) continue;

      final Date? lastTaken = _medicationIntakeProvider
          .getLastIntakeLocalDateForSchedule(schedule.id);

      final bool scheduledForToday = schedule.isScheduledForToday();
      final bool late = schedule.isLate(lastTaken);
      final bool taken = schedule.isTakenTodayOrLater(lastTaken);

      final ScheduleStatus status;
      if (scheduledForToday && late) {
        status = ScheduleStatus.todayOverdue;
      } else if (scheduledForToday) {
        status = ScheduleStatus.today;
      } else if (late) {
        status = ScheduleStatus.overdue;
      } else {
        status = ScheduleStatus.upcoming;
      }

      slots.add(ScheduleSlot(
        schedule: schedule,
        status: status,
        time: null,
        taken: taken,
      ));
    }
    return slots;
  }
}
