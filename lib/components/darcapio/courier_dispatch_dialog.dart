import 'package:flutter/material.dart';
import '../../repositories/darcapio_repository.dart';
import 'order_style.dart';

class CourierDispatchDialog extends StatefulWidget {
  final Future<List<DarcapioCourier>> Function() load;
  final int orderNumber;
  const CourierDispatchDialog(
      {super.key, required this.load, required this.orderNumber});
  @override
  State<CourierDispatchDialog> createState() => _CourierDispatchDialogState();
}

class _CourierDispatchDialogState extends State<CourierDispatchDialog> {
  late Future<List<DarcapioCourier>> couriers;
  DarcapioCourier? selected;
  String search = '';
  @override
  void initState() {
    super.initState();
    couriers = widget.load();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Entregador da loja'),
        content: SizedBox(
            width: 460,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      'Quem vai entregar o pedido #${widget.orderNumber.toString().padLeft(4, '0')}?',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text(
                      'Confirme a saída somente quando o entregador retirar o pedido.',
                      style: TextStyle(fontSize: 13, color: OrderStyle.muted)),
                  const SizedBox(height: 18),
                  TextField(
                      decoration: const InputDecoration(
                          labelText: 'Buscar entregador',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder()),
                      onChanged: (text) =>
                          setState(() => search = text.trim().toLowerCase())),
                  const SizedBox(height: 12),
                  SizedBox(
                      height:
                          MediaQuery.sizeOf(context).height < 600 ? 120 : 230,
                      child: FutureBuilder<List<DarcapioCourier>>(
                          future: couriers,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return Center(
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                    const Text(
                                        'Não foi possível carregar os entregadores. Confira a conexão com o ERP.',
                                        textAlign: TextAlign.center),
                                    TextButton(
                                        onPressed: () => setState(() {
                                              selected = null;
                                              couriers = widget.load();
                                            }),
                                        child: const Text('Tentar novamente')),
                                  ]));
                            }
                            final all = snapshot.data ?? [];
                            if (all.isEmpty) {
                              return const Center(
                                  child: Text(
                                      'Nenhum entregador disponível. Cadastre um funcionário ativo com cargo de entregador no Kronos ERP.',
                                      textAlign: TextAlign.center));
                            }
                            final visible = all
                                .where((item) => '${item.name} ${item.code}'
                                    .toLowerCase()
                                    .contains(search))
                                .toList();
                            if (visible.isEmpty) {
                              return const Center(
                                  child: Text(
                                      'Nenhum entregador encontrado nessa busca.'));
                            }
                            return ListView.separated(
                                itemCount: visible.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final courier = visible[index];
                                  final chosen = selected?.code == courier.code;
                                  return Material(
                                      color: chosen
                                          ? OrderStyle.softTeal
                                          : OrderStyle.canvas,
                                      borderRadius: BorderRadius.circular(10),
                                      child: ListTile(
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          leading: const Icon(
                                              Icons.delivery_dining,
                                              color: OrderStyle.teal),
                                          title: Text(courier.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          subtitle: Text(
                                              'Entregador #${courier.code}'),
                                          trailing: Icon(
                                              chosen
                                                  ? Icons.radio_button_checked
                                                  : Icons.radio_button_off,
                                              color: chosen
                                                  ? OrderStyle.teal
                                                  : OrderStyle.muted),
                                          selected: chosen,
                                          onTap: () => setState(
                                              () => selected = courier)));
                                });
                          })),
                  if (selected != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text('Selecionado: ${selected!.name}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: OrderStyle.teal))),
                ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Voltar')),
          FilledButton.icon(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(context, selected),
              icon: const Icon(Icons.delivery_dining),
              label: const Text('Confirmar saída para entrega'))
        ],
      );
}
