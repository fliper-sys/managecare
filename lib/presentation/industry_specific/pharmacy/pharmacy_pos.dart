import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/localization/app_localization.dart';

class PharmacyPosScreen extends StatelessWidget {
  const PharmacyPosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.tr(context, 'open_pos')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: const Center(
        child:
            Text('Pharmacy POS will be built here', style: AppTextStyles.body2),
      ),
    );
  }
}

