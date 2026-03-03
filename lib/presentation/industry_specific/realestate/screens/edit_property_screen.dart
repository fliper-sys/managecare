import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../providers/real_estate_provider.dart';
import '../../../../core/utils/context_extensions.dart';
import '../widgets/property_form.dart';

class EditPropertyScreen extends StatelessWidget {
  final Property property;

  const EditPropertyScreen({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    final provider = context.tryRead<RealEstateProvider>();
    if (provider == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Property'), backgroundColor: AppColors.primary),
        body: const Center(child: Text('Service not available. Try again.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Property'), backgroundColor: AppColors.primary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Edit Property', style: AppTextStyles.heading3),
            const SizedBox(height: 12),
            PropertyForm(
              provider: provider,
              initial: property,
              submitText: 'Save Changes',
              onSubmit: (updated) async {
                await provider.updateProperty(updated);
                if (Navigator.of(context).canPop()) Navigator.of(context).pop();
              },
            ),
          ]),
        ),
      ),
    );
  }
}
