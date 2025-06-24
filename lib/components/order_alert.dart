import 'package:flutter/material.dart';
import 'package:kronos_food/models/pedido_model.dart';

class OrderAlert extends StatelessWidget {
  final PedidoModel order;
  final VoidCallback onAccept;
  final VoidCallback onCancel;

  const OrderAlert({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate the remaining time to accept the order
    final Widget remainingTimeWidget = _buildRemainingTime();
    
    return Card(
      elevation: 2,
      color: Colors.red.shade50,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Aceite o pedido para ver os dados do cliente",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
                remainingTimeWidget,
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "As informações do cliente estão ocultas até que o pedido seja aceito",
              style: TextStyle(color: Colors.red.shade800),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancelar pedido'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check),
                  label: const Text('Aceitar pedido'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRemainingTime() {
    // Calcula o tempo decorrido desde a criação do pedido
    final now = DateTime.now();
    final minutesElapsed = now.difference(order.createdAt).inMinutes;
    final minutesRemaining = 6 - minutesElapsed; // Assumindo 6 minutos para aceitar

    if (minutesRemaining <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          "Tempo esgotado!",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: minutesRemaining <= 2 ? Colors.red : Colors.orange,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.timer,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              "$minutesRemaining min",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
  }
} 