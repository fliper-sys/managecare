import 'package:flutter/material.dart';
import '../../../../widgets/profile_avatar.dart';
import 'package:provider/provider.dart';
import '../../../../providers/pharmacy_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/theme/colors.dart';
import 'prescription_detail_screen.dart';

class PatientRecordsScreen extends StatefulWidget {
  const PatientRecordsScreen({super.key});

  @override
  State<PatientRecordsScreen> createState() => _PatientRecordsScreenState();
}

class _PatientRecordsScreenState extends State<PatientRecordsScreen> {
  String _searchQuery = '';
  String _sortBy = 'name'; // name, prescriptions, recent

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PharmacyProvider>();
      final business = context.read<BusinessProvider>().currentBusiness;
      if (business != null) {
        provider.loadFromRepository(businessId: business.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Records'),
        backgroundColor: AppColors.pharmacy,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final provider = context.read<PharmacyProvider>();
              final business = context.read<BusinessProvider>().currentBusiness;
              if (business != null) {
                provider.loadFromRepository(businessId: business.id);
              }
            },
          ),
        ],
      ),
      body: Consumer<PharmacyProvider>(
        builder: (context, provider, child) {
          var patients = provider.getPatientsWithPrescriptionCount();

          // Apply search filter
          if (_searchQuery.isNotEmpty) {
            patients = patients
                .where((p) => (p['name'] as String)
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()))
                .toList();
          }

          // Apply sorting
          switch (_sortBy) {
            case 'name':
              patients.sort((a, b) =>
                  (a['name'] as String).compareTo(b['name'] as String));
              break;
            case 'prescriptions':
              patients.sort((a, b) => (b['prescriptionCount'] as int)
                  .compareTo(a['prescriptionCount'] as int));
              break;
            case 'recent':
              patients.sort((a, b) {
                final dateA = a['lastPrescriptionDate'] as DateTime?;
                final dateB = b['lastPrescriptionDate'] as DateTime?;
                if (dateA == null && dateB == null) return 0;
                if (dateA == null) return 1;
                if (dateB == null) return -1;
                return dateB.compareTo(dateA);
              });
              break;
          }

          if (patients.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No patients found',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Search and sort controls
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search patients...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Sort by: '),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _sortBy,
                            items: const [
                              DropdownMenuItem(
                                value: 'name',
                                child: Text('Patient Name'),
                              ),
                              DropdownMenuItem(
                                value: 'prescriptions',
                                child: Text('Prescriptions (Most)'),
                              ),
                              DropdownMenuItem(
                                value: 'recent',
                                child: Text('Recently Active'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _sortBy = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Patients list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: patients.length,
                  itemBuilder: (context, index) {
                    final patient = patients[index];
                    final prescriptionCount =
                        patient['prescriptionCount'] as int;
                    final activeTreatmentCount =
                        patient['activeTreatmentCount'] as int? ?? 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: ProfileAvatar(
                          photoUrl: (patient['photoUrl'] ?? patient['photo_url']) as String?,
                          initials: (patient['name'] as String).isNotEmpty ? (patient['name'] as String)[0].toUpperCase() : '?',
                          backgroundColor: Colors.green.shade100,
                        ),
                        title: Text(patient['name'] as String,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Phone: ${patient['phone']}'),
                            Text(
                              'Prescriptions: $prescriptionCount',
                              style: TextStyle(
                                color: prescriptionCount > 5
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                            if (activeTreatmentCount > 0)
                              Text(
                                'Active treatments: $activeTreatmentCount',
                                style: TextStyle(color: Colors.blueGrey[700]),
                              ),
                            if (patient['lastPrescriptionDate'] != null)
                              Text(
                                'Last Rx: ${(patient['lastPrescriptionDate'] as DateTime).toString().split(' ')[0]}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            if (patient['lastTreatmentDate'] != null)
                              Text(
                                'Last treatment: ${(patient['lastTreatmentDate'] as DateTime).toString().split(' ')[0]}',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            _showPatientDetails(context, patient, provider),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.pharmacy,
        onPressed: () => _showAddPatientDialog(context),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _showPatientDetails(BuildContext context, Map<String, dynamic> patient,
      PharmacyProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final patientHistory =
            provider.getPatientPrescriptionHistory(patient['id'] as String);
        final activeTreatments = provider.getActivePatientTreatments(patient['id'] as String);
        final treatmentHistory = provider.getPatientTreatmentHistory(patient['id'] as String);

        return DefaultTabController(
          length: 3,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient['name'] as String,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildDetailRow('Phone', patient['phone'] as String),
                if (patient['email'] != null && (patient['email'] as String).isNotEmpty)
                  _buildDetailRow('Email', patient['email'] as String),
                if (patient['address'] != null && (patient['address'] as String).isNotEmpty)
                  _buildDetailRow('Address', patient['address'] as String),
                if (patient['dateOfBirth'] != null)
                  _buildDetailRow(
                    'Age',
                    (provider.calculateAge(patient['dateOfBirth'] as DateTime?)
                            ?.toString()) ??
                        'N/A',
                  ),
                if (patient['allergies'] != null && (patient['allergies'] as String).isNotEmpty)
                  _buildDetailRow('Allergies', patient['allergies'] as String),
                if (patient['bloodType'] != null && (patient['bloodType'] as String).isNotEmpty)
                  _buildDetailRow('Blood Type', patient['bloodType'] as String),
                if (patient['additionalNotes'] != null && (patient['additionalNotes'] as String).isNotEmpty)
                  _buildDetailRow('Notes', patient['additionalNotes'] as String),
                _buildDetailRow('ID', patient['id'] as String),
                _buildDetailRow(
                    'Total Prescriptions', '${patient['prescriptionCount']}'),
                _buildDetailRow(
                    'Active Treatments', '${patient['activeTreatmentCount'] ?? 0}'),
                _buildDetailRow(
                    'Completed Treatments', '${patient['completedTreatmentCount'] ?? 0}'),
                const SizedBox(height: 16),
                const TabBar(
                  tabs: [
                    Tab(text: 'Prescriptions'),
                    Tab(text: 'Active Treatments'),
                    Tab(text: 'Treatment History'),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: TabBarView(
                    children: [
                      // Prescriptions tab
                      patientHistory.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('No prescriptions',
                                  style: TextStyle(color: Colors.grey)),
                            )
                          : ListView(
                              children: patientHistory.take(5).map((pres) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: InkWell(
                                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => PrescriptionDetailScreen(prescriptionId: pres.id))),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(pres.id),
                                      Chip(
                                        label: Text(pres.status),
                                        backgroundColor: pres.status == 'dispensed'
                                            ? Colors.green.shade100
                                            : Colors.orange.shade100,
                                      ),
                                    ],
                                  ),
                                ),
                              )).toList(),
                            ),
                      // Active Treatments tab
                      activeTreatments.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('No active treatments',
                                  style: TextStyle(color: Colors.grey)),
                            )
                          : ListView(
                              children: activeTreatments.map((treatment) => Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(treatment.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text('${treatment.drugName} - ${treatment.dosage}'),
                                      Text('${treatment.frequencyPerDay}x/day for ${treatment.durationDays} days'),
                                      Text('Days remaining: ${treatment.daysRemaining}'),
                                      Text(
                                        'Doses given: ${treatment.dosesGiven} / ${treatment.totalDosesExpected}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      if (treatment.administeredLog.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        const Text('Administration log:',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        ...treatment.administeredLog.reversed.take(5).map((entry) {
                                          final date = entry['date'] as DateTime;
                                          final staffName = (entry['userName'] as String?) ?? 'Unknown staff';
                                          final dateStr = '${date.day}/${date.month}/${date.year} '
                                              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              '• $dateStr — given by $staffName',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                          );
                                        }),
                                      ],
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          icon: const Icon(Icons.check_circle_outline, size: 18),
                                          label: const Text('Log Dose'),
                                          onPressed: () async {
                                            final auth = context.read<AuthProvider>();
                                            final businessProvider = context.read<BusinessProvider>();
                                            final staffName = auth.currentUser?.fullName ??
                                                auth.currentUser?.email ??
                                                'Staff';

                                            // Guard against accidentally logging the same
                                            // dose twice (e.g. two staff members, or one
                                            // device that was offline and double-submits
                                            // once back online). A dose is only expected
                                            // roughly every (24 / frequencyPerDay) hours,
                                            // so warn if the most recent log is still
                                            // within that window.
                                            if (treatment.administeredLog.isNotEmpty) {
                                              final lastEntry =
                                                  treatment.administeredLog.last;
                                              final lastDate =
                                                  lastEntry['date'] as DateTime;
                                              final lastStaff =
                                                  (lastEntry['userName'] as String?) ??
                                                      'Unknown staff';
                                              final minutesSinceLast = DateTime.now()
                                                  .difference(lastDate)
                                                  .inMinutes;
                                              final expectedGapMinutes =
                                                  treatment.frequencyPerDay > 0
                                                      ? ((24 / treatment.frequencyPerDay) *
                                                              60)
                                                          .round()
                                                      : 24 * 60;
                                              // Flag as a possible duplicate if logged
                                              // well inside the expected gap between
                                              // doses (using half the gap as the cutoff).
                                              if (minutesSinceLast <
                                                  (expectedGapMinutes / 2)) {
                                                final timeAgo = minutesSinceLast < 60
                                                    ? '$minutesSinceLast min ago'
                                                    : '${(minutesSinceLast / 60).floor()}h ${minutesSinceLast % 60}m ago';
                                                final proceed = await showDialog<bool>(
                                                      context: context,
                                                      builder: (dialogCtx) => AlertDialog(
                                                        title: const Text(
                                                            'Dose already logged recently'),
                                                        content: Text(
                                                          'A dose for "${treatment.name}" was logged $timeAgo by $lastStaff. '
                                                          'Log another dose anyway?',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.of(dialogCtx)
                                                                    .pop(false),
                                                            child: const Text('Cancel'),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.of(dialogCtx)
                                                                    .pop(true),
                                                            child: const Text(
                                                                'Log Anyway'),
                                                          ),
                                                        ],
                                                      ),
                                                    ) ??
                                                    false;
                                                if (!proceed) return;
                                              }
                                            }

                                            try {
                                              await context.read<PharmacyProvider>().administerTreatmentDose(
                                                    treatment.id,
                                                    DateTime.now(),
                                                    persist: true,
                                                    businessId: businessProvider.currentBusiness?.id,
                                                    userId: auth.currentUser?.id,
                                                    userName: staffName,
                                                  );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Dose logged by $staffName')),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Failed to log dose: $e')),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )).toList(),
                            ),
                      // Treatment History tab
                      treatmentHistory.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('No treatment history',
                                  style: TextStyle(color: Colors.grey)),
                            )
                          : ListView(
                              children: treatmentHistory.map((treatment) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(treatment.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('${treatment.drugName} - ${treatment.dosage}'),
                                    Text('Completed: ${treatment.endDate.toString().split(' ')[0]}'),
                                  ],
                                ),
                              )).toList(),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Patient'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.note_add),
                        label: const Text('New Rx'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.medical_services),
                        label: const Text('New Treatment'),
                        onPressed: () => _showAddTreatmentDialog(context, patient['id'] as String, provider),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showAddPatientDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    final dateOfBirthController = TextEditingController();
    final allergiesController = TextEditingController();
    final bloodTypeController = TextEditingController();
    final additionalNotesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Patient'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Patient Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dateOfBirthController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth (optional)',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    dateOfBirthController.text = date.toString().split(' ')[0];
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: allergiesController,
                decoration: const InputDecoration(
                  labelText: 'Allergies/Drug Reactions (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bloodTypeController,
                decoration: const InputDecoration(
                  labelText: 'Blood Type (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: additionalNotesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes/Diagnoses (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter the patient\'s name'))
                );
                return;
              }
              final provider = context.read<PharmacyProvider>();
              // Duplicate check by phone (only if provided) or exact name
              final dup = provider.patients.where((p) =>
                  (phone.isNotEmpty && p.phone == phone) ||
                      p.name.toLowerCase() == name.toLowerCase()).toList();
              if (dup.isNotEmpty) {
                final keep = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Possible duplicate'),
                    content: Text('A patient with similar details already exists. Add anyway?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
                    ],
                  ),
                ) ?? false;
                if (!keep) return;
              }
              final id = 'P${DateTime.now().millisecondsSinceEpoch}';
              DateTime? dob;
              if (dateOfBirthController.text.isNotEmpty) {
                try {
                  dob = DateTime.parse(dateOfBirthController.text);
                } catch (_) {}
              }
              final newPatient = Patient(
                id: id,
                name: name,
                phone: phone.isNotEmpty ? phone : null,
                email: emailController.text.isNotEmpty ? emailController.text : null,
                address: addressController.text.isNotEmpty ? addressController.text : null,
                dateOfBirth: dob,
                allergies: allergiesController.text.isNotEmpty ? allergiesController.text : null,
                bloodType: bloodTypeController.text.isNotEmpty ? bloodTypeController.text : null,
                additionalNotes: additionalNotesController.text.isNotEmpty ? additionalNotesController.text : null,
              );
              final businessId = context.read<BusinessProvider>().currentBusiness?.id;
              await provider.addPatient(newPatient, persist: true, businessId: businessId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient added')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddTreatmentDialog(BuildContext context, String patientId, PharmacyProvider provider) {
    final nameController = TextEditingController();
    final drugNameController = TextEditingController();
    final dosageController = TextEditingController();
    final frequencyController = TextEditingController(text: '1');
    final durationController = TextEditingController(text: '7');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Treatment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Treatment Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: drugNameController,
                decoration: const InputDecoration(
                  labelText: 'Drug Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dosageController,
                decoration: const InputDecoration(
                  labelText: 'Dosage (e.g., 2 tablets) *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: frequencyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Times per day *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (days) *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final drugName = drugNameController.text.trim();
              final dosage = dosageController.text.trim();
              final frequency = int.tryParse(frequencyController.text) ?? 1;
              final duration = int.tryParse(durationController.text) ?? 7;

              if (name.isEmpty || drugName.isEmpty || dosage.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all required fields'))
                );
                return;
              }

              final treatment = Treatment(
                id: 'T${DateTime.now().millisecondsSinceEpoch}',
                patientId: patientId,
                name: name,
                drugName: drugName,
                dosage: dosage,
                frequencyPerDay: frequency,
                durationDays: duration,
                startDate: DateTime.now(),
              );

              await provider.addTreatment(treatment, persist: true);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Treatment added')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

