import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:navis_mobile/features/ports/data/repositories/port_repository.dart';
import 'package:navis_mobile/features/ports/domain/entities/port.dart';
import 'package:navis_mobile/features/ports/presentation/providers/port_provider.dart';

/// Drives the map's viewport ports feed for one map screen.
///
/// Why this is a [ValueNotifier] and not a Riverpod provider: the camera
/// reports a new position on *every frame* of a pan or pinch. Routing that
/// through provider state rebuilt the entire map screen per frame, and keying
/// an autoDispose family on the bounding box meant each new box started empty
/// — so the markers blanked out on every pan and only came back if the fetch
/// won the race. Here the screen listens to just this value, so a refresh
/// repaints the marker layer and nothing else, and [value] keeps the last
/// loaded ports while the next box is in flight.
///
/// Three behaviours make panning cheap:
///  * **Grid snapping** — bounds snap outward to [snapBBox]'s grid, so moving
///    within a cell is not a new viewport at all.
///  * **Debounce** — a fetch starts [_debounce] after the camera settles, so a
///    gesture crossing five cells costs one request, not five.
///  * **Memo** — recently seen boxes are served from memory, so zooming out and
///    back in (the case that looked broken) redraws with no request at all.
class ViewportPortsController extends ValueNotifier<List<Port>> {
  ViewportPortsController({
    required PortRepository repository,
    this.enabled = true,
  })  : _repository = repository,
        super(const []);

  final PortRepository _repository;

  /// How long the camera must be still before a viewport is fetched.
  static const _debounce = Duration(milliseconds: 320);

  /// Markers requested per viewport. The server serves a viewport in a single
  /// page up to its own viewport ceiling, so this is one request.
  static const _pageSize = 300;

  /// How many recent viewports to keep in memory. A handful covers the
  /// zoom-out/zoom-in and pan-and-come-back paths that matter.
  static const _memoSize = 24;

  /// Whether the ports layer is switched on. When false the layer is emptied
  /// and no fetching happens; flipping it back on restores the last viewport
  /// (from the memo when possible, so it is instant).
  bool enabled;

  /// Insertion-ordered (Dart's default map), so the oldest viewport is the
  /// first key and eviction is a single removal.
  final Map<PortsBBox, List<Port>> _memo = {};

  Timer? _debounceTimer;
  PortsBBox? _pending;
  PortsBBox? _loaded;

  /// Monotonic request id: a response only lands if it is still the newest
  /// request, so a slow fetch for an abandoned viewport cannot overwrite a
  /// newer one.
  int _requestId = 0;
  bool _disposed = false;

  /// Whether a fetch is currently in flight (for an optional subtle indicator;
  /// the markers themselves never blank while this is true).
  bool get isLoading => _inFlight;
  bool _inFlight = false;

  /// Feeds a new camera position. Safe to call on every frame — it returns
  /// immediately unless the snapped viewport actually changed.
  void onCameraChanged({
    required double west,
    required double south,
    required double east,
    required double north,
    required double zoom,
  }) {
    if (_disposed) return;

    // Too far out to bound a query: the box would cover a near-global slice
    // (and the server rejects spans over 90°). Keep whatever is drawn rather
    // than clearing, so zooming back in has something on screen immediately.
    if (zoom < kMinPortsZoom) {
      _debounceTimer?.cancel();
      return;
    }

    final snapped = snapBBox(
      minLon: west,
      minLat: south,
      maxLon: east,
      maxLat: north,
    );
    if (snapped == _pending || snapped == _loaded) return;

    _pending = snapped;

    // A viewport already in memory needs no request and no debounce.
    final memoized = _memo[snapped];
    if (memoized != null) {
      _debounceTimer?.cancel();
      _loaded = snapped;
      value = memoized;
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, _fetchPending);
  }

  /// Turns the layer on or off. Off empties the markers; on restores the last
  /// known viewport.
  void setEnabled(bool next) {
    if (_disposed || next == enabled) return;
    enabled = next;
    if (!next) {
      _debounceTimer?.cancel();
      _inFlight = false;
      value = const [];
      return;
    }
    final box = _pending ?? _loaded;
    if (box == null) return;
    final memoized = _memo[box];
    if (memoized != null) {
      _loaded = box;
      value = memoized;
      return;
    }
    _pending = box;
    _fetchPending();
  }

  /// Drops the memo and refetches the current viewport.
  void refresh() {
    if (_disposed) return;
    _memo.clear();
    _pending ??= _loaded;
    _loaded = null;
    if (_pending != null) _fetchPending();
  }

  Future<void> _fetchPending() async {
    final bbox = _pending;
    if (_disposed || bbox == null || !enabled) return;

    final id = ++_requestId;
    _inFlight = true;

    try {
      final result = await _repository.getWithinBBox(
        minLon: bbox.minLon,
        minLat: bbox.minLat,
        maxLon: bbox.maxLon,
        maxLat: bbox.maxLat,
        limit: _pageSize,
      );
      if (_disposed || id != _requestId) return;

      _inFlight = false;
      _remember(bbox, result.ports);
      _loaded = bbox;
      if (!enabled) return;
      value = result.ports;

      if (result.nextCursor != null) {
        // A denser area than one page holds. Showing the first page beats
        // walking cursors on every pan; the user zooms in to see the rest.
        debugPrint(
          '[ports] viewport truncated at ${result.ports.length} markers '
          '(more available for this area)',
        );
      }
    } catch (error) {
      if (_disposed || id != _requestId) return;
      _inFlight = false;
      // Keep the markers that are already drawn: a failed refresh should
      // leave the map as it was, not wipe it.
      debugPrint('[ports] viewport fetch failed: $error');
    }
  }

  void _remember(PortsBBox bbox, List<Port> ports) {
    _memo.remove(bbox);
    _memo[bbox] = ports;
    while (_memo.length > _memoSize) {
      _memo.remove(_memo.keys.first);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }
}
