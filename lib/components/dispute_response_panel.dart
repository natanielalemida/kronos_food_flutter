import 'package:flutter/material.dart';

class DisputeResponsePanel extends StatefulWidget {
  final VoidCallback onClose;
  final Function(String action, [String? value]) onSubmit;

  const DisputeResponsePanel({
    super.key,
    required this.onClose,
    required this.onSubmit,
  });

  @override
  State<DisputeResponsePanel> createState() => _DisputeResponsePanelState();
}

class _DisputeResponsePanelState extends State<DisputeResponsePanel> {
  int? _selected;
  final TextEditingController _partialRefundController = TextEditingController();
  final TextEditingController _rejectionReasonController = TextEditingController();

  bool get isValid {
    if (_selected == null) return false;
    if (_selected == 2 && _partialRefundController.text.isEmpty) return false;
    if (_selected == 3 && _rejectionReasonController.text.isEmpty) return false;
    return true;
  }

  void _submit() {
    if (!isValid) return;

    String action;
    String? value;

    switch (_selected) {
      case 1:
        action = "accept_full_refund";
        break;
      case 2:
        action = "propose_partial_refund";
        value = _partialRefundController.text;
        break;
      case 3:
        action = "reject_refund";
        value = _rejectionReasonController.text;
        break;
      default:
        action = "";
    }

    widget.onSubmit(action, value);
  }

  Widget _radioCard({
    required int value,
    required String title,
    required String subtitle,
    Widget? child,
  }) {
    final isSelected = _selected == value;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Colors.red : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? Colors.red.shade50 : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Radio<int>(
                value: value,
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v),
                activeColor: Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (child != null && isSelected) ...[
            const SizedBox(height: 12),
            child,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return         Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Material(
      elevation: 8,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.4,
        padding: const EdgeInsets.all(24),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título e Fechar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Problemas no pedido #4018 entregue',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Você tem 9 minutos e 44 segundos para responder',
              style: TextStyle(color: Colors.red.shade600, fontSize: 12),
            ),
            const Divider(height: 32),

            // Mensagem do cliente
            const Text('Cliente solicitou o reembolso do pedido',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('O pedido veio com todos os itens errados'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.grey.shade100,
              ),
              child: Row(
                children: [
                  Image.asset('assets/images/prato_errado.png', width: 60, height: 60, fit: BoxFit.cover),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'kkkkkkkkkakejriamkakskkdkakkfkaifjakfkakdkkakdkakkakk',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Opções
            const Text('Escolha uma das opções pra responder:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            _radioCard(
              value: 1,
              title: 'Aceitar reembolso de R\$ 24,89',
              subtitle: 'Cliente receberá o valor total desse pedido',
            ),
            _radioCard(
              value: 2,
              title: 'Enviar proposta de reembolso',
              subtitle: 'Cliente pode aceitar ou recusar o valor',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Qual o valor você gostaria de reembolsar?'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _partialRefundController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixText: 'R\$ ',
                      hintText: 'Digite o valor (até R\$ 12,00)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            _radioCard(
              value: 3,
              title: 'Recusar reembolso de R\$ 24,89',
              subtitle: 'Cliente ainda pode solicitar uma análise do iFood',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Conte para o cliente por qual motivo você vai recusar:'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _rejectionReasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Descreva o motivo*',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      text: 'Saiba como ',
                      style: TextStyle(color: Colors.blue[700], fontSize: 12),
                      children: const [
                        TextSpan(
                          text:
                              'essa justificativa pode ajudar sua loja a prevenir cancelamentos.',
                          style: TextStyle(color: Colors.black87),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isValid ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Enviar'),
              ),
            ),
          ],
        ),
      ),
    )
    );
  }
}
