import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mona/data/model/administration_route.dart';
import 'package:mona/data/model/date.dart';
import 'package:mona/data/model/ester.dart';
import 'package:mona/data/model/medication_schedule.dart';
import 'package:mona/data/model/molecule.dart';
import 'package:mona/data/model/scheduling_strategy.dart';
import 'package:mona/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('MedicationSchedule', () {
    test('toMap and fromMap should preserve values', () {
      final schedule = MedicationSchedule(
        id: 1,
        name: 'Test Med',
        dose: Decimal.parse('10.5'),
        scheduling: IntervalDaysSchedule(
          intervalDays: 7,
          notificationTime: const TimeOfDay(hour: 8, minute: 30),
        ),
        startDate: Date.today(),
        molecule: KnownMolecules.estradiol,
        administrationRoute: AdministrationRoute.injection,
        ester: Ester.cypionate,
      );

      final map = schedule.toMap();
      final fromMap =
          MedicationScheduleMapper.fromMap(Map<String, dynamic>.from(map));

      expect(
        fromMap,
        isA<MedicationSchedule>()
            .having((s) => s.id, 'id', schedule.id)
            .having((s) => s.name, 'name', schedule.name)
            .having((s) => s.dose, 'dose', schedule.dose)
            .having((s) => s.scheduling, 'scheduling', schedule.scheduling)
            .having((s) => s.startDate, 'startDate', schedule.startDate)
            .having((s) => s.molecule, 'molecule', schedule.molecule)
            .having((s) => s.administrationRoute, 'administrationRoute',
                schedule.administrationRoute)
            .having((s) => s.ester, 'ester', schedule.ester),
      );
    });

    test('schedulingStrategy is encoded as a JSON string in the map', () {
      final schedule = MedicationSchedule(
        name: 'Test Med',
        dose: Decimal.parse('10.5'),
        scheduling: IntervalDaysSchedule(intervalDays: 7),
        molecule: KnownMolecules.estradiol,
        administrationRoute: AdministrationRoute.oral,
      );

      final map = schedule.toMap();

      // The JsonStringHook on the field flattens it into a TEXT-safe string.
      expect(map['schedulingStrategy'], isA<String>());
      expect(map['schedulingStrategy'], contains('"type":"intervalDays"'));
    });

    test('validateName works correctly', () {
      expect(
        [
          MedicationSchedule.validateName(l10n, null),
          MedicationSchedule.validateName(l10n, ''),
          MedicationSchedule.validateName(l10n, 'Valid'),
        ],
        [isNotNull, isNotNull, isNull],
      );
    });

    test('validateDose works correctly', () {
      expect(
        [
          MedicationSchedule.validateDose(l10n, null),
          MedicationSchedule.validateDose(l10n, ''),
          MedicationSchedule.validateDose(l10n, '0'),
          MedicationSchedule.validateDose(l10n, '-1'),
          MedicationSchedule.validateDose(l10n, 'abc'),
          MedicationSchedule.validateDose(l10n, '2.5'),
        ],
        [isNotNull, isNotNull, isNotNull, isNotNull, isNotNull, isNull],
      );
    });

    test('validateStartDate works correctly', () {
      final cases = [
        {'value': null, 'expected': isNotNull},
        {'value': Date.today(), 'expected': isNull},
      ];

      final results = cases
          .map((c) => MedicationSchedule.validateStartDate(
                l10n,
                c['value'] as Date?,
              ))
          .toList();
      final expected = cases.map((c) => c['expected'] as Matcher).toList();

      expect(results, expected);
    });

    test('validateMolecule works correctly', () {
      final cases = [
        {'value': null, 'expected': isNotNull},
        {'value': KnownMolecules.decapeptyl, 'expected': isNull},
      ];

      final results = cases
          .map((c) => MedicationSchedule.validateMolecule(
                l10n,
                c['value'] as Molecule?,
              ))
          .toList();
      final expected = cases.map((c) => c['expected'] as Matcher).toList();

      expect(results, expected);
    });

    test('validateAdministrationRoute works correctly', () {
      final cases = [
        {'value': null, 'expected': isNotNull},
        {'value': AdministrationRoute.implant, 'expected': isNull},
      ];

      final results = cases
          .map((c) => MedicationSchedule.validateAdministrationRoute(
                l10n,
                c['value'] as AdministrationRoute?,
              ))
          .toList();
      final expected = cases.map((c) => c['expected'] as Matcher).toList();

      expect(results, expected);
    });

    test('validateEster works correctly', () {
      final cases = [
        {
          'molecule': null,
          'route': null,
          'value': null,
          'expected': isNull,
        },
        {
          'molecule': KnownMolecules.estradiol,
          'route': AdministrationRoute.injection,
          'value': null,
          'expected': isNotNull,
        },
        {
          'molecule': KnownMolecules.estradiol,
          'route': AdministrationRoute.injection,
          'value': Ester.enanthate,
          'expected': isNull,
        },
        {
          'molecule': KnownMolecules.estradiol,
          'route': AdministrationRoute.oral,
          'value': Ester.enanthate,
          'expected': isNull,
        },
        {
          'molecule': KnownMolecules.estradiol,
          'route': AdministrationRoute.oral,
          'value': null,
          'expected': isNull,
        },
      ];

      final results = cases.map((c) {
        final validator = MedicationSchedule.esterValidator(
          l10n,
          c['molecule'] as Molecule?,
          c['route'] as AdministrationRoute?,
        );
        return validator(c['value'] as Ester?);
      }).toList();
      final expected = cases.map((c) => c['expected'] as Matcher).toList();

      expect(results, expected);
    });
  });
}
