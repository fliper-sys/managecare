import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../widgets/loading_indicator.dart';
import 'package:provider/provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/agri_provider.dart';

class FarmHintsScreen extends StatefulWidget {
  final String farmId;
  final String farmName;
  final String farmType;

  const FarmHintsScreen(
      {super.key,
      required this.farmId,
      required this.farmName,
      required this.farmType});

  @override
  State<FarmHintsScreen> createState() => _FarmHintsScreenState();
}

class _FarmHintsScreenState extends State<FarmHintsScreen> {
  final _controller = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHints();
  }

  Future<void> _loadHints() async {
    setState(() => _loading = true);
    final provider = context.read<AgriProvider>();
    final businessId =
        context.read<BusinessProvider?>()?.currentBusiness?.id ?? 'demo';
    await provider.loadHintsForFarm(businessId, widget.farmId);
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AgriProvider>();
    final hints = provider.getHintsForFarm(widget.farmId);

    return Scaffold(
      appBar: AppBar(
          title: Text('${widget.farmName} Hints'),
          backgroundColor: AppColors.agri),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration:
                        const InputDecoration(labelText: 'Add custom hint'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final text = _controller.text.trim();
                    if (text.isEmpty) return;
                    final businessId = context
                            .read<BusinessProvider?>()
                            ?.currentBusiness
                            ?.id ??
                        'demo';
                    await provider.addHintForFarm(
                        businessId, widget.farmId, text);
                    _controller.clear();
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: AppColors.agri),
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                final businessId =
                    context.read<BusinessProvider?>()?.currentBusiness?.id ??
                        'demo';
                await provider.generateDailyHint(
                    businessId: businessId,
                    farmId: widget.farmId,
                    farmType: widget.farmType);
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Tailored Hint'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.agri),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CustomLoadingIndicator())
                  : hints.isEmpty
                      ? const Center(child: Text('No hints yet'))
                      : ListView.separated(
                          itemCount: hints.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final h = hints[index];
                            final dateVal = h['date'];
                            String dateStr = '';
                            try {
                              if (dateVal is String) {
                                final dt = DateTime.tryParse(dateVal);
                                if (dt != null) {
                                  dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                                } else {
                                  dateStr = dateVal;
                                }
                              } else if (dateVal is Timestamp) {
                                final dt = dateVal.toDate();
                                dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                              } else if (dateVal is DateTime) {
                                final dt = dateVal;
                                dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                              } else {
                                dateStr = '';
                              }
                            } catch (_) {
                              dateStr = '';
                            }

                            return Card(
                              child: ListTile(
                                title: Text(h['text'] ?? ''),
                                subtitle: Text(dateStr),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

