import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kronos_food/components/food_order_brand.dart';
import 'package:kronos_food/components/food_order_list.dart';
import 'package:kronos_food/components/food_source_badge.dart';
import 'package:kronos_food/models/food_order_entry.dart';
import 'package:kronos_food/models/food_store_identity.dart';
import 'package:kronos_food/repositories/darcapio_repository.dart';
import 'package:kronos_food/pages/food_orders_view.dart';
import 'darcapio_test.dart' show FakeDarcapio;
import 'food_order_details_design_test.dart'
    show previewIfoodOrder, previewDarcapioOrder;

final testLogo = Uint8List.fromList(utf8.encode(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="11" fill="#8437A5"/></svg>'));

class LogoRepository extends FakeDarcapio {
  bool failLogo = false;
  @override
  Future<FoodStoreIdentity> storeIdentity() async {
    if (failLogo) throw StateError('Imagem indisponível');
    return FoodStoreIdentity(
        company: 1, name: 'Restaurante da loja', logo: testLogo);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'Company logo parser accepts ERP base64 and tolerates missing/invalid images',
      () {
    expect(
        FoodStoreIdentity.fromJson({
          'Codigo': 2,
          'NomeFantasia': 'Loja B',
          'ImgLogo': base64Encode(testLogo)
        }).logo,
        testLogo);
    for (final raw in [
      null,
      '',
      'invalid***',
      [],
      [999]
    ]) {
      expect(FoodStoreIdentity.fromJson({'codigo': 2, 'imgLogo': raw}).logo,
          isNull);
    }
  });

  test(
      'Identity is fetched through the Service using the selected company session',
      () async {
    SharedPreferences.setMockInitialValues({
      'server_ip': 'https://erp.example/arc',
      'kronos_token': 'test-session',
      'company_code': '2'
    });
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      expect(options.uri.toString(), 'https://erp.example/arc/empresa/2');
      expect(options.headers['Auth'], 'test-session');
      expect(options.headers['Empresa'], '2');
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: {
        'Resultado': {'Codigo': 2, 'ImgLogo': base64Encode(testLogo)}
      }));
    }));
    final repo = DarcapioRepository(client: dio);
    expect((await repo.storeIdentity()).logo, testLogo);
    repo.dispose();
  });

  test('A logo from another company is rejected', () async {
    SharedPreferences.setMockInitialValues({
      'server_ip': 'https://erp.example/arc',
      'kronos_token': 'test-session',
      'company_code': '2'
    });
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(
          onRequest: (options, handler) =>
              handler.resolve(Response(requestOptions: options, data: {
                'Resultado': {'Codigo': 1, 'ImgLogo': base64Encode(testLogo)}
              }))));
    final repo = DarcapioRepository(client: dio);
    await expectLater(repo.storeIdentity(), throwsStateError);
    repo.dispose();
  });

  testWidgets(
      'iFood always uses its own SVG; Darcapio uses the company logo or fallback',
      (tester) async {
    for (final logo in [
      testLogo,
      null,
      Uint8List.fromList([0, 1, 2])
    ]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: FoodOrderBrand(
                  source: FoodOrderSource.darcapio,
                  store: FoodStoreIdentity(company: 2, logo: logo),
                  child: const Row(children: [
                    FoodSourceBadge(FoodOrderSource.ifood),
                    FoodSourceBadge(FoodOrderSource.darcapio)
                  ])))));
      await tester.pumpAndSettle();
      final ifood = find.descendant(
          of: find.byWidgetPredicate((widget) =>
              widget is FoodSourceBadge &&
              widget.source == FoodOrderSource.ifood),
          matching: find.byType(SvgPicture));
      expect(
          (tester.widget<SvgPicture>(ifood).bytesLoader as SvgAssetLoader)
              .assetName,
          'assets/images/ifood-logo.svg');
      expect(find.byKey(const ValueKey('darcapio-fallback-logo')),
          identical(logo, testLogo) ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('Mixed order cards keep source colors when selected',
      (tester) async {
    final ifood = FoodOrderEntry.ifood(previewIfoodOrder());
    final darcapio = FoodOrderEntry.darcapio(previewDarcapioOrder());
    for (final selected in [ifood, darcapio]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: FoodOrderList(
                  orders: [ifood, darcapio],
                  selectedId: selected.key,
                  onSelected: (_) {},
                  connected: true))));
      await tester.pumpAndSettle();
      final card = tester.widget<Material>(find.byKey(ValueKey(selected.key)));
      expect((card.shape as RoundedRectangleBorder).side.color,
          FoodOrderBrand.colorFor(selected.source));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'Company logo reaches the order list; logo failure does not block orders',
      (tester) async {
    for (final failure in [false, true]) {
      await tester.pumpWidget(MaterialApp(
          home: FoodOrdersView(
              repository: LogoRepository()..failLogo = failure)));
      await tester.pumpAndSettle();
      expect(find.text('#0123'), findsOneWidget);
      expect(find.byKey(const ValueKey('company-logo')),
          failure ? findsNothing : findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
