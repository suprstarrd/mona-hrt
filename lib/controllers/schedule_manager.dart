import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:mona/data/model/date.dart';
import 'package:mona/data/model/medication_intake.dart';
import 'package:mona/data/model/medication_schedule.dart';
import 'package:mona/data/model/scheduling_strategy.dart';
import 'package:mona/data/providers/medication_intake_provider.dart';
import 'package:mona/data/providers/medication_schedule_provider.dart';

class ScheduleSlot {
  final MedicationSchedule schedule;
  final ScheduleStatus status;
  final TimeOfDay? time;
  final MedicationIntake? intake;

  ScheduleSlot({
    required this.schedule,
    required this.status,
    this.time,
    this.intake,
  });
}

class ScheduleManager {
  final MedicationScheduleProvider _medicationScheduleProvider;
  final MedicationIntakeProvider _medicationIntakeProvider;

  ScheduleManager(
      this._medicationScheduleProvider, this._medicationIntakeProvider);

  List<ScheduleSlot> getSlots() {
    final today = Date.today();
    final slots = <ScheduleSlot>[];
    for (final schedule in _medicationScheduleProvider.schedules) {
      switch (schedule.scheduling) {
        case IntervalDaysSchedule s:
          final status =
              s.statusFor(schedule.startDate, _lastTakenFor(schedule));
          slots.add(ScheduleSlot(
            schedule: schedule,
            status: status,
            time: null,
            intake: status == ScheduleStatus.taken
                ? _medicationIntakeProvider
                    .getLastTakenIntakeForSchedule(schedule.id)
                : null,
          ));
        case DailySchedule s:
          final todaysIntakes = _medicationIntakeProvider
              .getTakenIntakesForScheduleOn(schedule.id, today);
          for (final time in s.intakeTimes) {
            final match =
                todaysIntakes.firstWhereOrNull((i) => i.scheduledTime == time);
            slots.add(ScheduleSlot(
              schedule: schedule,
              status: s.statusFor(taken: match != null),
              time: time,
              intake: match,
            ));
          }
      }
    }
    return slots;
  }

  ({List<ScheduleSlot> today, List<ScheduleSlot> upcoming}) splitSlotsByDay() {
    final overdueToday = <ScheduleSlot>[];
    final otherToday = <ScheduleSlot>[];
    final upcoming = <ScheduleSlot>[];

    for (final slot in getSlots()) {
      if (slot.status == ScheduleStatus.upcoming) {
        upcoming.add(slot);
      } else if (slot.status == ScheduleStatus.overdue ||
          slot.status == ScheduleStatus.todayOverdue) {
        overdueToday.add(slot);
      } else {
        otherToday.add(slot);
      }
    }

    otherToday.sort(_byTimeNullsFirst);

    return (today: [...overdueToday, ...otherToday], upcoming: upcoming);
  }

  static int _byTimeNullsFirst(ScheduleSlot a, ScheduleSlot b) {
    final at = a.time;
    final bt = b.time;
    if (at == null && bt == null) return 0;
    if (at == null) return -1;
    if (bt == null) return 1;
    final hourCompare = at.hour.compareTo(bt.hour);
    return hourCompare != 0 ? hourCompare : at.minute.compareTo(bt.minute);
  }

  Date? _lastTakenFor(MedicationSchedule schedule) =>
      _medicationIntakeProvider.getLastIntakeLocalDateForSchedule(schedule.id);
}
