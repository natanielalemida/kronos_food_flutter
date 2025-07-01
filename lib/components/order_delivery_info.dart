import 'package:flutter/material.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/models/pedido_model.dart';

class OrderDeliveryInfo extends StatelessWidget {
  final PedidoModel order;
  final String status;

  const OrderDeliveryInfo({
    super.key,
    required this.order,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 22),
              const SizedBox(width: 8),
              const Text(
                "Endereço de Entrega",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (order.delivery.deliveredBy == "MERCHANT")
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delivery_dining, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        "Entrega própria",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              if (order.orderType == "TAKEOUT")
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Consts.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.my_location, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        "Retirada no local",
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              if (order.delivery.nomeEntregador.isNotEmpty) ...[
                const SizedBox(width: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Consts.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.motorcycle,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        order.delivery.nomeEntregador,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ]
            ],
          ),
          const SizedBox(height: 12),
          if (status == Consts.statusPlaced)
            const Text(
              "As informações de endereço estão ocultas até que o pedido seja aceito",
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${order.delivery.deliveryAddress.streetName}, ${order.delivery.deliveryAddress.streetNumber}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (order.delivery.deliveryAddress.complement.isNotEmpty)
                        Text(
                          "Complemento: ${order.delivery.deliveryAddress.complement}",
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      Text(
                        "${order.delivery.deliveryAddress.neighborhood} - ${order.delivery.deliveryAddress.city}",
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      Text(
                        "CEP: ${order.delivery.deliveryAddress.postalCode}",
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (order.delivery.deliveryAddress.reference.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[100]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.amber[800]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Ponto de referência: ${order.delivery.deliveryAddress.reference}",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.amber[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
