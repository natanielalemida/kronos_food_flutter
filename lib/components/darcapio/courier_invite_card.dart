import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/courier_management.dart';
import 'order_style.dart';

class CourierInviteCard extends StatelessWidget {
  final CourierInvite invite;
  final String name;
  const CourierInviteCard(
      {super.key, required this.invite, required this.name});
  Future<void> copy(BuildContext context, String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(label)));
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: OrderPanel(
          title: 'Conectar o celular de $name',
          icon: Icons.smartphone_outlined,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text(
                'No app Kronos Entregador, informe o endereço da loja e o convite abaixo.'),
            const SizedBox(height: 20),
            const Text('Endereço da loja',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SelectableText(invite.storeUrl),
            const SizedBox(height: 18),
            const Text('Convite de acesso',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: OrderStyle.softTeal,
                    borderRadius: BorderRadius.circular(8)),
                child: SelectableText(
                    invite.expired
                        ? 'Este convite expirou. Gere outro para conectar o celular.'
                        : invite.code,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: OrderStyle.teal))),
            const SizedBox(height: 12),
            Text(
                'Uso único · Válido até ${DateFormat('HH:mm').format(invite.expiresAt)}. Compartilhe somente com esse entregador.',
                style: const TextStyle(color: OrderStyle.muted)),
            const SizedBox(height: 20),
            Wrap(spacing: 12, runSpacing: 10, children: [
              FilledButton.icon(
                  onPressed: invite.expired
                      ? null
                      : () => copy(context, invite.code, 'Convite copiado.'),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Copiar convite')),
              OutlinedButton(
                  onPressed: () => copy(
                      context, invite.storeUrl, 'Endereço da loja copiado.'),
                  child: const Text('Copiar endereço da loja')),
            ]),
          ])));
}
