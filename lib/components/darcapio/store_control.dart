import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../repositories/darcapio_repository.dart';

class DarcapioStoreControl extends StatefulWidget {
  final DarcapioRepository repository;
  const DarcapioStoreControl({super.key, required this.repository});
  @override
  State<DarcapioStoreControl> createState() => _DarcapioStoreControlState();
}

class _DarcapioStoreControlState extends State<DarcapioStoreControl> {
  Map<String, dynamic>? status;
  Timer? timer;
  bool busy = false, refreshing = false, failed = false;
  @override
  void initState() {
    super.initState();
    unawaited(refresh());
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!busy) unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true;
    try {
      final value = await widget.repository.storeStatus();
      if (mounted) {
        setState(() {
          status = value;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      refreshing = false;
    }
  }

  Future<void> change(String action) async {
    if (busy || status == null) return;
    setState(() => busy = true);
    try {
      final value = await widget.repository.changeStore(
          (darcapioField(status, 'versao') as num).toInt(), action);
      if (mounted) {
        setState(() {
          status = value;
          failed = false;
        });
      }
    } catch (error) {
      final detail = error is DioException
          ? darcapioField(error.response?.data, 'mensagem')
          : null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(detail?.toString() ??
                'Não foi possível confirmar o atendimento. Atualize e tente novamente.')));
      }
      await refresh();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (status == null || failed) {
      return TextButton.icon(
          onPressed: refreshing ? null : refresh,
          icon: const Icon(Icons.storefront, size: 16),
          label: Text(failed
              ? 'Consultar atendimento Darcapio'
              : 'Consultando atendimento…'));
    }
    final open = darcapioField(status, 'aberta') == true;
    final accepting = darcapioField(status, 'aceitarPedidos') == true;
    final receiving = darcapioField(status, 'recebendoPedidos') == true;
    final label = !open
        ? 'Loja fechada'
        : !accepting
            ? 'Pedidos pausados'
            : receiving
                ? 'Loja aberta'
                : 'Fora do horário';
    return PopupMenuButton<String>(
      enabled: !busy && !refreshing,
      tooltip: 'Atendimento Darcapio · compartilhado com o painel da loja',
      onSelected: change,
      itemBuilder: (_) => [
        if (!open)
          const PopupMenuItem(
              value: 'abrir', child: Text('Abrir loja no Darcapio')),
        if (open)
          PopupMenuItem(
              value: accepting ? 'pausar' : 'retomar',
              child:
                  Text(accepting ? 'Pausar novos pedidos' : 'Retomar pedidos')),
        if (open)
          const PopupMenuItem(
              value: 'fechar', child: Text('Fechar loja no Darcapio')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color:
                receiving ? const Color(0xFFE8F5EF) : const Color(0xFFFFF2E2),
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(busy ? Icons.sync : Icons.storefront,
              size: 16, color: const Color(0xFF087F6D)),
          const SizedBox(width: 7),
          Text('Darcapio · $label',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 5),
          const Icon(Icons.expand_more, size: 16),
        ]),
      ),
    );
  }
}
