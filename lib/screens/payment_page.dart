import 'package:flutter/cupertino.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentPage extends StatefulWidget {
  final String url;
  const PaymentPage({super.key, required this.url});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://xendit.co') ||
                request.url.contains('success') ||
                request.url.contains('paid')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text("Xendit Payment"),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () {
            showCupertinoDialog(
              context: context,
              builder: (context) => CupertinoAlertDialog(
                title: const Text("Cancel Payment?"),
                content: const Text("Are you sure you want to cancel this payment?"),
                actions: [
                  CupertinoDialogAction(
                    child: const Text("No"),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    child: const Text("Yes"),
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Close payment page
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CupertinoActivityIndicator(
                radius: 15,
              ),
            ),
        ],
      ),
    );
  }
}