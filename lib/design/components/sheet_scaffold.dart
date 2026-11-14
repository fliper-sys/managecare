import 'package:flutter/material.dart';

import '../app_tokens.dart';

/// Shows [builder]'s content in the standard v2 bottom sheet.
Future<T?> showManageSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SheetScaffold(title: title, child: builder(ctx)),
  );
}

/// The v2 bottom sheet frame: handle, title, 48 dp close button, scrolling
/// body that lifts above the keyboard.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTokens.rSheet)),
          border: Border(top: BorderSide(color: t.line)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTokens.s8),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s8, AppTokens.s4, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: Icon(Icons.close, color: t.inkMuted),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(AppTokens.s16, 0, AppTokens.s16, AppTokens.s16),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
