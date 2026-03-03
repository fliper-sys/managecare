import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';

typedef AuthPredicate = bool Function(AuthProvider auth);

/// Shows [child] only when [allow] returns true for current `AuthProvider`.
/// If [onTapRoute] is provided, the widget will navigate to that route when
/// tapped, merging `businessId` and `businessType` into the route arguments.
class PermissionedAction extends StatelessWidget {
  final AuthPredicate allow;
  final Widget child;
  final String? onTapRoute;
  final Map<String, dynamic>? onTapArgs;

  const PermissionedAction({
    super.key,
    required this.allow,
    required this.child,
    this.onTapRoute,
    this.onTapArgs,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (!allow(auth)) return const SizedBox.shrink();

    if (onTapRoute == null) return child;

    return GestureDetector(
      onTap: () {
        final businessId = Provider.of<BusinessProvider>(context, listen: false)
                .currentBusiness
                ?.id ??
            auth.currentUser?.businessId ??
            '';
        final businessType =
            Provider.of<BusinessProvider>(context, listen: false)
                    .currentBusiness
                    ?.businessType ??
                '';

        final merged = <String, dynamic>{};
        if (onTapArgs != null) merged.addAll(onTapArgs!);
        merged['businessId'] = businessId;
        merged['businessType'] = businessType;

        Navigator.pushNamed(context, onTapRoute!, arguments: merged);
      },
      child: child,
    );
  }
}

