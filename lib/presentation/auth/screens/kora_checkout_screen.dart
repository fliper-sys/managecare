import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
    this.reference,
  });

  final String checkoutUrl;
  final String redirectUrl;
  final String? reference;

  @override
  State<KoraCheckoutScreen> createState() => _KoraCheckoutScreenState();
}

class _KoraCheckoutScreenState extends State<KoraCheckoutScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _externalCheckoutOpened = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _openExternalCheckout();
      return;
    }

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

  Future<void> _openExternalCheckout() async {
    final launched = await launchUrl(
      Uri.parse(widget.checkoutUrl),
      webOnlyWindowName: '_blank',
      mode: LaunchMode.externalApplication,
    );

    if (!mounted) return;
    setState(() {
      _externalCheckoutOpened = launched;
      _isLoading = false;
    });
  }

  void _completeExternalCheckout() {
    Navigator.of(context).pop(
      KoraCheckoutResult(
        completed: true,
        reference: widget.reference,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Secure Kora Checkout')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    _externalCheckoutOpened
                        ? Icons.open_in_new_rounded
                        : Icons.warning_amber_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _externalCheckoutOpened
                        ? 'Kora checkout opened in a new tab.'
                        : 'Open Kora checkout to continue.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Complete the payment in the Kora tab, then return here and tap the button below so we can verify it.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurface.withOpacity(0.70)),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _completeExternalCheckout,
                    icon: const Icon(Icons.verified_rounded),
                    label: const Text('I have completed payment'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _openExternalCheckout,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open checkout again'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(
                      const KoraCheckoutResult(completed: false),
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Secure Kora Checkout')),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
