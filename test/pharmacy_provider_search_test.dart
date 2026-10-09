import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:business_manager/data/models/industry_specific/pharmacy/drug_model.dart';
import 'package:business_manager/data/models/industry_specific/pharmacy/patient_model.dart';
import 'package:business_manager/data/models/industry_specific/pharmacy/prescription_model.dart';
import 'package:business_manager/data/repositories/industry_specific/pharmacy_repository_impl.dart';
import 'package:business_manager/providers/pharmacy_provider.dart';

class _StubPharmacyRepository extends PharmacyRepositoryImpl {
  _StubPharmacyRepository()
      : super(
          http: Dio(),
          supabase: SupabaseClient('https://example.supabase.co', 'anon-key'),
        );

  @override
  Future<List<DrugModel>> fetchDrugs({String? businessId}) async => const [];

  @override
  Future<List<PrescriptionModel>> fetchPrescriptions({String? businessId}) async => const [];

  @override
  Future<List<Map<String, dynamic>>> fetchTreatments({String? businessId}) async => const [];

  @override
  Future<List<PatientModel>> fetchPatients({String? businessId}) async => const [];
}

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pharmacy-search-');
    Hive.init(hiveDirectory.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  group('PharmacyProvider search', () {
    test('matches drugs by name or manufacturer', () async {
      final provider = PharmacyProvider();

      await provider.addDrug(
        Drug(
          id: 'd1',
          name: 'Panadol Extra',
          batch: 'GSK Nigeria',
          expiry: DateTime.now().add(const Duration(days: 90)),
          stock: 25,
          price: 150,
          costPrice: 100,
        ),
      );

      await provider.addDrug(
        Drug(
          id: 'd2',
          name: 'Vitamin C',
          batch: 'NatureLabs',
          expiry: DateTime.now().add(const Duration(days: 45)),
          stock: 9,
          price: 220,
          costPrice: 150,
        ),
      );

      expect(provider.searchDrugs('panadol').map((d) => d.id), contains('d1'));
      expect(provider.searchDrugs('gsk').map((d) => d.id), contains('d1'));
      expect(provider.searchDrugs('nature').map((d) => d.id), contains('d2'));
    });

    test('generates treatment sessions and tracks completion status', () async {
      final provider = PharmacyProvider();
      final treatment = Treatment(
        id: 'treatment-1',
        patientId: 'patient-1',
        name: 'Injection course',
        drugName: 'Example injection',
        dosage: '1 dose',
        frequencyPerDay: 2,
        durationDays: 3,
        startDate: DateTime(2026, 10, 7),
      );

      expect(treatment.totalDosesExpected, 6);
      expect(treatment.sessions.first['label'], 'Day 1 Morning');
      expect(treatment.sessions[1]['label'], 'Day 1 Evening');

      await provider.addTreatment(treatment);
      await provider.updateTreatmentSessionStatus(
        treatment.id,
        0,
        'completed',
      );

      expect(treatment.dosesGiven, 1);
      expect(treatment.sessions.first['status'], 'completed');
    });

    test('marks a treatment inactive after the final scheduled session completes', () async {
      final provider = PharmacyProvider();
      final treatment = Treatment(
        id: 'treatment-2',
        patientId: 'patient-2',
        name: 'Oral course',
        drugName: 'Medicine A',
        dosage: '1 tablet',
        frequencyPerDay: 1,
        durationDays: 2,
        startDate: DateTime(2026, 10, 7),
      );

      await provider.addTreatment(treatment);
      for (final session in treatment.sessions) {
        await provider.updateTreatmentSessionStatus(
          treatment.id,
          session['index'] as int,
          'completed',
        );
      }

      expect(treatment.sessions.every((session) => session['status'] == 'completed'), isTrue);
      expect(treatment.isActive, isFalse);
    });

    test('keeps locally created patients when remote patient fetch is empty', () async {
      final provider = PharmacyProvider(repository: _StubPharmacyRepository());
      final patient = Patient(
        id: 'local-patient-1',
        name: 'Ada Local',
        phone: '08000000001',
      );

      await provider.addPatient(patient, persist: false);
      await provider.loadFromRepository(businessId: 'biz-1');

      expect(provider.patients.any((item) => item.id == patient.id), isTrue);
    });
  });
}
