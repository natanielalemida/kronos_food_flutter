import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'darcapio/order_style.dart';
import 'food_order_brand.dart';

class FoodOrderProgressStep {
  final String label;
  final IconData icon;
  final Color color;
  final DateTime? time;
  final bool reached;
  const FoodOrderProgressStep(
      {required this.label,
      required this.icon,
      required this.color,
      this.time,
      this.reached = true});
}

/// Shared presentation only: each source supplies its own real stages.
class FoodOrderProgress extends StatelessWidget {
  final List<FoodOrderProgressStep> steps;
  final double progress;
  final String? currentLabel;
  final bool cancelled;
  const FoodOrderProgress(
      {super.key,
      required this.steps,
      required this.progress,
      this.currentLabel,
      this.cancelled = false});

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    final accent = FoodOrderBrand.colorOf(context);
    return OrderPanel(
      title: 'Status do pedido',
      icon: Icons.timeline_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (currentLabel != null) ...[
          Text(currentLabel!,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: OrderStyle.ink)),
          const SizedBox(height: 20),
        ],
        LayoutBuilder(builder: (context, bounds) {
          final minWidth = steps.length * 112.0;
          final width = math.max(bounds.maxWidth, minWidth);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
                width: width,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < steps.length; i++)
                      Expanded(child: _step(steps[i], i)),
                  ],
                )),
          );
        }),
        const SizedBox(height: 22),
        Semantics(
          label: 'Andamento das etapas do pedido',
          value: cancelled ? 'Pedido cancelado' : '${(value * 100).round()}%',
          child: LayoutBuilder(
              builder: (context, bounds) => Container(
                    height: 7,
                    decoration: BoxDecoration(
                        color: OrderStyle.line,
                        borderRadius: BorderRadius.circular(8)),
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      key: const ValueKey('order-progress-fill'),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 450),
                      curve: Curves.easeInOutCubic,
                      height: 7,
                      width: bounds.maxWidth * value,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                            colors: [accent.withValues(alpha: .22), accent]),
                      ),
                    ),
                  )),
        ),
      ]),
    );
  }

  Widget _step(FoodOrderProgressStep step, int index) {
    final color = step.reached ? step.color : OrderStyle.muted;
    return Semantics(
      label: '${step.label}: ${step.reached ? 'alcançado' : 'aguardando'}',
      child: Column(children: [
        Row(children: [
          Expanded(
              child: Container(
                  height: 2,
                  color: index == 0
                      ? Colors.transparent
                      : step.reached
                          ? step.color.withValues(alpha: .35)
                          : OrderStyle.line)),
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: step.reached ? step.color : OrderStyle.canvas,
                  border: Border.all(
                      color: step.reached ? step.color : OrderStyle.line),
                  boxShadow: step.reached
                      ? [
                          BoxShadow(
                              color: step.color.withValues(alpha: .16),
                              blurRadius: 10,
                              offset: const Offset(0, 3))
                        ]
                      : null),
              child: Icon(step.icon,
                  size: 20, color: step.reached ? Colors.white : color)),
          Expanded(
              child: Container(
                  height: 2,
                  color: index == steps.length - 1
                      ? Colors.transparent
                      : steps[index + 1].reached
                          ? steps[index + 1].color.withValues(alpha: .35)
                          : OrderStyle.line)),
        ]),
        const SizedBox(height: 10),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(step.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color))),
        const SizedBox(height: 4),
        Text(
            step.time == null
                ? (step.reached ? ' ' : 'Aguardando')
                : DateFormat('HH:mm').format(step.time!.toLocal()),
            style: const TextStyle(fontSize: 11, color: OrderStyle.muted)),
      ]),
    );
  }
}
