import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:navis_mobile/features/charts/data/chart_tile_fetcher.dart';
import 'package:navis_mobile/features/charts/data/chart_tile_layer.dart';
import 'package:navis_mobile/features/charts/data/chart_tile_store.dart';
import 'package:navis_mobile/features/charts/data/tile_math.dart';

/// A 1x1 fully transparent PNG, drawn where the tile server told us there is
/// nothing — most of the seamark layer is empty water. Cheaper and quieter
/// than letting flutter_map raise an error tile for every one of them.
final Uint8List blankTilePng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNgYGBgAAAABQAB'
  'eqhXUAAAAABJRU5ErkJggg==',
);

/// Fetches chart tiles through [ChartTileStore], so the map draws from disk
/// first and only asks the network for what it is missing.
///
/// This is the fix for "the map is blank at sea": the previous provider handed
/// tiles to `cached_network_image`, whose cache manager keeps a couple of
/// hundred objects for seven days and hits the network on a miss — which
/// offshore means a grey screen. Here a stored tile is served without any
/// network call at all, and a tile that belongs to a downloaded region is
/// never even considered stale.
class ChartTileProvider extends TileProvider {
  ChartTileProvider({
    required this.layer,
    ChartTileStore? store,
    ChartTileFetcher? fetcher,
  })  : store = store ?? ChartTileStore.instance,
        fetcher = fetcher ?? ChartTileFetcher();

  final ChartTileLayer layer;
  final ChartTileStore store;
  final ChartTileFetcher fetcher;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return ChartTileImage(
      layer: layer,
      ref: (z: coordinates.z, x: coordinates.x, y: coordinates.y),
      store: store,
      fetcher: fetcher,
      // flutter_map fills in the User-Agent from `userAgentPackageName`; the
      // public tile servers reject requests without one.
      headers: Map<String, String>.of(headers),
    );
  }
}

/// One chart tile, resolved store-first.
@immutable
class ChartTileImage extends ImageProvider<ChartTileImage> {
  const ChartTileImage({
    required this.layer,
    required this.ref,
    required this.store,
    required this.fetcher,
    required this.headers,
  });

  final ChartTileLayer layer;
  final TileRef ref;
  final ChartTileStore store;
  final ChartTileFetcher fetcher;
  final Map<String, String> headers;

  @override
  Future<ChartTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<ChartTileImage>(this);

  @override
  ImageStreamCompleter loadImage(
    ChartTileImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: key._resolve(decode),
      scale: 1,
      debugLabel: key._url,
    );
  }

  String get _url => layer.url(ref.z, ref.x, ref.y);

  Future<ui.Codec> _resolve(ImageDecoderCallback decode) async {
    final stored = await _stored();
    if (stored != null && !_isStale(stored)) {
      return _decodeStored(stored, decode);
    }

    try {
      final bytes = await fetcher.fetch(layer, ref, headers: headers);
      await _save(bytes);
      return _decodeBytes(bytes.isEmpty ? blankTilePng : bytes, decode);
    } on Exception {
      // Offline, or the server is unreachable: a stale tile is a far better
      // chart than no chart. With nothing stored there is nothing to draw, so
      // let flutter_map treat it as a missing tile.
      if (stored != null) return _decodeStored(stored, decode);
      rethrow;
    }
  }

  /// Reading the store is best-effort. If it cannot be opened, the chart still
  /// has a network to fall back on, and a broken cache must not be the reason
  /// the map goes blank.
  Future<StoredTile?> _stored() async {
    try {
      return await store.lookup(layer, ref);
    } catch (_) {
      return null;
    }
  }

  /// Writing is best-effort too: a full disk costs the user the cache, not the
  /// tile they are looking at.
  Future<void> _save(Uint8List bytes) async {
    try {
      await store.save(layer, ref, bytes);
    } catch (_) {}
  }

  /// A tile from a downloaded region never goes stale — the user asked for it
  /// precisely so it would still be there weeks later, out of signal.
  bool _isStale(StoredTile stored) {
    if (stored.pinned) return false;
    return DateTime.now().difference(stored.fetchedAt) >
        ChartTileStore.browseMaxAge;
  }

  Future<ui.Codec> _decodeStored(
    StoredTile stored,
    ImageDecoderCallback decode,
  ) {
    return _decodeBytes(stored.bytes ?? blankTilePng, decode);
  }

  Future<ui.Codec> _decodeBytes(
    Uint8List bytes,
    ImageDecoderCallback decode,
  ) async {
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is ChartTileImage &&
      other.layer == layer &&
      other.ref == ref &&
      other.store == store;

  @override
  int get hashCode => Object.hash(layer, ref.z, ref.x, ref.y, store);
}
