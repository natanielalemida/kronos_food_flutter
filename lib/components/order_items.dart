import 'package:flutter/material.dart';
import 'package:kronos_food/models/pedido_model.dart';

class OrderItems extends StatelessWidget {
  final PedidoModel order;

  const OrderItems({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shopping_cart, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                "Itens do Pedido",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(),
          // ListView.builder(
          //   itemCount: order.items.length,
          //   itemBuilder: (context, index) {
          //     final item = order.items[index];
          //     return _buildItemRow(item);
          //   },
          // ),
          ...order.items.map((item) => _buildItemRow(item)),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Subtotal:"),
                Text("R\$ ${order.total.subTotal.toStringAsFixed(2)}"),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Taxa de entrega:"),
                Text("R\$ ${order.total.deliveryFee.toStringAsFixed(2)}"),
              ],
            ),
          ),
          if (order.total.additionalFees > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Taxas adicionais:"),
                  Text("R\$ ${order.total.additionalFees.toStringAsFixed(2)}"),
                ],
              ),
            ),
          if (order.total.benefits > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Descontos:"),
                  Text("-R\$ ${order.total.benefits.toStringAsFixed(2)}"),
                ],
              ),
            ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total:",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "R\$ ${order.total.orderAmount.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(Item item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "${item.quantity}x",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (item.observations.isNotEmpty)
                  Row(
                    children: [
                      const Icon(
                        Icons.comment_rounded,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        item.observations,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                if (item.options.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...item.options.map((option) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "•",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "${option.name}${option.quantity > 1 ? ' (${option.quantity}x)' : ''}",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            if (option.price > 0)
                              Text(
                                "+R\$ ${option.price.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "R\$ ${item.totalPrice.toStringAsFixed(2)}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
