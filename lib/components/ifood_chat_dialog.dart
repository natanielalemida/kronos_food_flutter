import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kronos_food/consts.dart';
import 'package:webview_windows/webview_windows.dart';

class IfoodChatDialog extends StatefulWidget {
  final String merchantId;
  final String widgetId;

  const IfoodChatDialog({
    super.key,
    required this.merchantId,
    required this.widgetId,
  });

  @override
  State<IfoodChatDialog> createState() => _IfoodChatDialogState();
}

class _IfoodChatDialogState extends State<IfoodChatDialog> {
  final WebviewController _controller = WebviewController();
  final List<StreamSubscription> _subscriptions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      final version = await WebviewController.getWebViewVersion();
      if (version == null) {
        throw PlatformException(
          code: 'webview2_not_found',
          message: 'Microsoft Edge WebView2 Runtime nao esta instalado.',
        );
      }

      await _controller.initialize();
      _subscriptions.add(
        _controller.loadingState.listen((state) {
          if (!mounted) return;
          setState(() {
            _loading = state == LoadingState.loading;
          });
        }),
      );
      _subscriptions.add(
        _controller.onLoadError.listen((status) {
          if (!mounted) return;
          setState(() {
            _error = 'Falha ao carregar o widget iFood: $status';
          });
        }),
      );

      await _controller.setBackgroundColor(Colors.white);
      await _controller
          .setPopupWindowPolicy(WebviewPopupWindowPolicy.sameWindow);
      await _controller.loadStringContent(_buildWidgetHtml());

      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message ?? e.code;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _buildWidgetHtml() {
    final merchantId = jsonEncode(widget.merchantId);
    final widgetId = jsonEncode(widget.widgetId);

    return '''
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Chat iFood</title>
  <style>
    html, body {
      width: 100%;
      height: 100%;
      margin: 0;
      overflow: hidden;
      background: #f6fbfa;
      font-family: Arial, Helvetica, sans-serif;
    }
    #ifood-widget-root {
      width: 100%;
      height: 100%;
      min-height: 640px;
    }
    #ifood-widget-root iframe {
      width: 100% !important;
      height: 100% !important;
      border: 0 !important;
    }
    #status {
      position: fixed;
      inset: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #00665f;
      font-size: 14px;
      pointer-events: none;
    }
    #status.hidden {
      display: none;
    }
  </style>
  <script src="https://widgets.ifood.com.br/widget.js"></script>
</head>
<body>
  <div id="ifood-widget-root"></div>
  <div id="status">Carregando chat iFood...</div>
  <script>
    const statusElement = document.getElementById('status');
    const setStatus = (text, hidden) => {
      statusElement.textContent = text || '';
      statusElement.className = hidden ? 'hidden' : '';
    };

    window.addEventListener('load', async () => {
      try {
        if (!window.iFoodWidget) {
          throw new Error('Biblioteca iFoodWidget nao carregou.');
        }

        window.iFoodWidget.init({
          merchantIds: [$merchantId],
          widgetId: $widgetId,
          autoShow: true,
          containerSelector: '#ifood-widget-root',
        });

        await window.iFoodWidget.ready;
        window.iFoodWidget.show();
        setStatus('', true);
      } catch (error) {
        setStatus('Nao foi possivel iniciar o chat iFood. ' + (error && error.message ? error.message : error), false);
      }
    });
  </script>
</body>
</html>
''';
  }

  Future<WebviewPermissionDecision> _onPermissionRequested(
    String url,
    WebviewPermissionKind kind,
    bool isUserInitiated,
  ) async {
    if (kind == WebviewPermissionKind.notifications ||
        kind == WebviewPermissionKind.clipboardRead) {
      return WebviewPermissionDecision.allow;
    }
    return WebviewPermissionDecision.none;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = size.width * 0.86;
    final dialogHeight = size.height * 0.86;

    return Dialog(
      insetPadding: const EdgeInsets.all(32),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogWidth.clamp(720.0, 1280.0).toDouble(),
        height: dialogHeight.clamp(540.0, 900.0).toDouble(),
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Consts.primaryColor,
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, color: Colors.white),
                  const SizedBox(width: 10),
                  const Text(
                    'Chat iFood',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Recarregar chat',
                    onPressed: _controller.value.isInitialized
                        ? () => _controller.reload()
                        : null,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'Fechar chat',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  if (_controller.value.isInitialized)
                    Webview(
                      _controller,
                      permissionRequested: _onPermissionRequested,
                    )
                  else
                    const SizedBox.expand(),
                  if (_loading)
                    const Align(
                      alignment: Alignment.topCenter,
                      child: LinearProgressIndicator(),
                    ),
                  if (_error != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Material(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    unawaited(_controller.dispose());
    super.dispose();
  }
}
