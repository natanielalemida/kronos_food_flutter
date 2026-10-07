import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:kronos_food/models/order_receipt.dart';
import 'package:kronos_food/repositories/darcapio_repository.dart';
import 'package:kronos_food/service/order_receipt_service.dart';
import 'food_order_details_design_test.dart' show previewIfoodOrder;

DarcapioOrder deliveryOrder(
    {bool lowercase = false, bool pickup = false, int? customerOrdersCount}) {
  Map<String, dynamic> fields(Map<String, dynamic> values) => lowercase
      ? values.map((key, value) => MapEntry(key.toLowerCase(), value))
      : values;
  return DarcapioOrder.fromJson(fields({
    'PedidoId': 'receipt-darcapio',
    'CodigoDelivery': 72,
    'Situacao': 'saiu_para_entrega',
    'VersaoStatus': 4,
    'ClienteNome': 'Cliente de teste',
    'PedidosClienteNaLoja': customerOrdersCount,
    'FormaPagamento': 'Dinheiro',
    'CriadoEm': '2026-09-30T14:00:00Z',
    'NomeEntregador': 'Carlos - Teste',
    'Pedido': fields({
      'Total': pickup ? 63.8 : 69.8,
      'Retirada': pickup,
      'TaxaEntrega': pickup ? 0 : 6,
      'PrecisaTroco': true,
      'TrocoPara': 100,
      'Endereco': fields({
        'Rua': 'Rua das Palmeiras',
        'Numero': '120',
        'Complemento': 'Apartamento 302',
        'Bairro': 'Centro',
        'Cidade': 'Fortaleza',
        'Uf': 'CE',
        'Cep': '60000-000'
      }),
      'Itens': [
        fields({
          'Descricao': 'X-burger artesanal',
          'Quantidade': 2,
          'ValorUnitario': 24.9,
          'Observacao': 'Sem cebola',
          'Adicionais': [
            fields({'Descricao': 'Bacon extra', 'Valor': 5}),
            fields({'Descricao': 'Cheddar extra', 'Valor': 2}),
          ],
        })
      ],
    }),
  }));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Darcapio mantém adicionais, total do servidor, endereço e troco', () {
    for (final lowercase in [false, true]) {
      final receipt = OrderReceipt.fromDarcapio(
          deliveryOrder(lowercase: lowercase),
          storeName: 'Loja de teste');
      expect(receipt.number, '0072');
      expect(receipt.source, 'Darcapio');
      expect(receipt.store, 'Loja de teste');
      expect(receipt.items.single.quantity, 2);
      expect(receipt.items.single.unitPrice, 24.9);
      expect(receipt.items.single.observations, 'Sem cebola');
      expect(receipt.items.single.options, [
        (label: 'Bacon extra', value: 5.0),
        (label: 'Cheddar extra', value: 2.0),
      ]);
      expect(receipt.subtotal, closeTo(63.8, .001));
      expect(receipt.total, 69.8);
      expect(receipt.deliveryFee, 6);
      expect(receipt.changeFor! - receipt.pending, closeTo(30.2, .001));
      expect(receipt.deliveryLines, contains('Entregador: Carlos - Teste'));
      expect(
          receipt.deliveryLines, contains('Endereço: Rua das Palmeiras, 120'));
      expect(receipt.pickupCode, isEmpty);
      expect(receipt.phone, isEmpty);
      expect(receipt.expectedDelivery, isNull);
    }
  });
  test('Retirada não imprime endereço antigo nem horário de entrega inventado',
      () {
    final receipt = OrderReceipt.fromDarcapio(deliveryOrder(pickup: true));
    expect(receipt.fulfillment, 'RETIRADA');
    expect(receipt.deliveryLines, isEmpty);
    expect(receipt.deliveryFee, 0);
    expect(receipt.subtotal, receipt.total);
    expect(receipt.expectedDelivery, isNull);
  });
  test(
      'iFood preserva os descontos, pagamento e itens no template compartilhado',
      () {
    final receipt = OrderReceipt.fromIfood(previewIfoodOrder());
    expect(receipt.number, '8275');
    expect(receipt.items.length, 2);
    expect(receipt.discounts, [(label: 'IFOOD', value: 3.0)]);
    expect(receipt.paymentMethods, [(label: 'Dinheiro', value: 40.9)]);
    expect(receipt.total, 40.9);
    expect(receipt.additionalFees, 1);
    expect(receipt.changeFor, 50);
    expect(receipt.deliveryLines, contains('Endereço: Rua das Palmeiras, 120'));
  });
  test('Gera cupons PDF dos dois canais e de retirada', () async {
    final receipts = {
      'darcapio-entrega': OrderReceipt.fromDarcapio(deliveryOrder(),
          storeName: 'Loja de teste'),
      'darcapio-retirada': OrderReceipt.fromDarcapio(
          deliveryOrder(pickup: true),
          storeName: 'Loja de teste'),
      'ifood': OrderReceipt.fromIfood(previewIfoodOrder()),
    };
    for (final entry in receipts.entries) {
      final bytes = await generateOrderReceipt(entry.value,
          version: 'teste',
          font: pw.Font.helvetica(),
          boldFont: pw.Font.helveticaBold());
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(1500));
      final preview = Platform.environment['KRONOS_RECEIPT_PREVIEW_DIR'];
      if (preview != null) {
        await Directory(preview).create(recursive: true);
        await File('$preview/${entry.key}.pdf').writeAsBytes(bytes);
      }
    }
  });
}
