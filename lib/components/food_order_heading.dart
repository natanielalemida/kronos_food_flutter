import 'package:flutter/material.dart';
import '../models/food_order_entry.dart';
import 'food_order_brand.dart';
import 'darcapio/order_style.dart';

class FoodOrderHeading extends StatelessWidget {
  final String number, status, statusLabel;
  final FoodOrderSource source;
  final VoidCallback? onPrint;
  final bool printing;
  final Widget? fulfillment;
  const FoodOrderHeading(
      {super.key,
      required this.number,
      required this.status,
      required this.statusLabel,
      required this.source,
      this.onPrint,
      this.fulfillment,
      this.printing = false});
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        final compact = bounds.maxWidth < 600;
        final storeName = source == FoodOrderSource.darcapio
            ? FoodOrderBrand.storeOf(context)?.name
            : null;
        final heading = Row(children: [
          FoodSourceLogo(source, size: 32, tile: true),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('DETALHES DO PEDIDO',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                        color: OrderStyle.muted)),
                const SizedBox(height: 6),
                Text('Pedido #$number',
                    style: TextStyle(
                        fontSize: compact ? 24 : 28,
                        letterSpacing: -.7,
                        fontWeight: FontWeight.w700,
                        color: OrderStyle.ink)),
                if (storeName?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(storeName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: OrderStyle.muted)),
                ],
              ])),
        ]);
        final statusAndPrint = Row(mainAxisSize: MainAxisSize.min, children: [
          OrderStatusBadge(label: statusLabel, status: status),
          if (onPrint != null) ...[
            const SizedBox(width: 10),
            IconButton.outlined(
                onPressed: printing ? null : onPrint,
                tooltip: 'Imprimir pedido',
                style: IconButton.styleFrom(
                    foregroundColor: FoodOrderBrand.colorFor(source)),
                icon: const Icon(Icons.print_outlined, size: 19)),
          ],
        ]);
        if (fulfillment != null && bounds.maxWidth >= 1000) {
          return Row(children: [
            Expanded(child: heading),
            const SizedBox(width: 24),
            Expanded(child: fulfillment!),
            const SizedBox(width: 24),
            statusAndPrint,
          ]);
        }
        if (compact) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: statusAndPrint),
                if (fulfillment != null) ...[
                  const SizedBox(height: 12),
                  fulfillment!,
                ],
              ]);
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: heading),
                const SizedBox(width: 20),
                statusAndPrint,
              ]),
              if (fulfillment != null) ...[
                const SizedBox(height: 12),
                fulfillment!,
              ],
            ]);
      });
}
