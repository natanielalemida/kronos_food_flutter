import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/darcapio/order_details.dart';
import '../components/darcapio/order_style.dart';
import '../components/food_order_list.dart';
import '../models/food_order_entry.dart';
import '../repositories/darcapio_repository.dart';

class DarcapioOrderHistoryPage extends StatefulWidget {
  final DarcapioRepository repository;
  final Future<void> Function(DarcapioOrder) onPrint;
  const DarcapioOrderHistoryPage(
      {super.key, required this.repository, required this.onPrint});
  @override
  State<DarcapioOrderHistoryPage> createState() =>
      _DarcapioOrderHistoryPageState();
}

class _DarcapioOrderHistoryPageState extends State<DarcapioOrderHistoryPage> {
  final search = TextEditingController();
  List<DarcapioCashMovement> movements = [];
  DarcapioCashMovement? movement;
  DarcapioOrderPage? result;
  DarcapioOrder? selected;
  bool loading = true, exporting = false, printing = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadMovements();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> loadMovements() async {
    final value = search.text.trim();
    final code = value.isEmpty ? null : int.tryParse(value);
    if (value.isNotEmpty && (code == null || code <= 0)) {
      setState(() => error = 'Informe um número de movimento válido.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final found = await widget.repository.movements(code: code);
      if (mounted) setState(() => movements = found);
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'Não foi possível consultar os movimentos. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadOrders(DarcapioCashMovement value, {int page = 0}) async {
    setState(() {
      loading = true;
      error = null;
      selected = null;
      result = null;
      movement = value;
    });
    try {
      final found = await widget.repository.history(value.code, page: page);
      if (mounted) setState(() => result = found);
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'Não foi possível consultar os pedidos deste movimento. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> exportOrders() async {
    final code = movement!.code;
    setState(() => exporting = true);
    try {
      final orders = <DarcapioOrder>[];
      var page = 0;
      while (true) {
        final data = await widget.repository.history(code, page: page++);
        orders.addAll(data.orders);
        if (!data.hasNext) break;
      }
      if (!mounted) return;
      final file = await getSaveLocation(
          suggestedName: 'pedidos-darcapio-movimento-$code.csv',
          acceptedTypeGroups: const [
            XTypeGroup(label: 'CSV', extensions: ['csv'])
          ]);
      if (file == null) return;
      final csv = darcapioMovementCsv(code, orders);
      await XFile.fromData(Uint8List.fromList(utf8.encode('\uFEFF$csv')),
              mimeType: 'text/csv')
          .saveTo(file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Relatório exportado.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Não foi possível exportar o relatório. Tente novamente.')));
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  String period(DarcapioCashMovement value) {
    final format = DateFormat('dd/MM/yyyy HH:mm');
    return '${format.format(value.opened)} → ${value.closed == null ? (value.isOpen ? 'Aberto' : 'Fechado') : format.format(value.closed!)}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: OrderStyle.canvas,
      appBar: AppBar(
          title: const Text('Histórico Darcapio'),
          backgroundColor: OrderStyle.teal,
          foregroundColor: Colors.white,
          actions: [
            if (movement != null)
              IconButton(
                  tooltip: 'Exportar pedidos do movimento (CSV)',
                  onPressed: loading || exporting || result == null
                      ? null
                      : exportOrders,
                  icon: exporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_outlined))
          ]),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: movement == null
                ? Row(children: [
                    Expanded(
                        child: TextField(
                            controller: search,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Número do movimento',
                                hintText:
                                    'Vazio para listar os 100 mais recentes'),
                            onSubmitted: (_) {
                              if (!loading) loadMovements();
                            })),
                    const SizedBox(width: 12),
                    FilledButton(
                        onPressed: loading ? null : loadMovements,
                        child: const Text('Buscar')),
                  ])
                : Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                        TextButton.icon(
                            onPressed: loading || exporting
                                ? null
                                : () => setState(() {
                                      movement = null;
                                      result = null;
                                      selected = null;
                                      error = null;
                                    }),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Trocar movimento')),
                        Text(
                            'Movimento #${movement!.code} · ${period(movement!)}'),
                        const Text('Somente consulta',
                            style: TextStyle(color: OrderStyle.muted)),
                      ])),
        if (error != null)
          Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(child: Text(error!)),
                TextButton(
                    onPressed: loading
                        ? null
                        : () {
                            if (movement == null) {
                              loadMovements();
                            } else {
                              loadOrders(movement!);
                            }
                          },
                    child: const Text('Tentar novamente')),
              ])),
        Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : movement == null
                    ? movements.isEmpty
                        ? const Center(
                            child: Text(
                                'Nenhum movimento com pedidos Darcapio encontrado.'))
                        : ListView.builder(
                            itemCount: movements.length,
                            itemBuilder: (context, index) {
                              final value = movements[index];
                              return ListTile(
                                  leading: const Icon(Icons.point_of_sale),
                                  title: Text('Movimento #${value.code}'),
                                  subtitle: Text(period(value)),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => loadOrders(value));
                            })
                    : selected != null
                        ? DarcapioOrderDetails(
                            order: selected!,
                            busy: false,
                            blocked: true,
                            onAction: (_) {},
                            onBack: () => setState(() => selected = null),
                            printing: printing,
                            onPrint: () async {
                              if (printing) return;
                              setState(() => printing = true);
                              try {
                                await widget.onPrint(selected!);
                              } finally {
                                if (mounted) setState(() => printing = false);
                              }
                            })
                        : result == null
                            ? const SizedBox.shrink()
                            : FoodOrderList(
                                key: ValueKey(
                                    '${movement!.code}-${result!.page}'),
                                orders: result!.orders
                                    .map(FoodOrderEntry.darcapio)
                                    .toList(),
                                selectedId: null,
                                connected: true,
                                initialShowAll: true,
                                automaticUpdates: false,
                                searchHint:
                                    'Buscar nesta página por nome ou nº',
                                actionsEnabled: false,
                                onSelected: (key) => setState(() => selected =
                                    result!.orders.firstWhere((order) =>
                                        'darcapio-order-${order.id}' == key)))),
        if (result != null && selected == null && !loading)
          SafeArea(
              top: false,
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    Expanded(
                        child: Text(
                            '${result!.total} pedidos · Página ${result!.page + 1} de ${((result!.total + result!.size - 1) ~/ result!.size).clamp(1, 100000)}')),
                    IconButton(
                        tooltip: 'Página anterior',
                        onPressed: result!.page == 0
                            ? null
                            : () =>
                                loadOrders(movement!, page: result!.page - 1),
                        icon: const Icon(Icons.chevron_left)),
                    IconButton(
                        tooltip: 'Próxima página',
                        onPressed: result!.hasNext
                            ? () =>
                                loadOrders(movement!, page: result!.page + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right)),
                  ]))),
      ]));
}

String darcapioMovementCsv(int movement, Iterable<DarcapioOrder> orders) {
  String cell(Object value) {
    var text = value.toString();
    if (RegExp(r'^[\s]*[=+@-]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  return [
    ['Movimento', 'Pedido', 'Data', 'Cliente', 'Modalidade', 'Status', 'Total'],
    ...orders.map((order) => [
          movement,
          order.delivery,
          DateFormat('dd/MM/yyyy HH:mm').format(order.created),
          order.customer,
          order.pickup ? 'Retirada' : 'Entrega',
          order.label,
          order.total.toStringAsFixed(2).replaceAll('.', ',')
        ]),
  ].map((row) => row.map(cell).join(';')).join('\r\n');
}
