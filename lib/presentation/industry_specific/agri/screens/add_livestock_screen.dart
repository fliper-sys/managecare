import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../providers/agri_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../models/agri/livestock_group.dart';
import 'package:uuid/uuid.dart';

class AddLivestockScreen extends StatefulWidget {
  const AddLivestockScreen({super.key});

  @override
  State<AddLivestockScreen> createState() => _AddLivestockScreenState();
}

class _AddLivestockScreenState extends State<AddLivestockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  
  // Animal types supported
  static const List<String> animalTypes = [
    'poultry',
    'cattle',
    'sheep',
    'goats',
    'pigs',
    'rabbits',
    'fish',
    'bees',
    'horses',
  ];
  
  String _type = 'poultry';
  int _count = 0;
  int _ageWeeks = 0;
  int _maturityWeek = 20;
  double _feedPerAnimalGrams = 100.0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Add Livestock'), backgroundColor: AppColors.agri),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add Livestock Group', style: AppTextStyles.heading3),
            const SizedBox(height: 12),
            TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Group Name')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
                initialValue: _type,
                items: animalTypes
                    .map((t) => DropdownMenuItem(
                        value: t, 
                        child: Row(
                          children: [
                            Text(AnimalGroup.getEmojiForType(t)),
                            const SizedBox(width: 8),
                            Text(t.toUpperCase()),
                          ],
                        )))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? 'poultry'),
                decoration: const InputDecoration(labelText: 'Animal Type')),
            const SizedBox(height: 12),
            TextFormField(
                initialValue: '0',
                decoration: const InputDecoration(labelText: 'Count'),
                keyboardType: TextInputType.number,
                onChanged: (v) => _count = int.tryParse(v) ?? 0),
            const SizedBox(height: 12),
            TextFormField(
                initialValue: '0',
                decoration: const InputDecoration(labelText: 'Age (weeks)'),
                keyboardType: TextInputType.number,
                onChanged: (v) => _ageWeeks = int.tryParse(v) ?? 0),
            const SizedBox(height: 12),
            TextFormField(
                initialValue: '20',
                decoration: const InputDecoration(labelText: 'Maturity week'),
                keyboardType: TextInputType.number,
                onChanged: (v) => _maturityWeek = int.tryParse(v) ?? 20),
            const SizedBox(height: 12),
            TextFormField(
                initialValue: '100',
                decoration: const InputDecoration(
                    labelText: 'Feed per animal (grams/day)'),
                keyboardType: TextInputType.number,
                onChanged: (v) => _feedPerAnimalGrams = double.tryParse(v) ?? 100.0),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.agri),
                      child: const Text('Create Animal Group'),
                      onPressed: () async {
                        if (!_formKey.currentState!.validate()) return;
                        
                        final id = const Uuid().v4();
                        final emoji = AnimalGroup.getEmojiForType(_type);
                        
                        final group = AnimalGroup(
                            id: id,
                            type: _type,
                            name: _nameCtrl.text.isEmpty
                                ? 'Group $id'
                                : _nameCtrl.text,
                            count: _count,
                            ageWeeks: _ageWeeks,
                            maturityWeek: _maturityWeek,
                            feedPerAnimalGrams: _feedPerAnimalGrams,
                            emoji: emoji);
                        
                        final businessId = context
                                .read<BusinessProvider>()
                                .currentBusiness
                                ?.id ??
                            '';
                        
                        // Use new updateGroupInFirestore method for proper persistence
                        await context
                            .read<AgriProvider>()
                            .updateGroupInFirestore(businessId, group, source: 'add_livestock_screen');
                        
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      })),
            ])
          ]),
        ),
      ),
    );
  }
}

