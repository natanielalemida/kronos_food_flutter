import 'package:flutter/material.dart';
import '../models/food_order_entry.dart';
import 'food_order_brand.dart';

class FoodSourceBadge extends StatelessWidget {
  final FoodOrderSource source;
  const FoodSourceBadge(this.source, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = FoodOrderBrand.colorFor(source);
    return Semantics(
      label: 'Origem do pedido: ${source.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: .15)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          FoodSourceLogo(source, size: 20),
          if (source == FoodOrderSource.darcapio) ...[
            const SizedBox(width: 6),
            Text(source.label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ]),
      ),
    );
  }
}
