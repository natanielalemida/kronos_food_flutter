import 'package:flutter/material.dart';
import '../../models/courier_management.dart';
import 'order_style.dart';

class CourierAccessCard extends StatelessWidget {
  final CourierAccess courier;
  final VoidCallback? onInvite, onRevoke;
  const CourierAccessCard(
      {super.key, required this.courier, this.onInvite, this.onRevoke});
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: OrderStyle.line),
          borderRadius: BorderRadius.circular(12)),
      child: LayoutBuilder(builder: (context, size) {
        final identity =
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CircleAvatar(
              backgroundColor: OrderStyle.softTeal,
              foregroundColor: OrderStyle.teal,
              child: Icon(Icons.delivery_dining_outlined)),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(courier.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: OrderStyle.ink)),
                const SizedBox(height: 5),
                Text('Cadastro #${courier.code} · Entregador da loja',
                    style: const TextStyle(color: OrderStyle.muted)),
                const SizedBox(height: 12),
                Wrap(spacing: 14, runSpacing: 8, children: [
                  Text(courier.statusLabel,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: courier.state == CourierAccessState.connected
                              ? OrderStyle.teal
                              : OrderStyle.muted)),
                  Text(
                      '${courier.activeOrders} ${courier.activeOrders == 1 ? 'entrega em andamento' : 'entregas em andamento'}',
                      style: const TextStyle(color: OrderStyle.muted)),
                  if (courier.sharingLocation)
                    const Text('Compartilhamento de GPS ativo',
                        style: TextStyle(color: OrderStyle.teal)),
                ]),
              ])),
        ]);
        final actions = Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(
              onPressed: onInvite,
              icon: const Icon(Icons.phonelink_ring_outlined, size: 18),
              label:
                  Text(courier.hasAccess ? 'Novo convite' : 'Gerar convite')),
          if (courier.hasAccess)
            OutlinedButton(
                onPressed: onRevoke,
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFBC3545)),
                child: const Text('Encerrar acesso')),
        ]);
        return size.maxWidth < 780
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [identity, const SizedBox(height: 22), actions])
            : Row(children: [
                Expanded(child: identity),
                const SizedBox(width: 24),
                actions
              ]);
      }));
}
