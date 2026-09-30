import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../food_order_brand.dart';
import '../../models/darcapio_order_status.dart';

class OrderStyle {
  static const teal = Color(0xFF006D70);
  static const ink = Color(0xFF202B36);
  static const muted = Color(0xFF77828E);
  static const line = Color(0xFFE7EBEF);
  static const canvas = Color(0xFFF4F6F8);
  static const softTeal = Color(0xFFEAF5F3);
  static final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  static String money(num value) => currency.format(value);

  static Color statusColor(String status) =>
      switch (darcapioOrderStage(status)) {
        'aguardando_aceite' => const Color(0xFFDC7130),
        'em_preparo' => const Color(0xFF3474BA),
        'pronto' => const Color(0xFF05856E),
        'em_rota_entrega' => const Color(0xFF8062B0),
        'concluido' => const Color(0xFF617367),
        'cancelado' => const Color(0xFFBD5353),
        'atencao' => const Color(0xFFBD5353),
        'agendado' => const Color(0xFF8062B0),
        _ => muted,
      };

  static const groups = [
    ('Precisam de atenção', ['atencao'], Icons.priority_high),
    (
      'Aguardando aceite',
      ['aguardando_erp', 'recebido_erp', 'aguardando_aceite'],
      Icons.notifications_active_outlined
    ),
    ('Em preparo', ['aceito', 'em_preparo'], Icons.soup_kitchen_outlined),
    (
      'Pronto',
      ['pronto_retirada', 'pronto_entrega', 'pronto'],
      Icons.takeout_dining_outlined
    ),
    (
      'Em rota de entrega',
      ['saiu_para_entrega', 'em_rota_entrega'],
      Icons.delivery_dining_outlined
    ),
    ('Agendados', ['agendado'], Icons.event_available_outlined),
    ('Concluído', ['concluido'], Icons.check_circle_outline),
    ('Cancelados', ['cancelado'], Icons.cancel_outlined),
  ];
}

class OrderStatusBadge extends StatelessWidget {
  final String label;
  final String status;
  const OrderStatusBadge(
      {super.key, required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = OrderStyle.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(
            child: Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class OrderPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final String? caption;
  const OrderPanel(
      {super.key,
      required this.title,
      required this.icon,
      required this.child,
      this.caption});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: OrderStyle.line),
            borderRadius: BorderRadius.circular(12)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Icon(icon, size: 19, color: FoodOrderBrand.colorOf(context)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: OrderStyle.ink))),
              if (caption != null)
                Text(caption!,
                    style:
                        const TextStyle(fontSize: 12, color: OrderStyle.muted)),
            ]),
          ),
          const Divider(height: 1, color: OrderStyle.line),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ]),
      );
}

class OrderMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  const OrderMeta(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: OrderStyle.muted),
        const SizedBox(width: 6),
        Flexible(
            child: Text(text,
                style: const TextStyle(fontSize: 12, color: OrderStyle.muted))),
      ]);
}
