import 'package:flutter/material.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/models/pedido_model.dart';

class OrderCustomerInfo extends StatelessWidget {
  final PedidoModel order;
  final String status;

  const OrderCustomerInfo({
    super.key,
    required this.order,
    required this.status,
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
              Icon(Icons.person, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                "Informações do Cliente",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(),
          if (status == Consts.statusPlaced)
            const Text(
              "As informações do cliente estão ocultas até que o pedido seja aceito",
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            )
          else ...[
            Text("Nome: ${order.customer.name}"),
            Text("Telefone: ${order.customer.phone.number}"),
            if (order.customer.documentNumber.isNotEmpty)
              Text("Documento: ${order.customer.documentNumber}"),
            if (order.customer.ordersCountOnMerchant > 0)
              Text(
                "Cliente fiel: ${order.customer.ordersCountOnMerchant} pedidos anteriores",
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ],
      ),
    );
  }
} 