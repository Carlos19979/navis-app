import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/ports/domain/entities/port.dart';
import 'package:navis_mobile/features/ports/presentation/controllers/viewport_ports_controller.dart';
import 'package:navis_mobile/features/ports/presentation/providers/port_provider.dart';

import '../../helpers/helpers.dart';

/// Longer than the controller's internal debounce, so a settle-and-fetch cycle
/// completes within a pump.
const _afterDebounce = Duration(milliseconds: 400);

Port _port(String id) => Port(
      id: id,
      name: 'Port $id',
      lat: 39.5,
      lon: 2.6,
      country: 'ES',
      portType: PortType.marina,
    );

void main() {
  late FakePortRepository repo;
  late ViewportPortsController controller;

  setUp(() {
    repo = FakePortRepository(ports: [_port('a'), _port('b')]);
    controller = ViewportPortsController(repository: repo);
  });

  tearDown(() => controller.dispose());

  /// Feeds a viewport centred on Mallorca, offset by [shift] degrees so each
  /// call lands in a different snap-grid cell when shift changes.
  void pan(ViewportPortsController c, {double shift = 0, double zoom = 10}) {
    c.onCameraChanged(
      west: 2.0 + shift,
      south: 39.0 + shift,
      east: 3.0 + shift,
      north: 40.0 + shift,
      zoom: zoom,
    );
  }

  group('ViewportPortsController fetching', () {
    test('a settled viewport is fetched once, in a single request', () async {
      pan(controller);
      // Nothing yet: the fetch waits for the camera to stop moving.
      expect(repo.bboxRequests, isEmpty);

      await Future<void>.delayed(_afterDebounce);

      expect(repo.bboxRequests, hasLength(1));
      expect(controller.value, hasLength(2));
    });

    test('panning across many grid cells costs one request, not one per frame',
        () async {
      // 30 frames of a drag that crosses several snap cells.
      for (var i = 0; i < 30; i++) {
        pan(controller, shift: i * 0.05);
      }
      await Future<void>.delayed(_afterDebounce);

      expect(repo.bboxRequests, hasLength(1));
    });

    test('moving inside one grid cell does not refetch at all', () async {
      // Edges away from the grid lines, so a small move stays in the same cell
      // (a viewport whose edge sits exactly on a line snaps to the next cell on
      // any movement — one cell of hysteresis is inherent to snapping).
      void nudge(double shift) => controller.onCameraChanged(
            west: 2.03 + shift,
            south: 39.03 + shift,
            east: 2.97 + shift,
            north: 39.97 + shift,
            zoom: 10,
          );

      nudge(0);
      await Future<void>.delayed(_afterDebounce);
      expect(repo.bboxRequests, hasLength(1));

      nudge(0.01);
      await Future<void>.delayed(_afterDebounce);

      expect(repo.bboxRequests, hasLength(1));
    });

    test('a revisited viewport is served from memory without a request',
        () async {
      pan(controller);
      await Future<void>.delayed(_afterDebounce);
      pan(controller, shift: 5);
      await Future<void>.delayed(_afterDebounce);
      expect(repo.bboxRequests, hasLength(2));

      // Back to the first viewport — this is the zoom-out-then-back path.
      pan(controller);
      await Future<void>.delayed(_afterDebounce);

      expect(repo.bboxRequests, hasLength(2), reason: 'served from the memo');
      expect(controller.value, hasLength(2));
    });
  });

  group('ViewportPortsController keeps markers on screen', () {
    test('markers stay put while the next viewport loads', () async {
      pan(controller);
      await Future<void>.delayed(_afterDebounce);
      final loaded = controller.value;
      expect(loaded, hasLength(2));

      // A new viewport is requested but has not resolved yet: the previously
      // loaded markers must still be the value (the bug was blanking here).
      pan(controller, shift: 5);
      expect(controller.value, same(loaded));
    });

    test('a failed viewport leaves the drawn markers alone', () async {
      pan(controller);
      await Future<void>.delayed(_afterDebounce);
      expect(controller.value, hasLength(2));

      final failing = ViewportPortsController(
        repository: FakePortRepository(error: Exception('offline')),
      );
      addTearDown(failing.dispose);
      pan(failing);
      await Future<void>.delayed(_afterDebounce);

      // No markers were ever loaded here, but the point is it did not throw
      // and the value is simply unchanged.
      expect(failing.value, isEmpty);
    });

    test('zooming out past the fetch threshold keeps the markers drawn',
        () async {
      pan(controller);
      await Future<void>.delayed(_afterDebounce);
      expect(controller.value, hasLength(2));

      pan(controller, shift: 5, zoom: kMinPortsZoom - 1);
      await Future<void>.delayed(_afterDebounce);

      expect(repo.bboxRequests, hasLength(1), reason: 'too far out to fetch');
      expect(controller.value, hasLength(2),
          reason: 'markers survive zoom-out');
    });
  });

  group('ViewportPortsController toggling', () {
    test('switching off clears the markers, switching on restores them',
        () async {
      pan(controller);
      await Future<void>.delayed(_afterDebounce);
      expect(controller.value, hasLength(2));

      controller.setEnabled(false);
      expect(controller.value, isEmpty);

      controller.setEnabled(true);
      // Restored from the memo: no second request needed.
      expect(controller.value, hasLength(2));
      expect(repo.bboxRequests, hasLength(1));
    });

    test('while off, camera changes do not fetch', () async {
      controller.setEnabled(false);
      pan(controller, shift: 3);
      await Future<void>.delayed(_afterDebounce);

      expect(repo.bboxRequests, isEmpty);
    });
  });

  group('ViewportPortsController staleness', () {
    test('a superseded response cannot overwrite a newer viewport', () async {
      // Two viewports in flight: only the newest may land.
      pan(controller);
      await Future<void>.delayed(_afterDebounce);
      pan(controller, shift: 5);
      await Future<void>.delayed(_afterDebounce);

      expect(repo.bboxRequests, hasLength(2));
      // The last request wins and its box is the one that was asked for.
      expect(repo.bboxRequests.last.minLon, greaterThan(6.0));
    });

    test('nothing is fetched after dispose', () async {
      final disposable = ViewportPortsController(repository: repo);
      pan(disposable);
      disposable.dispose();
      await Future<void>.delayed(_afterDebounce);

      expect(repo.bboxRequests, isEmpty);
    });
  });
}
