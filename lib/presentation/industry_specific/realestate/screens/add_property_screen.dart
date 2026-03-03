import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../providers/real_estate_provider.dart';
import '../widgets/property_form.dart';

class AddPropertyScreen extends StatelessWidget {
  const AddPropertyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RealEstateProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Add Property'), backgroundColor: AppColors.primary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add New Property', style: AppTextStyles.heading3),
            const SizedBox(height: 12),
            PropertyForm(
              provider: provider,
              submitText: 'Create Property',
              onSubmit: (property) async {
                await provider.addProperty(property);
                if (Navigator.of(context).canPop()) Navigator.of(context).pop();
              },
            ),
          ]),
        ),
      ),
    );
  }
}

