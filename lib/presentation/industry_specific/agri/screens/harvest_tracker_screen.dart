import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/agri_provider.dart';
import '../../../../services/business_logic/agriculture_logic.dart';

class HarvestTrackerScreen extends StatefulWidget {
  const HarvestTrackerScreen({super.key});

  @override
  State<HarvestTrackerScreen> createState() => _HarvestTrackerScreenState();
}

class _HarvestTrackerScreenState extends State<HarvestTrackerScreen> {
  bool _loading = true;
  String? _error;
  final Map<String, HarvestPrediction?> _predictions = {};

  @override
  void initState() {
    super.initState();
    _loadPredictions();
  }

  Future<void> _loadPredictions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final agri = context.read<AgriProvider>();
      final logic = AgricultureBusinessLogic();
      final businessId = context.read<AgriProvider>().dailyHintDate == null ? '' : '';
      // We'll use crop ids from provider
      final crops = agri.crops;
      for (final c in crops) {
        final cropId = c['id'] ?? '';
        if (cropId.isEmpty) continue;
        try {
          final pred = await logic.predictHarvestTime(businessId, cropId);
          _predictions[cropId] = pred;
        } catch (_) {
          _predictions[cropId] = null;
        }
      }
    } catch (e) {
      _error = 'Failed to load predictions';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agri = context.watch<AgriProvider>();
    final crops = agri.crops;
    return Scaffold(
      appBar: AppBar(title: const Text('Harvest Tracker'), backgroundColor: AppColors.agri),
      body: RefreshIndicator(
        onRefresh: _loadPredictions,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : crops.isEmpty
                    ? ListView(children: const [SizedBox(height: 100), Center(child: Text('No crops available'))])
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: crops.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, i) {
                          final c = crops[i];
                          final id = c['id'] ?? '';
                          final pred = _predictions[id];
                          return ListTile(
                            title: Text(c['name'] ?? 'Crop'),
                            subtitle: pred == null
                                ? const Text('No prediction available')
                                : Text('Harvest in ${pred.daysUntilHarvest} days • ${pred.recommendedAction}'),
                            trailing: pred == null
                                ? null
                                : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Text('Ready: ${pred.readiness}%'),
                                    Text('${pred.harvestDate.toLocal().toString().split(' ')[0]}')
                                  ]),
                            onTap: () {},
                          );
                        },
                      ),
      ),
    );
  }
}

