import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/darcapio_delivery_map.dart';
import '../../repositories/darcapio_repository.dart';
import 'order_style.dart';
import 'delivery_route_map.dart';

class DarcapioDeliveryMapView extends StatefulWidget {
  final String orderId;
  final DarcapioRepository repository;
  const DarcapioDeliveryMapView(
      {super.key, required this.orderId, required this.repository});
  @override
  State<DarcapioDeliveryMapView> createState() =>
      _DarcapioDeliveryMapViewState();
}

class _DarcapioDeliveryMapViewState extends State<DarcapioDeliveryMapView> {
  DarcapioDeliveryMap? data;
  String? error;
  int request = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant DarcapioDeliveryMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId ||
        oldWidget.repository != widget.repository) {
      load();
    }
  }

  Future<void> load() async {
    final attempt = ++request;
    setState(() {
      data = null;
      error = null;
    });
    try {
      final result = await widget.repository.deliveryMap(widget.orderId);
      if (mounted && attempt == request) setState(() => data = result);
    } catch (failure) {
      if (!mounted || attempt != request) return;
      final message = failure is DioException
          ? darcapioField(failure.response?.data, 'mensagem')
          : null;
      setState(() => error = message is String && message.isNotEmpty
          ? message
          : 'Não foi possível carregar o mapa agora. O endereço do pedido continua disponível acima.');
    }
  }

  String distance(DarcapioDeliveryMap map) => map.distanceMeters < 1000
      ? '${map.distanceMeters} m'
      : '${NumberFormat('0.0', 'pt_BR').format(map.distanceMeters / 1000)} km';
  String duration(DarcapioDeliveryMap map) {
    final minutes = (map.durationSeconds / 60).ceil().clamp(1, 99999);
    return minutes < 60
        ? '$minutes min'
        : '${minutes ~/ 60} h ${minutes % 60} min';
  }

  Widget routeMap(DarcapioDeliveryMap map) => DeliveryRouteMap(
      key: ValueKey(widget.orderId),
      data: map,
      repository: widget.repository,
      orderId: widget.orderId);
  Widget legend(String letter, String title, String address, Color color) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(7)),
            child: Text(letter,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12))),
        const SizedBox(width: 9),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: OrderStyle.ink)),
          Text(address,
              style: const TextStyle(
                  fontSize: 12, height: 1.5, color: OrderStyle.muted)),
        ]))
      ]);

  void expand(DarcapioDeliveryMap map) => showDialog<void>(
      context: context,
      builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(20),
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: 1100,
                  maxHeight: MediaQuery.sizeOf(context).height * .92),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 10, 12),
                    child: Row(children: [
                      const Icon(Icons.route_rounded, color: OrderStyle.teal),
                      const SizedBox(width: 10),
                      const Expanded(
                          child: Text('Trajeto da entrega',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700))),
                      IconButton(
                          tooltip: 'Fechar mapa',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close)),
                    ])),
                Expanded(child: routeMap(map)),
                Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                              '${distance(map)} por ruas · Aproximadamente ${duration(map)} de trajeto',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          legend('A', 'Loja · endereço atual', map.origin,
                              OrderStyle.teal),
                          const SizedBox(height: 10),
                          legend('B', 'Cliente · endereço deste pedido',
                              map.destination, const Color(0xFF2563EB)),
                          const SizedBox(height: 12),
                          const Text(
                              'Use a roda do mouse, os botões ou a pinça para aproximar. Arraste para explorar. A linha indica o trajeto estimado de carro. O marcador do entregador mostra o último GPS recebido durante a entrega.',
                              style: TextStyle(
                                  fontSize: 12, color: OrderStyle.muted)),
                        ])),
              ]))));

  @override
  Widget build(BuildContext context) {
    final map = data;
    return Container(
        margin: const EdgeInsets.only(top: 20),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            border: Border.all(color: OrderStyle.line),
            borderRadius: BorderRadius.circular(12)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(
              padding: EdgeInsets.all(12),
              child: Row(children: [
                Icon(Icons.route_rounded, size: 18, color: OrderStyle.teal),
                SizedBox(width: 8),
                Expanded(
                    child: Text('Da loja até o cliente',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: OrderStyle.ink))),
              ])),
          if (map == null && error == null)
            const SizedBox(
                height: 160,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(height: 12),
                      Text('Carregando trajeto…',
                          style:
                              TextStyle(fontSize: 12, color: OrderStyle.muted)),
                    ]))
          else if (error != null)
            Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(error!,
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: OrderStyle.muted)),
                      TextButton.icon(
                          onPressed: load,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Tentar carregar mapa')),
                    ]))
          else ...[
            AspectRatio(aspectRatio: 5 / 3, child: routeMap(map!)),
            Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(spacing: 14, runSpacing: 6, children: [
                        Text('${distance(map)} por ruas',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: OrderStyle.teal)),
                        Text('≈ ${duration(map)} de trajeto',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: OrderStyle.ink)),
                      ]),
                      const SizedBox(height: 14),
                      legend('A', 'Loja', map.origin, OrderStyle.teal),
                      const SizedBox(height: 10),
                      legend('B', 'Cliente', map.destination,
                          const Color(0xFF2563EB)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                          onPressed: () => expand(map),
                          icon: const Icon(Icons.open_in_full, size: 16),
                          label: const Text('Ampliar mapa')),
                      const SizedBox(height: 6),
                      const Text(
                          'Trajeto estimado a partir do endereço atual da loja. O frete do pedido não é alterado.',
                          style: TextStyle(
                              fontSize: 11,
                              height: 1.5,
                              color: OrderStyle.muted)),
                    ])),
          ],
        ]));
  }
}
