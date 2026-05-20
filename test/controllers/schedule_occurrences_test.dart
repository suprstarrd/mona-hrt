import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mona/controllers/occurrences_manager.dart';
import 'package:mona/data/model/administration_route.dart';
import 'package:mona/data/model/date.dart';
import 'package:mona/data/model/medication_intake.dart';
import 'package:mona/data/model/medication_schedule.dart';
import 'package:mona/data/model/molecule.dart';
import 'package:mona/data/model/scheduling_strategy.dart';
import 'package:mona/data/providers/medication_intake_provider.dart';
import 'package:mona/data/providers/medication_schedule_provider.dart';

@GenerateNiceMocks([
  MockSpec<MedicationIntakeProvider>(),
  MockSpec<MedicationScheduleProvider>(),
])
import 'schedule_occurrences_test.mocks.dart';

MedicationSchedule schedule({
  int id = 1,
  required SchedulingStrategy scheduling,
  Date? startDate,
}) =>
    MedicationSchedule(
      id: id,
      name: 'Med',
      dose: Decimal.one,
      scheduling: scheduling,
      startDate: startDate ?? Date.today(),
      molecule: KnownMolecules.estradiol,
      administrationRoute: AdministrationRoute.oral,
    );

MedicationIntake intakeAt(TimeOfDay time, {int id = 0, int scheduleId = 1}) =>
    MedicationIntake(
      id: id,
      dose: Decimal.one,
      takenDateTime: DateTime.utc(2025, 1, 1, time.hour, time.minute),
      takenTimeZone: 'Etc/UTC',
      scheduleId: scheduleId,
      molecule: KnownMolecules.estradiol,
      administrationRoute: AdministrationRoute.oral,
      scheduledTime: time,
    );

void main() {
  late MockMedicationIntakeProvider intakes;
  late MockMedicationScheduleProvider schedules;
  late OccurrencesManager occurrences;

  setUp(() {
    intakes = MockMedicationIntakeProvider();
    schedules = MockMedicationScheduleProvider();
    when(schedules.schedules).thenReturn([]);
    occurrences = OccurrencesManager(intakes, schedules);
  });

  void withSchedules(List<MedicationSchedule> all) {
    when(schedules.schedules).thenReturn(all);
  }

  group('current — IntervalDaysSchedule', () {
    test('returns exactly one occurrence dated today', () {
      final s = schedule(scheduling: IntervalDaysSchedule(intervalDays: 7));
      withSchedules([s]);

      final result = occurrences.current();

      expect(result, hasLength(1));
      expect(result.single.date, Date.today());
    });

    test('overdue (not scheduled today, past missed) -> status overdue', () {
      final start = Date.today().subtract(const Duration(days: 9));
      final s = schedule(
          id: 7,
          scheduling: IntervalDaysSchedule(intervalDays: 2),
          startDate: start);
      withSchedules([s]);
      when(intakes.getLastIntakeLocalDateForSchedule(7))
          .thenReturn(start); // taken at start, missed since

      expect(occurrences.current().single.status, ScheduleStatus.overdue);
    });

    test('not scheduled today, start in the future -> upcoming', () {
      final s = schedule(
          scheduling: IntervalDaysSchedule(intervalDays: 7),
          startDate: Date.today().add(const Duration(days: 5)));
      withSchedules([s]);

      expect(occurrences.current().single.status, ScheduleStatus.upcoming);
    });

    test('scheduled today, taken today -> taken with last intake attached', () {
      final start = Date.today().subtract(const Duration(days: 14));
      final intake = intakeAt(const TimeOfDay(hour: 8, minute: 0), id: 42);
      final s = schedule(
          id: 7,
          scheduling: IntervalDaysSchedule(intervalDays: 7),
          startDate: start);
      withSchedules([s]);
      when(intakes.getLastIntakeLocalDateForSchedule(7))
          .thenReturn(Date.today());
      when(intakes.getLastTakenIntakeForSchedule(7)).thenReturn(intake);

      final occ = occurrences.current().single;

      expect(occ.status, ScheduleStatus.taken);
      expect(occ.intake, intake);
    });

    test('non-taken occurrence carries no intake', () {
      final s = schedule(scheduling: IntervalDaysSchedule(intervalDays: 7));
      withSchedules([s]);

      expect(occurrences.current().single.intake, isNull);
    });

    test('notifiable mirrors notificationTime presence', () {
      final withTime = schedule(
          id: 1,
          scheduling: IntervalDaysSchedule(
              intervalDays: 7,
              notificationTime: const TimeOfDay(hour: 9, minute: 0)));
      final withoutTime =
          schedule(id: 2, scheduling: IntervalDaysSchedule(intervalDays: 7));
      withSchedules([withTime, withoutTime]);

      final result = occurrences.current();
      expect(
        result.singleWhere((it) => it.schedule.id == withTime.id).notifiable,
        isTrue,
      );
      expect(
        result.singleWhere((it) => it.schedule.id == withoutTime.id).notifiable,
        isFalse,
      );
    });

    test('time mirrors notificationTime', () {
      const t = TimeOfDay(hour: 9, minute: 30);
      final s = schedule(
          scheduling:
              IntervalDaysSchedule(intervalDays: 7, notificationTime: t));
      withSchedules([s]);

      expect(occurrences.current().single.notificationTime, t);
    });
  });

  group('current — DailySchedule', () {
    const morning = TimeOfDay(hour: 8, minute: 0);
    const afternoon = TimeOfDay(hour: 14, minute: 0);
    const evening = TimeOfDay(hour: 20, minute: 30);

    test('emits one occurrence per intakeTime, all dated today', () {
      final s = schedule(
          scheduling:
              const DailySchedule(intakeTimes: [morning, afternoon, evening]));
      withSchedules([s]);
      when(intakes.getTakenIntakesForScheduleOn(1, Date.today()))
          .thenReturn(<MedicationIntake>[]);

      final result = occurrences.current();

      expect(result.map((o) => o.time), [morning, afternoon, evening]);
      expect(result.map((o) => o.date), everyElement(Date.today()));
      expect(result.map((o) => o.status), everyElement(ScheduleStatus.today));
      expect(result.map((o) => o.intake), everyElement(isNull));
    });

    test('matched intake -> taken with intake attached', () {
      final morningIntake = intakeAt(morning, id: 1);
      final eveningIntake = intakeAt(evening, id: 2);
      final s = schedule(
          scheduling:
              const DailySchedule(intakeTimes: [morning, afternoon, evening]));
      withSchedules([s]);
      when(intakes.getTakenIntakesForScheduleOn(1, Date.today()))
          .thenReturn([morningIntake, eveningIntake]);

      final result = occurrences.current();

      expect(
        {for (final o in result) o.time: o.status},
        {
          morning: ScheduleStatus.taken,
          afternoon: ScheduleStatus.today,
          evening: ScheduleStatus.taken,
        },
      );
      expect(
        {for (final o in result) o.time: o.intake},
        {morning: morningIntake, afternoon: null, evening: eveningIntake},
      );
    });

    test('intake with unknown scheduledTime is ignored', () {
      final stray = intakeAt(afternoon);
      final s = schedule(
          scheduling: const DailySchedule(intakeTimes: [morning, evening]));
      withSchedules([s]);
      when(intakes.getTakenIntakesForScheduleOn(1, Date.today()))
          .thenReturn([stray]);

      final result = occurrences.current();

      expect(result.map((o) => o.status), everyElement(ScheduleStatus.today));
      expect(result.map((o) => o.intake), everyElement(isNull));
    });

    test('notifiable mirrors notify flag', () {
      final loud = schedule(
          id: 1, scheduling: const DailySchedule(intakeTimes: [morning]));
      final silent = schedule(
          id: 2,
          scheduling:
              const DailySchedule(intakeTimes: [morning], notify: false));
      withSchedules([loud, silent]);
      when(intakes.getTakenIntakesForScheduleOn(any, any)).thenReturn([]);

      final result = occurrences.current();
      expect(
        result.singleWhere((it) => it.schedule.id == loud.id).notifiable,
        isTrue,
      );
      expect(
        result.singleWhere((it) => it.schedule.id == silent.id).notifiable,
        isFalse,
      );
    });
  });

  group('upcoming — IntervalDaysSchedule', () {
    test('returns `days` future scheduled dates', () {
      final start = Date.today().subtract(const Duration(days: 7));
      final s = schedule(
          scheduling: IntervalDaysSchedule(intervalDays: 7), startDate: start);
      withSchedules([s]);

      final result = occurrences.upcoming(days: 3);

      expect(result, hasLength(3));
      expect(result.first.date, Date.today());
      expect(result[1].date, Date.today().add(const Duration(days: 7)));
      expect(result[2].date, Date.today().add(const Duration(days: 14)));
    });

    test('today-slot status reflects current state (taken)', () {
      final start = Date.today().subtract(const Duration(days: 7));
      final s = schedule(
          id: 7,
          scheduling: IntervalDaysSchedule(intervalDays: 7),
          startDate: start);
      withSchedules([s]);
      when(intakes.getLastIntakeLocalDateForSchedule(7))
          .thenReturn(Date.today());

      final result = occurrences.upcoming(days: 2);

      expect(result.first.status, ScheduleStatus.taken);
    });

    test('future-day slots are upcoming regardless of intake history', () {
      final start = Date.today().subtract(const Duration(days: 7));
      final s = schedule(
          id: 7,
          scheduling: IntervalDaysSchedule(intervalDays: 7),
          startDate: start);
      withSchedules([s]);
      when(intakes.getLastIntakeLocalDateForSchedule(7))
          .thenReturn(Date.today());

      final result = occurrences.upcoming(days: 3);

      expect(result.skip(1).map((o) => o.status),
          everyElement(ScheduleStatus.upcoming));
    });

    test('time mirrors notificationTime on every occurrence', () {
      const t = TimeOfDay(hour: 9, minute: 30);
      final s = schedule(
          scheduling:
              IntervalDaysSchedule(intervalDays: 1, notificationTime: t));
      withSchedules([s]);

      final result = occurrences.upcoming(days: 3);

      expect(result.map((o) => o.notificationTime), everyElement(t));
    });

    test('notifiable mirrors notificationTime presence', () {
      final withoutTime =
          schedule(scheduling: IntervalDaysSchedule(intervalDays: 1));
      withSchedules([withoutTime]);

      final result = occurrences.upcoming(days: 2);

      expect(result.map((o) => o.notifiable), everyElement(isFalse));
    });
  });

  group('upcoming — DailySchedule', () {
    const morning = TimeOfDay(hour: 8, minute: 0);
    const evening = TimeOfDay(hour: 20, minute: 30);

    test('emits `days * intakeTimes` occurrences', () {
      final s = schedule(
          scheduling: const DailySchedule(intakeTimes: [morning, evening]));
      withSchedules([s]);
      when(intakes.getTakenIntakesForScheduleOn(1, Date.today()))
          .thenReturn(<MedicationIntake>[]);

      final result = occurrences.upcoming(days: 3);

      expect(result, hasLength(6));
    });

    test('today slots: matched intake -> taken', () {
      final morningIntake = intakeAt(morning, id: 1);
      final s = schedule(
          scheduling: const DailySchedule(intakeTimes: [morning, evening]));
      withSchedules([s]);
      when(intakes.getTakenIntakesForScheduleOn(1, Date.today()))
          .thenReturn([morningIntake]);

      final result = occurrences.upcoming(days: 1);

      expect(result.first.status, ScheduleStatus.taken);
      expect(result.first.intake, morningIntake);
      expect(result[1].status, ScheduleStatus.today);
    });

    test('future-day slots never carry intake and are upcoming', () {
      final morningIntake = intakeAt(morning, id: 1);
      final s =
          schedule(scheduling: const DailySchedule(intakeTimes: [morning]));
      withSchedules([s]);
      when(intakes.getTakenIntakesForScheduleOn(1, Date.today()))
          .thenReturn([morningIntake]);

      final result = occurrences.upcoming(days: 3);

      expect(result.skip(1).map((o) => o.status),
          everyElement(ScheduleStatus.upcoming));
      expect(result.skip(1).map((o) => o.intake), everyElement(isNull));
    });

    test('notifiable mirrors notify flag for every occurrence', () {
      final silent = schedule(
          scheduling:
              const DailySchedule(intakeTimes: [morning], notify: false));
      withSchedules([silent]);
      when(intakes.getTakenIntakesForScheduleOn(any, any)).thenReturn([]);

      final result = occurrences.upcoming(days: 3);

      expect(result.map((o) => o.notifiable), everyElement(isFalse));
    });
  });
}
