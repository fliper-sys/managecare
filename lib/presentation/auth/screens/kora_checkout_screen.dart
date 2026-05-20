import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class KoraCheckoutResult {
  final bool completed;
  final String? reference;

  const KoraCheckoutResult({
    required this.completed,
    this.reference,
  });
}

class KoraCheckoutScreen extends StatefulWidget {
  const KoraCheckoutScreen({
    super.key,
    required this.checkoutUrl,
    required this.redirectUrl,
  });

  final String checkoutUrl;
  final String redirectUrl;

  @override
  State<KoraCheckoutScreen> createState() => _KoraCheckoutScreenState();
}

class _KoraCheckoutScreenState extends State<KoraCheckoutScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null &&
                request.url.startsWith(widget.redirectUrl)) {
              Navigator.of(context).pop(
                KoraCheckoutResult(
                  completed: true,
                  reference: uri.queryParameters['reference'],
                ),
              );
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secure Kora Checkout')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
