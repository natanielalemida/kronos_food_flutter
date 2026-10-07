import 'package:flutter/material.dart';
import '../utils/customer_order_count.dart';
import 'darcapio/order_style.dart';

class CustomerOrderCount extends StatelessWidget {
  final int? count;
  final bool ifood;
  const CustomerOrderCount(
      {super.key, required this.count, this.ifood = false});

  @override
  Widget build(BuildContext context) {
    final label = customerOrderCountLabel(count);
    if (label == null) return const SizedBox.shrink();
    return Tooltip(
      message: ifood
          ? 'Contagem informada pelo iFood para esta loja nos últimos 5 anos.'
          : 'Pedidos do cliente no Darcapio nesta loja. Inclui pedidos em andamento e concluídos; cancelados e recusados não entram na contagem.',
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.history, size: 14, color: OrderStyle.muted),
        const SizedBox(width: 5),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12,
                  color: OrderStyle.muted,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
