import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronos_food/components/darcapio/delivery_confirmation_dialog.dart';

void main() {
  testWidgets('Código e confirmação continuam acessíveis com teclado aberto',
      (tester) async {
    tester.view.physicalSize = const Size(420, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    String? confirmedCode;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => DeliveryConfirmationDialog(
                  pickup: false,
                  orderNumber: 123,
                  confirm: (code) async => confirmedCode = code,
                  describeError: (error) => error.toString(),
                ),
              ),
              child: const Text('Abrir confirmação'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Abrir confirmação'));
    await tester.pumpAndSettle();
    final input = find.widgetWithText(TextField, 'Código do cliente');
    await tester.enterText(input, '123456');
    await tester.pumpAndSettle();

    final confirm = find.widgetWithText(FilledButton, 'Confirmar');
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(confirm).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(input).dy));

    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(confirmedCode, '123456');
    expect(find.byType(DeliveryConfirmationDialog), findsNothing);
  });
}
