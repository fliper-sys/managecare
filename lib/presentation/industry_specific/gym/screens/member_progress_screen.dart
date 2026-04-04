import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/gym_provider.dart';
import '../../../../data/models/gym_member_model.dart';

class MemberProgressScreen extends StatefulWidget {
  final String memberId;

  const MemberProgressScreen({super.key, required this.memberId});

  @override
  State<MemberProgressScreen> createState() => _MemberProgressScreenState();
}

class _MemberProgressScreenState extends State<MemberProgressScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GymProvider>(
      builder: (context, provider, _) {
        final member = provider.members.firstWhere(
          (m) => m.id == widget.memberId,
          orElse: () => Member(id: 'unknown', name: 'Unknown Member', email: '', phone: ''),
        );

        final measurements = provider.getMeasurementsForMember(widget.memberId);
        final goals = provider.getGoalsForMember(widget.memberId);

        return Scaffold(
          appBar: AppBar(
            title: Text('${member.name} - Progress'),
            backgroundColor: AppColors.primary,
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Measurements', icon: Icon(Icons.straighten)),
                Tab(text: 'Goals', icon: Icon(Icons.flag)),
                Tab(text: 'Progress Charts', icon: Icon(Icons.show_chart)),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _MeasurementsTab(member: member, measurements: measurements, provider: provider),
              _GoalsTab(member: member, goals: goals, provider: provider),
              _ProgressChartsTab(member: member, measurements: measurements, provider: provider),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddOptions(context, provider),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _showAddOptions(BuildContext context, GymProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.straighten),
            title: const Text('Add Measurement'),
            onTap: () {
              Navigator.pop(context);
              _showAddMeasurementDialog(context, provider);
            },
          ),
          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('Add Goal'),
            onTap: () {
              Navigator.pop(context);
              _showAddGoalDialog(context, provider);
            },
          ),
        ],
      ),
    );
  }

  void _showAddMeasurementDialog(BuildContext context, GymProvider provider) {
    final weightCtrl = TextEditingController();
    final heightCtrl = TextEditingController();
    final bodyFatCtrl = TextEditingController();
    final muscleMassCtrl = TextEditingController();
    final chestCtrl = TextEditingController();
    final waistCtrl = TextEditingController();
    final hipsCtrl = TextEditingController();
    final bicepsCtrl = TextEditingController();
    final thighsCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Measurement'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: weightCtrl,
                      decoration: const InputDecoration(labelText: 'Weight (kg)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: heightCtrl,
                      decoration: const InputDecoration(labelText: 'Height (cm)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: bodyFatCtrl,
                      decoration: const InputDecoration(labelText: 'Body Fat (%)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: muscleMassCtrl,
                      decoration: const InputDecoration(labelText: 'Muscle Mass (kg)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Circumferences (cm)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: chestCtrl,
                      decoration: const InputDecoration(labelText: 'Chest'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: waistCtrl,
                      decoration: const InputDecoration(labelText: 'Waist'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: hipsCtrl,
                      decoration: const InputDecoration(labelText: 'Hips'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: bicepsCtrl,
                      decoration: const InputDecoration(labelText: 'Biceps'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: thighsCtrl,
                decoration: const InputDecoration(labelText: 'Thighs (cm)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
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
            onPressed: () {
              final weight = double.tryParse(weightCtrl.text);
              final height = double.tryParse(heightCtrl.text);

              // Calculate BMI if weight and height are provided
              final bmi = (weight != null && height != null && height > 0)
                  ? weight / ((height / 100) * (height / 100))
                  : null;

              final measurement = FitnessMeasurement(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                memberId: widget.memberId,
                date: DateTime.now(),
                weight: weight,
                height: height,
                bodyFat: double.tryParse(bodyFatCtrl.text),
                muscleMass: double.tryParse(muscleMassCtrl.text),
                bmi: bmi,
                chest: double.tryParse(chestCtrl.text),
                waist: double.tryParse(waistCtrl.text),
                hips: double.tryParse(hipsCtrl.text),
                biceps: double.tryParse(bicepsCtrl.text),
                thighs: double.tryParse(thighsCtrl.text),
                notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
              );

              provider.addMeasurement(measurement);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Measurement added successfully')),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context, GymProvider provider) {
    final titleCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    DateTime targetDate = DateTime.now().add(const Duration(days: 30));
    final targetMetrics = <String, double>{};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Fitness Goal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Goal Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Target Date: '),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: targetDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => targetDate = picked);
                        }
                      },
                      child: Text(DateFormat('MMM d, yyyy').format(targetDate)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Target Metrics (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricInput(
                      label: 'Weight (kg)',
                      onChanged: (value) => targetMetrics['weight'] = value,
                    ),
                    _MetricInput(
                      label: 'Body Fat (%)',
                      onChanged: (value) => targetMetrics['bodyFat'] = value,
                    ),
                    _MetricInput(
                      label: 'Muscle Mass (kg)',
                      onChanged: (value) => targetMetrics['muscleMass'] = value,
                    ),
                  ],
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
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;

                final goal = FitnessGoal(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  memberId: widget.memberId,
                  title: titleCtrl.text.trim(),
                  description: descriptionCtrl.text.trim(),
                  targetDate: targetDate,
                  targetMetrics: Map<String, dynamic>.from(targetMetrics),
                );

                provider.addGoal(goal);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Goal added successfully')),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _MeasurementsTab extends StatelessWidget {
  final Member member;
  final List<FitnessMeasurement> measurements;
  final GymProvider provider;

  const _MeasurementsTab({
    required this.member,
    required this.measurements,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    if (measurements.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.straighten, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No measurements recorded yet'),
            SizedBox(height: 8),
            Text('Tap the + button to add the first measurement'),
          ],
        ),
      );
    }

    // Sort by date (most recent first)
    final sortedMeasurements = List<FitnessMeasurement>.from(measurements)
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedMeasurements.length,
      itemBuilder: (context, index) {
        final measurement = sortedMeasurements[index];
        final isLatest = index == 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMM d, yyyy').format(measurement.date),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isLatest ? Colors.green : Colors.black,
                      ),
                    ),
                    if (isLatest)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Latest',
                          style: TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (measurement.weight != null)
                      _MetricChip(label: 'Weight', value: '${measurement.weight} kg'),
                    if (measurement.height != null)
                      _MetricChip(label: 'Height', value: '${measurement.height} cm'),
                    if (measurement.bodyFat != null)
                      _MetricChip(label: 'Body Fat', value: '${measurement.bodyFat}%'),
                    if (measurement.muscleMass != null)
                      _MetricChip(label: 'Muscle', value: '${measurement.muscleMass} kg'),
                    if (measurement.bmi != null)
                      _MetricChip(label: 'BMI', value: measurement.bmi!.toStringAsFixed(1)),
                  ],
                ),
                if (measurement.chest != null || measurement.waist != null || measurement.hips != null ||
                    measurement.biceps != null || measurement.thighs != null) ...[
                  const SizedBox(height: 12),
                  const Text('Circumferences:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (measurement.chest != null)
                        _MetricChip(label: 'Chest', value: '${measurement.chest} cm'),
                      if (measurement.waist != null)
                        _MetricChip(label: 'Waist', value: '${measurement.waist} cm'),
                      if (measurement.hips != null)
                        _MetricChip(label: 'Hips', value: '${measurement.hips} cm'),
                      if (measurement.biceps != null)
                        _MetricChip(label: 'Biceps', value: '${measurement.biceps} cm'),
                      if (measurement.thighs != null)
                        _MetricChip(label: 'Thighs', value: '${measurement.thighs} cm'),
                    ],
                  ),
                ],
                if (measurement.notes != null && measurement.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Notes: ${measurement.notes}'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GoalsTab extends StatelessWidget {
  final Member member;
  final List<FitnessGoal> goals;
  final GymProvider provider;

  const _GoalsTab({
    required this.member,
    required this.goals,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No goals set yet'),
            SizedBox(height: 8),
            Text('Tap the + button to add the first goal'),
          ],
        ),
      );
    }

    // Sort by target date
    final sortedGoals = List<FitnessGoal>.from(goals)
      ..sort((a, b) => a.targetDate.compareTo(b.targetDate));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedGoals.length,
      itemBuilder: (context, index) {
        final goal = sortedGoals[index];
        final daysLeft = goal.targetDate.difference(DateTime.now()).inDays;
        final isOverdue = daysLeft < 0;
        final isCompleted = goal.isCompleted;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        goal.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green.withOpacity(0.1)
                            : isOverdue
                                ? Colors.red.withOpacity(0.1)
                                : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isCompleted
                            ? 'Completed'
                            : isOverdue
                                ? 'Overdue'
                                : '$daysLeft days left',
                        style: TextStyle(
                          color: isCompleted
                              ? Colors.green
                              : isOverdue
                                  ? Colors.red
                                  : Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(goal.description),
                const SizedBox(height: 8),
                Text(
                  'Target: ${DateFormat('MMM d, yyyy').format(goal.targetDate)}',
                  style: const TextStyle(color: Colors.grey),
                ),
                if (goal.targetMetrics.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Target Metrics:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: goal.targetMetrics.entries.map((entry) {
                      return Chip(
                        label: Text('${entry.key}: ${entry.value}'),
                        backgroundColor: Colors.blue.withOpacity(0.1),
                      );
                    }).toList(),
                  ),
                ],
                if (!isCompleted) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _markGoalCompleted(context, provider, goal),
                        child: const Text('Mark Complete'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _markGoalCompleted(BuildContext context, GymProvider provider, FitnessGoal goal) {
    final updatedGoal = goal.copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
    );
    provider.updateGoal(updatedGoal);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Goal marked as completed!')),
    );
  }
}

class _ProgressChartsTab extends StatelessWidget {
  final Member member;
  final List<FitnessMeasurement> measurements;
  final GymProvider provider;

  const _ProgressChartsTab({
    required this.member,
    required this.measurements,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    if (measurements.length < 2) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Not enough data for charts'),
            SizedBox(height: 8),
            Text('Add at least 2 measurements to see progress charts'),
          ],
        ),
      );
    }

    // Sort measurements by date
    final sortedMeasurements = List<FitnessMeasurement>.from(measurements)
      ..sort((a, b) => a.date.compareTo(b.date));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progress Overview',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Weight progress
          if (sortedMeasurements.any((m) => m.weight != null)) ...[
            _ProgressCard(
              title: 'Weight Progress',
              measurements: sortedMeasurements,
              valueGetter: (m) => m.weight,
              unit: 'kg',
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
          ],

          // Body fat progress
          if (sortedMeasurements.any((m) => m.bodyFat != null)) ...[
            _ProgressCard(
              title: 'Body Fat Progress',
              measurements: sortedMeasurements,
              valueGetter: (m) => m.bodyFat,
              unit: '%',
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
          ],

          // Muscle mass progress
          if (sortedMeasurements.any((m) => m.muscleMass != null)) ...[
            _ProgressCard(
              title: 'Muscle Mass Progress',
              measurements: sortedMeasurements,
              valueGetter: (m) => m.muscleMass,
              unit: 'kg',
              color: Colors.green,
            ),
            const SizedBox(height: 16),
          ],

          // BMI progress
          if (sortedMeasurements.any((m) => m.bmi != null)) ...[
            _ProgressCard(
              title: 'BMI Progress',
              measurements: sortedMeasurements,
              valueGetter: (m) => m.bmi,
              unit: '',
              color: Colors.purple,
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String title;
  final List<FitnessMeasurement> measurements;
  final double? Function(FitnessMeasurement) valueGetter;
  final String unit;
  final Color color;

  const _ProgressCard({
    required this.title,
    required this.measurements,
    required this.valueGetter,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dataPoints = measurements
        .where((m) => valueGetter(m) != null)
        .map((m) => _DataPoint(
              date: m.date,
              value: valueGetter(m)!,
            ))
        .toList();

    if (dataPoints.length < 2) return const SizedBox.shrink();

    final firstValue = dataPoints.first.value;
    final lastValue = dataPoints.last.value;
    final change = lastValue - firstValue;
    final changePercent = firstValue != 0 ? (change / firstValue) * 100 : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: change >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}$unit (${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      color: change >= 0 ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: CustomPaint(
                painter: _ProgressChartPainter(dataPoints, color),
                size: Size.infinite,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Start: ${firstValue.toStringAsFixed(1)}$unit',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  'Latest: ${lastValue.toStringAsFixed(1)}$unit',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DataPoint {
  final DateTime date;
  final double value;

  _DataPoint({required this.date, required this.value});
}

class _ProgressChartPainter extends CustomPainter {
  final List<_DataPoint> dataPoints;
  final Color color;

  _ProgressChartPainter(this.dataPoints, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final minValue = dataPoints.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxValue = dataPoints.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final valueRange = maxValue - minValue;

    final points = <Offset>[];
    for (int i = 0; i < dataPoints.length; i++) {
      final x = (i / (dataPoints.length - 1)) * size.width;
      final y = size.height - ((dataPoints[i].value - minValue) / valueRange) * size.height;
      points.add(Offset(x, y));
    }

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);

    // Draw data points
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(_ProgressChartPainter oldDelegate) => true;
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Colors.blue.withOpacity(0.1),
    );
  }
}

class _MetricInput extends StatelessWidget {
  final String label;
  final Function(double) onChanged;

  const _MetricInput({required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: TextField(
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        onChanged: (value) {
          final numValue = double.tryParse(value);
          if (numValue != null) {
            onChanged(numValue);
          }
        },
      ),
    );
  }
}