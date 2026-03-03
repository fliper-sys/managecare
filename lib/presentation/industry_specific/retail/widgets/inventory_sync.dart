import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/retail_provider.dart';
import '../../../../core/localization/app_localization.dart';

class InventorySyncWidget extends StatelessWidget {
  const InventorySyncWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RetailProvider>(context, listen: false);
    return Tooltip(
      message: AppLocalizations.tr(context, 'sync_inventory'),
      child: Semantics(
        button: true,
        label: AppLocalizations.tr(context, 'sync_inventory'),
        child: ElevatedButton.icon(
          onPressed: () async {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    Text(AppLocalizations.tr(context, 'syncing_inventory'))));
            await provider.syncInventory();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(AppLocalizations.tr(context, 'inventory_synced')),
                backgroundColor: AppColors.success));
          },
          icon: const Icon(Icons.sync),
          label: Text(AppLocalizations.tr(context, 'sync_inventory')),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
        ),
      ),
    );
  }
}

