import 'package:flutter/material.dart';
import 'package:kronos_food/consts.dart';
import 'package:kronos_food/models/pedido_model.dart';
import 'package:kronos_food/utils/ifood_event_utils.dart';

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
    final hasDeliveryAddress = _hasDeliveryAddress(order);
    final salesChannel = IfoodEventUtils.normalize(order.salesChannel);
    final orderType = IfoodEventUtils.normalize(order.orderType);
    final deliveredBy = IfoodEventUtils.normalize(order.delivery.deliveredBy);
    final isTotem = salesChannel.contains('TOTEM');
    final isTakeout = orderType.contains('TAKEOUT');
    final isDelivery = hasDeliveryAddress ||
        IfoodEventUtils.isIfoodDelivery(deliveredBy) ||
        IfoodEventUtils.isMerchantDelivery(deliveredBy);
    final sectionTitle =
        isDelivery ? 'Endereco de Entrega' : 'Retirada / Balcao';
    final sectionIcon =
        isDelivery ? Icons.location_on : Icons.storefront_outlined;
    final sectionColor = isDelivery ? Colors.red : Consts.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
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
              Icon(sectionIcon, color: sectionColor, size: 22),
              const SizedBox(width: 8),
              Text(
                sectionTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  if (isTotem)
                    _buildBadge(
                      icon: Icons.point_of_sale_outlined,
                      text: 'Pedido Totem',
                      backgroundColor:
                          Consts.primaryColor.withValues(alpha: 0.12),
                      foregroundColor: Consts.primaryColor,
                    ),
                  if (IfoodEventUtils.isMerchantDelivery(deliveredBy))
                    _buildBadge(
                      icon: Icons.delivery_dining,
                      text: 'Entrega propria',
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.grey.shade700,
                    ),
                  if (IfoodEventUtils.isIfoodDelivery(deliveredBy))
                    _buildBadge(
                      icon: Icons.two_wheeler,
                      text: 'Entrega iFood',
                      backgroundColor:
                          Consts.primaryColor.withValues(alpha: 0.12),
                      foregroundColor: Consts.primaryColor,
                    ),
                  if (isTakeout || !isDelivery)
                    _buildBadge(
                      icon: Icons.my_location,
                      text: 'Sem entrega',
                      backgroundColor: Consts.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  if (order.delivery.nomeEntregador.isNotEmpty)
                    _buildBadge(
                      icon: Icons.motorcycle,
                      text: order.delivery.nomeEntregador,
                      backgroundColor: Consts.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isDelivery)
            _buildInfoBox(
              icon: Icons.info_outline,
              text: isTotem
                  ? 'Pedido vindo do TOTEM, sem entrega associada. Por isso nao existe mapa, entregador ou localizacao em tempo real.'
                  : 'Pedido sem entrega associada. Por isso nao existe mapa, entregador ou localizacao em tempo real.',
            )
          else if (status == Consts.statusPlaced)
            const Text(
              'As informacoes de endereco estao ocultas ate que o pedido seja aceito',
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
                        '${order.delivery.deliveryAddress.streetName}, ${order.delivery.deliveryAddress.streetNumber}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (order.delivery.deliveryAddress.complement.isNotEmpty)
                        Text(
                          'Complemento: ${order.delivery.deliveryAddress.complement}',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      Text(
                        '${order.delivery.deliveryAddress.neighborhood} - ${order.delivery.deliveryAddress.city}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      Text(
                        'CEP: ${order.delivery.deliveryAddress.postalCode}',
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
                        'Ponto de referencia: ${order.delivery.deliveryAddress.reference}',
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

  static bool _hasDeliveryAddress(PedidoModel order) {
    final address = order.delivery.deliveryAddress;
    return address.streetName.trim().isNotEmpty ||
        address.streetNumber.trim().isNotEmpty ||
        address.neighborhood.trim().isNotEmpty ||
        address.city.trim().isNotEmpty ||
        address.postalCode.trim().isNotEmpty;
  }

  Widget _buildBadge({
    required IconData icon,
    required String text,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: foregroundColor),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.teal.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.teal.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
