import 'dart:async';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../repositories/darcapio_repository.dart';

class DeliveryTileProvider extends TileProvider {
  final DarcapioRepository repository;
  final String orderId;
  final VoidCallback onError;
  final pending = <CancelToken>{};
  DeliveryTileProvider(this.repository, this.orderId, this.onError);
  @override
  bool get supportsCancelLoading => true;
  @override
  ImageProvider getImageWithCancelLoadingSupport(TileCoordinates coordinates,
          TileLayer options, Future<void> cancelLoading) =>
      _DeliveryTileImage(this, (coordinates.z + options.zoomOffset).round(),
          coordinates.x, coordinates.y, cancelLoading);
  @override
  void dispose() {
    for (final token in pending.toList()) {
      token.cancel();
    }
    pending.clear();
  }
}

class _DeliveryTileImage extends ImageProvider<_DeliveryTileImage> {
  final DeliveryTileProvider provider;
  final int z, x, y;
  final Future<void> cancelLoading;
  const _DeliveryTileImage(
      this.provider, this.z, this.x, this.y, this.cancelLoading);
  @override
  Future<_DeliveryTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
          _DeliveryTileImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1);
  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final token = CancelToken();
    provider.pending.add(token);
    unawaited(cancelLoading.then((_) => token.cancel()));
    try {
      final bytes = await provider.repository
          .deliveryMapTile(provider.orderId, z, x, y, cancelToken: token);
      if (token.isCancelled) {
        throw DioException.requestCancelled(
            requestOptions: RequestOptions(), reason: 'Tile fora da tela');
      }
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } catch (error) {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(this));
      if (!token.isCancelled) provider.onError();
      return decode(await ui.ImmutableBuffer.fromUint8List(
          TileProvider.transparentImage));
    } finally {
      provider.pending.remove(token);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is _DeliveryTileImage &&
      identical(provider, other.provider) &&
      other.z == z &&
      other.x == x &&
      other.y == y;
  @override
  int get hashCode => Object.hash(provider, z, x, y);
}
