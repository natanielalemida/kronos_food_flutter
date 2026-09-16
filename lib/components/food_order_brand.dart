import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/food_order_entry.dart';
import '../models/food_store_identity.dart';

class FoodOrderBrand extends InheritedWidget {
  static const ifoodRed = Color(0xFFEA1D2C);
  static const darcapioTeal = Color(0xFF006D70);
  final FoodOrderSource source;
  final FoodStoreIdentity? store;
  const FoodOrderBrand(
      {super.key, required this.source, this.store, required super.child});

  static Color colorFor(FoodOrderSource source) =>
      source == FoodOrderSource.ifood ? ifoodRed : darcapioTeal;
  static Color colorOf(BuildContext context) => colorFor(
      context.dependOnInheritedWidgetOfExactType<FoodOrderBrand>()?.source ??
          FoodOrderSource.darcapio);
  static FoodStoreIdentity? storeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FoodOrderBrand>()?.store;
  @override
  bool updateShouldNotify(FoodOrderBrand oldWidget) =>
      source != oldWidget.source || store != oldWidget.store;
}

class FoodSourceLogo extends StatelessWidget {
  final FoodOrderSource source;
  final double size;
  final bool tile;
  const FoodSourceLogo(this.source,
      {super.key, this.size = 24, this.tile = false});
  @override
  Widget build(BuildContext context) {
    final store = FoodOrderBrand.storeOf(context);
    final color = FoodOrderBrand.colorFor(source);
    Widget fallback() => SvgPicture.asset('assets/images/darcapio-logo.svg',
        key: const ValueKey('darcapio-fallback-logo'),
        width: size,
        height: size);
    Widget logo;
    if (source == FoodOrderSource.ifood) {
      logo = SvgPicture.asset('assets/images/ifood-logo.svg',
          width: size * 1.65,
          height: size,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
    } else if (store?.logo != null) {
      final bytes = store!.logo!;
      final prefix = utf8
          .decode(bytes.take(256).toList(), allowMalformed: true)
          .trimLeft();
      logo = prefix.startsWith('<svg') || prefix.startsWith('<?xml')
          ? SvgPicture.memory(bytes,
              key: const ValueKey('company-logo'),
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => fallback())
          : Image.memory(bytes,
              key: const ValueKey('company-logo'),
              width: size,
              height: size,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              cacheWidth: 256,
              errorBuilder: (_, __, ___) => fallback());
    } else {
      logo = fallback();
    }
    return Semantics(
      label: source == FoodOrderSource.ifood
          ? 'Logo iFood'
          : store?.logo != null
              ? 'Logo da loja ${store!.name}'
              : 'Logo Darcapio',
      image: true,
      child: tile
          ? Container(
              width: size * 1.65 + 24,
              height: size + 24,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: .18))),
              child: logo,
            )
          : logo,
    );
  }
}
