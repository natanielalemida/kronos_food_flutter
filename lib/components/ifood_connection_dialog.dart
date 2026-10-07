import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/repositories/auth_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class IfoodConnectionDialog extends StatefulWidget {
  final AuthRepository repository;

  const IfoodConnectionDialog({super.key, required this.repository});

  @override
  State<IfoodConnectionDialog> createState() => _IfoodConnectionDialogState();
}

class _IfoodConnectionDialogState extends State<IfoodConnectionDialog> {
  final _authorizationCode = TextEditingController();
  Map<String, dynamic>? _credentials;
  DateTime? _expiresAt;
  Timer? _timer;
  bool _busy = false;
  String? _error;

  int get _remainingSeconds {
    final remaining = _expiresAt?.difference(DateTime.now()).inSeconds ?? 0;
    return remaining > 0 ? remaining : 0;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_prepareConnection());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _authorizationCode.dispose();
    super.dispose();
  }

  String _failureMessage(Object error) {
    if (error is StateError) return error.message.toString();
    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        return 'O iFood não aceitou a autorização ou a credencial do aplicativo. '
            'Confira o código recebido no Portal e a chave configurada.';
      }
      if (error.response?.statusCode == 400) {
        return 'O iFood não aceitou o código. Confira o código recebido no '
            'Portal do Parceiro; se ele expirou, gere um novo código.';
      }
    }
    return 'Não foi possível conectar ao iFood. Confira a conexão e tente novamente.';
  }

  Future<void> _prepareConnection() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _credentials = null;
    });
    _timer?.cancel();
    _authorizationCode.clear();
    try {
      if (!widget.repository.distributed) {
        final tokens =
            await widget.repository.authenticateWithClientCredentials();
        await widget.repository.saveConfig(tokens);
        if (mounted) Navigator.pop(context, true);
        return;
      }
      final credentials = await widget.repository.getUserCode();
      final duration = int.tryParse('${credentials['expiresIn']}') ?? 600;
      if (credentials['userCode'] is! String ||
          credentials['authorizationCodeVerifier'] is! String ||
          (credentials['userCode'] as String).isEmpty ||
          (credentials['authorizationCodeVerifier'] as String).isEmpty ||
          duration <= 0) {
        throw StateError(
            'O iFood não retornou um código válido. Tente novamente.');
      }
      if (!mounted) return;
      setState(() {
        _credentials = credentials;
        _expiresAt = DateTime.now().add(Duration(seconds: duration));
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _remainingSeconds == 0) timer.cancel();
        if (mounted) setState(() {});
      });
    } catch (error) {
      if (mounted) setState(() => _error = _failureMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _authorize() async {
    if (_busy || _credentials == null) return;
    if (_remainingSeconds == 0) {
      setState(() =>
          _error = 'O código expirou. Gere um novo código para continuar.');
      return;
    }
    final code = _authorizationCode.text.trim();
    if (code.isEmpty) {
      setState(() => _error =
          'Informe o código de autorização recebido no Portal do Parceiro.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tokens = await widget.repository.authenticate(
        false,
        code,
        _credentials!['authorizationCodeVerifier'] as String,
        '',
      );
      if (tokens['refreshToken']?.toString().isNotEmpty != true) {
        throw StateError(
            'O iFood não retornou uma autorização para reconectar automaticamente. Gere um novo código.');
      }
      await widget.repository.saveConfig(tokens);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = _failureMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPortal() async {
    final value = _credentials?['verificationUrlComplete'] ??
        _credentials?['verificationUrl'];
    final uri = Uri.tryParse(value?.toString() ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'portal.ifood.com.br') {
      setState(() => _error =
          'O endereço do Portal não está disponível. Gere um novo código.');
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        setState(() => _error =
            'Abra portal.ifood.com.br/apps/code no navegador e informe o código da loja.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Não foi possível abrir o navegador. Acesse portal.ifood.com.br/apps/code.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: AlertDialog(
          title: const Text('Conectar iFood'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Autorize a loja no Portal do Parceiro iFood. '
                      'Depois, o Food renova a conexão automaticamente enquanto a autorização estiver válida.'),
                  if (_busy) ...[
                    const SizedBox(height: 20),
                    const LinearProgressIndicator(),
                  ],
                  if (_credentials != null) ...[
                    const SizedBox(height: 20),
                    const Text('1. Informe este código no Portal:'),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: SelectableText(
                        _credentials!['userCode'] as String,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w600),
                      )),
                      IconButton(
                        tooltip: 'Copiar código iFood',
                        onPressed: _remainingSeconds == 0
                            ? null
                            : () => Clipboard.setData(ClipboardData(
                                text: _credentials!['userCode'] as String)),
                        icon: const Icon(Icons.copy_outlined),
                      ),
                    ]),
                    Text(_remainingSeconds == 0
                        ? 'Código expirado'
                        : 'Válido por ${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed:
                          _busy || _remainingSeconds == 0 ? null : _openPortal,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Abrir Portal do Parceiro'),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                        '2. Selecione a loja no Portal e autorize o aplicativo. Cole abaixo o código de autorização recebido:'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _authorizationCode,
                      enabled: !_busy && _remainingSeconds > 0,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      onSubmitted: (_) => _authorize(),
                      decoration: const InputDecoration(
                        labelText: 'Código de autorização',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy ? null : _prepareConnection,
                    child: Text(widget.repository.distributed
                        ? 'Gerar novo código'
                        : 'Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            if (widget.repository.distributed)
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Consts.primaryColor),
                onPressed:
                    _busy || _credentials == null || _remainingSeconds == 0
                        ? null
                        : _authorize,
                child: const Text('Conectar'),
              ),
          ],
        ),
      );
}
