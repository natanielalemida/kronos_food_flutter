import 'package:flutter/material.dart';

class FoodFulfillmentBadge extends StatelessWidget {
  final bool pickup;
  const FoodFulfillmentBadge({super.key, required this.pickup});
  @override
  Widget build(BuildContext context) {
    final color = pickup ? const Color(0xFF9B570F) : const Color(0xFF285CB0);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .09),
            border: Border.all(color: color.withValues(alpha: .2)),
            borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox.square(
              dimension: 20,
              child: Icon(
                  pickup ? Icons.storefront_outlined : Icons.delivery_dining,
                  size: 16,
                  color: color)),
          const SizedBox(width: 6),
          Text(pickup ? 'RETIRADA' : 'ENTREGA',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ]));
  }
}
