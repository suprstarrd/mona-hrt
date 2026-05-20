import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mona/controllers/occurrences_manager.dart';
import 'package:mona/controllers/schedule_manager.dart';
import 'package:mona/data/model/administration_route.dart';
import 'package:mona/data/model/date.dart';
import 'package:mona/data/model/medication_intake.dart';
import 'package:mona/data/model/medication_schedule.dart';
import 'package:mona/data/model/molecule.dart';
import 'package:mona/data/model/scheduled_occurrence.dart';
import 'package:mona/data/model/scheduling_strategy.dart';

@GenerateNiceMocks([
  MockSpec<OccurrencesManager>(),
])
import 'schedule_manager_test.mocks.dart';

MedicationSchedule schedule({int id = 1, SchedulingStrategy? scheduling}) =>
    MedicationSchedule(
      id: id,
      name: 'Med',
      dose: Decimal.one,
      scheduling: scheduling ?? IntervalDaysSchedule(intervalDays: 1),
      molecule: KnownMolecules.estradiol,
      administrationRoute: AdministrationRoute.oral,
    );

ScheduledOccurrence occurrence({
  MedicationSchedule? schedule,
  ScheduleStatus status = ScheduleStatus.today,
  TimeOfDay? time,
  MedicationIntake? intake,
}) =>
    ScheduledOccurrence(
      schedule: schedule ??
          MedicationSchedule(
            id: 0,
            name: 'Med',
            dose: Decimal.one,
            scheduling: IntervalDaysSchedule(intervalDays: 1),
            molecule: KnownMolecules.estradiol,
            administrationRoute: AdministrationRoute.oral,
          ),
      date: Date.today(),
      status: status,
      notifiable: true,
      time: time,
      intake: intake,
    );

void main() {
  late MockOccurrencesManager occurrences;
  late ScheduleManager manager;

  setUp(() {
    occurrences = MockOccurrencesManager();
    manager = ScheduleManager(occurrences);
  });

  group('getSlots', () {
    test('returns empty list when there are no schedules', () {
      when(occurrences.current()).thenReturn([]);

      expect(manager.getSlots(), isEmpty);
    });

    test('maps occurrence status / time / intake onto each slot', () {
      final intake = MedicationIntake(
        id: 99,
        dose: Decimal.one,
        takenDateTime: DateTime.utc(2025, 1, 1, 8),
        takenTimeZone: 'Etc/UTC',
        molecule: KnownMolecules.estradiol,
        administrationRoute: AdministrationRoute.oral,
      );
      final s = schedule(id: 1);
      const time = TimeOfDay(hour: 8, minute: 0);

      when(occurrences.current()).thenReturn([
        occurrence(
          schedule: s,
          status: ScheduleStatus.taken,
          time: time,
          intake: intake,
        ),
      ]);

      final slot = manager.getSlots().single;

      expect(slot.schedule, s);
      expect(slot.status, ScheduleStatus.taken);
      expect(slot.time, time);
      expect(slot.intake, intake);
    });

    test('flattens multiple occurrences from a single schedule', () {
      final s = schedule(id: 1);

      when(occurrences.current()).thenReturn([
        occurrence(schedule: s, time: const TimeOfDay(hour: 8, minute: 0)),
        occurrence(schedule: s, time: const TimeOfDay(hour: 14, minute: 0)),
        occurrence(schedule: s, time: const TimeOfDay(hour: 20, minute: 0)),
      ]);

      expect(manager.getSlots(), hasLength(3));
    });

    test('preserves schedule order across multiple schedules', () {
      final a = schedule(id: 1);
      final b = schedule(id: 2);

      when(occurrences.current()).thenReturn([
        occurrence(schedule: a, status: ScheduleStatus.upcoming),
        occurrence(schedule: b, status: ScheduleStatus.overdue),
      ]);

      final slots = manager.getSlots();

      expect(slots[0].schedule, a);
      expect(slots[1].schedule, b);
    });
  });

  group('splitSlotsByDay', () {
    test('returns two empty lists when there are no schedules', () {
      when(occurrences.current()).thenReturn([]);

      final split = manager.splitSlotsByDay();

      expect(split.today, isEmpty);
      expect(split.upcoming, isEmpty);
    });

    test('routes upcoming status to `upcoming`, everything else to `today`',
        () {
      final a = schedule(id: 1);
      final b = schedule(id: 2);
      final c = schedule(id: 3);
      final d = schedule(id: 4);

      when(occurrences.current()).thenReturn([
        occurrence(schedule: a, status: ScheduleStatus.today),
        occurrence(schedule: b, status: ScheduleStatus.taken),
        occurrence(schedule: c, status: ScheduleStatus.upcoming),
        occurrence(schedule: d, status: ScheduleStatus.overdue),
      ]);

      final split = manager.splitSlotsByDay();

      expect(split.today.map((s) => s.schedule), [d, a, b]);
      expect(split.upcoming.map((s) => s.schedule), [c]);
    });

    test('places overdue and todayOverdue first within today, preserving order',
        () {
      final a = schedule(id: 1);
      final b = schedule(id: 2);
      final c = schedule(id: 3);

      when(occurrences.current()).thenReturn([
        occurrence(schedule: a, status: ScheduleStatus.today),
        occurrence(schedule: b, status: ScheduleStatus.todayOverdue),
        occurrence(schedule: c, status: ScheduleStatus.overdue),
      ]);

      final split = manager.splitSlotsByDay();

      expect(split.today.map((s) => s.schedule), [b, c, a]);
    });

    test('sorts non-overdue today slots by time, with null times first', () {
      final s = schedule(id: 1);

      when(occurrences.current()).thenReturn([
        occurrence(schedule: s, time: const TimeOfDay(hour: 20, minute: 30)),
        occurrence(schedule: s),
        occurrence(schedule: s, time: const TimeOfDay(hour: 8, minute: 0)),
        occurrence(schedule: s, time: const TimeOfDay(hour: 14, minute: 0)),
      ]);

      final times = manager.splitSlotsByDay().today.map((s) => s.time).toList();

      expect(times, [
        null,
        const TimeOfDay(hour: 8, minute: 0),
        const TimeOfDay(hour: 14, minute: 0),
        const TimeOfDay(hour: 20, minute: 30),
      ]);
    });
  });
}
