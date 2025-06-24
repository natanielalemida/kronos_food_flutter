import 'package:flutter/material.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/models/pedido_model.dart';

class OrderPaymentInfo extends StatelessWidget {
  final PedidoModel order;
  final String status;

  const OrderPaymentInfo({
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
              Icon(Icons.payment, color: Colors.green),
              SizedBox(width: 8),
              Text(
                "Forma de Pagamento",
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
              "As informações de pagamento estão ocultas até que o pedido seja aceito",
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            )
          else ...[
            ...order.payments.methods.map((method) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _getPaymentIcon(method),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_formatPaymentType(method.type),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  if (method.card.brand.isNotEmpty)
                                    Text(
                                      _formatCardBrand(method.card.brand),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (method.currency.isNotEmpty &&
                                      method.method.isNotEmpty)
                                    Text(
                                      _formatPaymentMethod(method.method),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (method.type == "OFFLINE") ...[
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "Pagamento na entrega",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange[800],
                                        ),
                                      ),
                                    ),
                                    if (method.method == "CASH" &&
                                        (method.cash.changeFor ?? 0) > 0) ...[
                                      //valor a receber
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Text(
                                            "Valor a receber em dinheiro: ",
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          Text(
                                            "R\$ ${(method.cash.changeFor ?? 0).toStringAsFixed(2)}",
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Text(
                                            "Valor para levar de troco: ",
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          Text(
                                            "R\$ ${((method.cash.changeFor ?? 0) - (method.value)).toStringAsFixed(2)}",
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ]
                                  ]
                                ],
                              ),
                            ],
                          ),
                          Text(
                            "R\$ ${method.value.toStringAsFixed(2)}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
            if (order.payments.prepaid > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.payments.prepaid == order.total.orderAmount
                              ? "Pedido totalmente pago online (R\$ ${order.payments.prepaid.toStringAsFixed(2)})"
                              : "Pré-pago parcial: R\$ ${order.payments.prepaid.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(),
            Row(
              children: [
                const Icon(Icons.receipt, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  "Incluir CPF na nota fiscal: ${order.customer.documentNumber}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }

  String _formatPaymentType(String type) {
    switch (type.toUpperCase()) {
      case 'ONLINE':
        return 'Pagamento Online';
      case 'OFFLINE':
        return 'Pagamento na Entrega';
      default:
        return type;
    }
  }

  String _formatPaymentMethod(String method) {
    switch (method.toUpperCase()) {
      case 'CREDIT':
        return 'Cartão de Crédito';
      case 'DEBIT':
        return 'Cartão de Débito';
      case 'CASH':
        return 'Dinheiro';
      case 'PIX':
        return 'PIX';
      case 'MEAL_VOUCHER':
        return 'Vale Refeição';
      case 'FOOD_VOUCHER':
        return 'Vale Alimentação';
      default:
        return method;
    }
  }

  String _formatCardBrand(String brand) {
    // Converter para title case (primeira letra maiúscula)
    if (brand.isEmpty) return '';

    String formattedBrand = brand.toLowerCase();
    switch (formattedBrand) {
      case 'mastercard':
        return 'Mastercard';
      case 'visa':
        return 'Visa';
      case 'elo':
        return 'Elo';
      case 'amex':
      case 'american express':
        return 'American Express';
      case 'hipercard':
        return 'Hipercard';
      default:
        // Capitalizar primeira letra
        return formattedBrand[0].toUpperCase() + formattedBrand.substring(1);
    }
  }

  Widget _getPaymentIcon(PaymentMethod method) {
    // Determinar o tipo de ícone e cor baseado no tipo de pagamento
    IconData icon;
    Color color;
    Color backgroundColor = Colors.grey.shade100;

    // Definir estilo baseado no método de pagamento
    switch (method.type.toUpperCase()) {
      case 'CREDIT':
        icon = Icons.credit_card;
        color = Colors.blue;
        backgroundColor = Colors.blue.shade50;
        break;
      case 'DEBIT':
        icon = Icons.credit_card;
        color = Colors.green;
        backgroundColor = Colors.green.shade50;
        break;
      case 'CASH':
        icon = Icons.payments;
        color = Colors.green.shade700;
        backgroundColor = Colors.green.shade50;
        break;
      case 'PIX':
        icon = Icons.qr_code;
        color = Colors.purple;
        backgroundColor = Colors.purple.shade50;
        break;
      case 'MEAL_VOUCHER':
        icon = Icons.fastfood;
        color = Colors.red;
        backgroundColor = Colors.red.shade50;
        break;
      case 'FOOD_VOUCHER':
        icon = Icons.restaurant;
        color = Colors.orange;
        backgroundColor = Colors.orange.shade50;
        break;
      case 'ONLINE':
        icon = Icons.shopping_cart;
        color = Colors.blue;
        backgroundColor = Colors.blue.shade50;
        break;
      case 'OFFLINE':
        icon = Icons.delivery_dining;
        color = Colors.orange;
        backgroundColor = Colors.orange.shade50;
        break;
      default:
        icon = Icons.payment;
        color = Colors.grey;
    }

    // Se tiver a bandeira do cartão, mostrar uma representação visual dela
    if (method.card.brand.isNotEmpty &&
        (method.type.toUpperCase() == 'CREDIT' ||
            method.type.toUpperCase() == 'DEBIT')) {
      final brand = method.card.brand.toLowerCase();

      // Verificar o tipo de bandeira para personalizar ainda mais
      if (brand == 'visa') {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Text(
              'VISA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        );
      } else if (brand == 'mastercard') {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.deepOrange.shade600,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Text(
              'MC',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        );
      } else if (brand == 'elo') {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.yellow.shade600,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Text(
              'ELO',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        );
      } else if (brand == 'amex' || brand == 'american express') {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue.shade800,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Text(
              'AMEX',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
        );
      }
    }

    // Ícone padrão para métodos que não possuem bandeira específica
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Center(
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}
