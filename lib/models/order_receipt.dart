import '../repositories/darcapio_repository.dart';
import 'pedido_model.dart';

typedef ReceiptAmount = ({String label, double value});

class ReceiptItem {
  final String name, observations;
  final num quantity;
  final double unitPrice;
  final List<ReceiptAmount> options;
  const ReceiptItem(this.name, this.quantity, this.unitPrice, this.observations,
      this.options);
}

/// Dados de impressão; não envia pedidos ou ações a nenhum canal.
class OrderReceipt {
  final String number, source, store, fulfillment, customer, phone, pickupCode;
  final DateTime created;
  final DateTime? expectedDelivery;
  final bool pickup;
  final List<ReceiptItem> items;
  final List<ReceiptAmount> discounts, paymentMethods;
  final List<String> deliveryLines, documentLines;
  final double subtotal, deliveryFee, additionalFees, total, prepaid, pending;
  final double? changeFor;

  const OrderReceipt({
    required this.number,
    required this.source,
    required this.store,
    required this.fulfillment,
    required this.customer,
    required this.created,
    required this.pickup,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.pending,
    required this.paymentMethods,
    this.phone = '',
    this.pickupCode = '',
    this.expectedDelivery,
    this.discounts = const [],
    this.deliveryLines = const [],
    this.documentLines = const [],
    this.additionalFees = 0,
    this.prepaid = 0,
    this.changeFor,
  });

  factory OrderReceipt.fromDarcapio(DarcapioOrder order, {String? storeName}) {
    String address(String field) =>
        darcapioField(order.address, field)?.toString().trim() ?? '';
    final street = [address('rua'), address('numero')]
        .where((part) => part.isNotEmpty)
        .join(', ');
    final city = [address('cidade'), address('uf')]
        .where((part) => part.isNotEmpty)
        .join(' - ');
    return OrderReceipt(
      number: order.delivery.toString().padLeft(4, '0'),
      source: 'Darcapio',
      store: storeName ?? '',
      fulfillment: order.pickup ? 'RETIRADA' : 'ENTREGA',
      customer: order.customer,
      created: order.created,
      pickup: order.pickup,
      items: order.items
          .map((item) => ReceiptItem(
                darcapioField(item, 'descricao')?.toString() ?? '',
                darcapioField(item, 'quantidade') as num? ?? 0,
                (darcapioField(item, 'valorUnitario') as num?)?.toDouble() ?? 0,
                darcapioField(item, 'observacao')?.toString() ?? '',
                (darcapioField(item, 'adicionais') as List? ?? [])
                    .map((option) => (
                          label:
                              darcapioField(option, 'descricao')?.toString() ??
                                  '',
                          value: (darcapioField(option, 'valor') as num?)
                                  ?.toDouble() ??
                              0,
                        ))
                    .toList(),
              ))
          .toList(),
      // Total e taxa já incluem os adicionais calculados pelo servidor.
      subtotal: order.total - order.deliveryFee,
      deliveryFee: order.deliveryFee,
      total: order.total,
      pending: order.total,
      paymentMethods: [(label: order.payment, value: order.total)],
      changeFor: order.needsChange ? order.changeFor : null,
      deliveryLines: order.pickup
          ? []
          : [
              'Entregador: ${order.courierName?.trim().isNotEmpty == true ? order.courierName : 'Entrega própria'}',
              if (street.isNotEmpty) 'Endereço: $street',
              if (address('complemento').isNotEmpty)
                'Comp: ${address('complemento')}',
              if (address('referencia').isNotEmpty)
                'Ref: ${address('referencia')}',
              if (address('bairro').isNotEmpty) 'Bairro: ${address('bairro')}',
              if (city.isNotEmpty) 'Cidade: $city',
              if (address('cep').isNotEmpty) 'CEP: ${address('cep')}',
            ],
    );
  }

  factory OrderReceipt.fromIfood(PedidoModel order) {
    final address = order.delivery.deliveryAddress;
    final pickup = order.orderType == 'TAKEOUT' || order.orderType == 'INDOOR';
    final cash = order.payments.methods
        .where((method) => !method.prepaid && method.cash.changeFor != null)
        .map((method) => method.cash.changeFor!)
        .where((amount) => amount > 0);
    return OrderReceipt(
      number: order.displayId,
      source: order.salesChannel.isEmpty ? 'iFood' : order.salesChannel,
      store: order.merchant.name,
      fulfillment: pickup ? 'RETIRADA' : order.orderType,
      customer: order.customer.name,
      phone: order.customer.phone.number,
      created: order.createdAt,
      expectedDelivery: pickup ? null : order.delivery.deliveryDateTime,
      pickupCode: order.delivery.pickupCode,
      pickup: pickup,
      items: order.items
          .map((item) => ReceiptItem(
                item.name,
                item.quantity,
                item.unitPrice,
                item.observations,
                item.options
                    .map((option) => (
                          label: '${option.quantity}x ${option.name}',
                          value: option.addition,
                        ))
                    .toList(),
              ))
          .toList(),
      subtotal: order.total.subTotal,
      deliveryFee: order.total.deliveryFee,
      additionalFees: order.total.additionalFees,
      total: order.total.orderAmount,
      prepaid: order.payments.prepaid,
      pending: order.payments.pending,
      paymentMethods: order.payments.methods
          .where((method) => !method.prepaid)
          .map((method) =>
              (label: _paymentLabel(method.method), value: method.value))
          .toList(),
      changeFor: cash.isEmpty ? null : cash.first,
      discounts: [
        for (final benefit in order.benefits)
          for (final sponsor in benefit.sponsorshipValues)
            if (sponsor.value > 0)
              (
                label: sponsor.name == 'MERCHANT' ? 'LOJA' : sponsor.name,
                value: sponsor.value
              )
      ],
      documentLines: order.customer.documentNumber.isNotEmpty &&
              order.delivery.deliveredBy == 'MERCHANT'
          ? [
              'Incluir CPF na Nota Fiscal',
              'CPF do Cliente: ${order.customer.documentNumber}'
            ]
          : [],
      deliveryLines: pickup || order.delivery.deliveredBy != 'MERCHANT'
          ? []
          : [
              'Entregador: Entrega própria',
              'Endereço: ${address.streetName}, ${address.streetNumber.isEmpty ? 'S/N' : address.streetNumber}',
              if (address.complement.isNotEmpty) 'Comp: ${address.complement}',
              if (address.reference.isNotEmpty) 'Ref: ${address.reference}',
              'Bairro: ${address.neighborhood}',
              'Cidade: ${address.city} - ${address.state}',
              'CEP: ${address.postalCode}',
            ],
    );
  }
}

String _paymentLabel(String method) => switch (method.toUpperCase()) {
      'CREDIT' => 'Cartão de Crédito',
      'DEBIT' => 'Cartão de Débito',
      'CASH' => 'Dinheiro',
      'PIX' => 'PIX',
      'MEAL_VOUCHER' => 'Vale Refeição',
      'FOOD_VOUCHER' => 'Vale Alimentação',
      _ => method,
    };
