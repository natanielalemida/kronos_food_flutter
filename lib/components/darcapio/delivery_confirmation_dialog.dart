import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../repositories/darcapio_repository.dart';
import 'order_style.dart';

class DeliveryConfirmationDialog extends StatefulWidget {
  final bool pickup;
  final int orderNumber;
  final Future<void> Function(String code) confirm;
  final String Function(Object error) describeError;

  const DeliveryConfirmationDialog({
    super.key,
    required this.pickup,
    required this.orderNumber,
    required this.confirm,
    required this.describeError,
  });

  @override
  State<DeliveryConfirmationDialog> createState() =>
      _DeliveryConfirmationDialogState();
}

class _DeliveryConfirmationDialogState
    extends State<DeliveryConfirmationDialog> {
  static const red = Color(0xFFB42318);
  final code = TextEditingController();
  final focus = FocusNode();
  final submitKey = GlobalKey();
  bool submitting = false, incorrectCode = false, needsRefresh = false;
  String? failure;

  void revealSubmit() {
    if (code.text.length != 6) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = submitKey.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(target,
          alignment: 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut);
    });
  }

  Future<void> submit() async {
    if (submitting || needsRefresh || code.text.length != 6) return;
    setState(() {
      submitting = true;
      failure = null;
      incorrectCode = false;
    });
    try {
      await widget.confirm(code.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      final invalid = error is DioException &&
          error.response?.statusCode == 400 &&
          (darcapioField(error.response?.data, 'codigo') ==
                  'codigo_incorreto' ||
              // Compatibilidade com versões do Service anteriores ao campo codigo.
              darcapioField(error.response?.data, 'mensagem')
                      ?.toString()
                      .startsWith('Código incorreto.') ==
                  true);
      setState(() {
        failure = widget.describeError(error);
        incorrectCode = invalid;
        // Conflitos, bloqueios e respostas incertas exigem consultar o pedido
        // antes de permitir outra tentativa. A validação continua no Service.
        needsRefresh = !invalid;
      });
      if (invalid) {
        focus.requestFocus();
        code.selection =
            TextSelection(baseOffset: 0, extentOffset: code.text.length);
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  void dispose() {
    code.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.pickup ? 'retirada' : 'entrega';
    return PopScope(
      canPop: !submitting,
      child: AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        title: Text('Confirmar $kind',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Pedido #${widget.orderNumber.toString().padLeft(4, '0')}',
                  style: const TextStyle(
                      color: OrderStyle.teal, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(
                  'Peça ao cliente o código de $kind exibido no pedido. '
                  'Confirme somente quando os itens forem entregues.',
                  style: const TextStyle(fontSize: 15, color: OrderStyle.ink)),
              const SizedBox(height: 20),
              if (failure != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F0),
                      border: Border.all(color: const Color(0xFFF0A7A0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, color: red, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  incorrectCode
                                      ? 'Código incorreto'
                                      : 'Não foi possível confirmar',
                                  style: const TextStyle(
                                      color: red,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text(
                                  incorrectCode
                                      ? 'Confira os 6 dígitos com o cliente e tente novamente. '
                                          'O pedido continua na mesma etapa.'
                                      : failure!,
                                  style: const TextStyle(
                                      color: red, fontSize: 15)),
                            ],
                          )),
                        ]),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              TextField(
                controller: code,
                focusNode: focus,
                autofocus: true,
                readOnly: submitting || needsRefresh,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: 6,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 6),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) {
                  setState(() {});
                  revealSubmit();
                },
                onSubmitted: (_) => submit(),
                decoration: InputDecoration(
                  labelText: 'Código do cliente',
                  hintText: '000000',
                  filled: true,
                  fillColor: incorrectCode
                      ? const Color(0xFFFFF8F7)
                      : OrderStyle.canvas,
                  border: const OutlineInputBorder(),
                  errorBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: red, width: 2)),
                  focusedErrorBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: red, width: 2)),
                  errorStyle: const TextStyle(color: red, fontSize: 13),
                  errorMaxLines: 2,
                  errorText: incorrectCode
                      ? 'Código inválido. Confira com o cliente.'
                      : null,
                  suffixIcon: incorrectCode
                      ? const Icon(Icons.error, color: red)
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                overflowSpacing: 8,
                overflowAlignment: OverflowBarAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        submitting ? null : () => Navigator.pop(context, false),
                    child: Text(
                        needsRefresh ? 'Voltar e atualizar pedido' : 'Voltar'),
                  ),
                  FilledButton.icon(
                    key: submitKey,
                    onPressed:
                        submitting || needsRefresh || code.text.length != 6
                            ? null
                            : submit,
                    style: FilledButton.styleFrom(
                        backgroundColor: OrderStyle.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16)),
                    icon: submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline, size: 20),
                    label: Text(submitting
                        ? 'Conferindo código…'
                        : incorrectCode
                            ? 'Conferir novamente'
                            : 'Confirmar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
