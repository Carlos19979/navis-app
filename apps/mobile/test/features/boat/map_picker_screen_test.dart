// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/boat/presentation/screens/map_picker_screen.dart';
import 'package:navis_mobile/features/ports/domain/entities/port.dart';
import 'package:navis_mobile/features/ports/presentation/providers/port_provider.dart';

import '../../helpers/helpers.dart';

/// Ignores tile/network-image plumbing errors that FlutterMap surfaces in
/// widget tests (same pattern as the W1 chart spike): they are cosmetic —
/// there is no network or path_provider in the test environment.
void installTileNoiseFilter() {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    const tolerated = [
      'MissingPluginException',
      'HTTP request failed',
      'NetworkImage',
      'CachedNetworkImageProvider',
      'HttpException',
      'SocketException',
      'Failed host lookup',
      'Connection refused',
      'Connection closed',
      'Couldn\'t download or retrieve file',
      'HttpExceptionWithStatus',
    ];
    if (tolerated.any(message.contains)) return;
    originalOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalOnError);
}

void main() {
  Widget buildSubject({
    double? initialLatitude,
    double? initialLongitude,
    bool showNameField = false,
    List<Port> ports = const [],
  }) {
    return buildTestApp(
      MapPickerScreen(
        initialLatitude: initialLatitude,
        initialLongitude: initialLongitude,
        showNameField: showNameField,
      ),
      overrides: [
        allPortsProvider.overrideWith((ref) async => ports),
      ],
    );
  }

  group('MapPickerScreen', () {
    testWidgets('shows home-port hint banner when nothing is selected',
        (tester) async {
      setPhoneSize(tester);
      installTileNoiseFilter();
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.text('Tap the map to set your home port'), findsOneWidget);
      expect(find.text('Confirm'), findsNothing);

      await drain(tester);
    });

    testWidgets('shows generic hint banner when a name is required',
        (tester) async {
      setPhoneSize(tester);
      installTileNoiseFilter();
      await tester.pumpWidget(buildSubject(showNameField: true));
      await pumpScreen(tester);

      expect(find.text('Tap the map to select a location'), findsOneWidget);

      await drain(tester);
    });

    testWidgets('tapping the map selects a point', (tester) async {
      setPhoneSize(tester);
      installTileNoiseFilter();
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.tap(find.byType(FlutterMap));
      await pumpScreen(tester);

      // Hint gone, coordinates banner + confirm + marker appear.
      expect(find.text('Tap the map to set your home port'), findsNothing);
      expect(find.textContaining(', '), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.byIcon(Icons.anchor), findsOneWidget);

      await drain(tester);
    });

    testWidgets(
        'confirm is disabled until a name is entered when showNameField',
        (tester) async {
      setPhoneSize(tester);
      installTileNoiseFilter();
      await tester.pumpWidget(
        buildSubject(
          initialLatitude: 39.5,
          initialLongitude: 2.6,
          showNameField: true,
        ),
      );
      await pumpScreen(tester);

      // Point pre-selected: the app-bar check exists but stays disabled and
      // the banner confirm button is absent while the name is empty.
      final checkButton = find.ancestor(
        of: find.byTooltip('Confirm location'),
        matching: find.byType(IconButton),
      );
      expect(checkButton, findsOneWidget);
      expect(tester.widget<IconButton>(checkButton).onPressed, isNull);
      expect(find.text('Confirm'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Cala Blava');
      await pumpScreen(tester);

      expect(tester.widget<IconButton>(checkButton).onPressed, isNotNull);
      expect(find.text('Confirm'), findsOneWidget);

      await drain(tester);
    });

    testWidgets('confirm pops with the selected point', (tester) async {
      setPhoneSize(tester);
      installTileNoiseFilter();
      MapPickerResult? result;
      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<MapPickerResult>(
                      MaterialPageRoute(
                        builder: (_) => const MapPickerScreen(
                          initialLatitude: 39.5,
                          initialLongitude: 2.6,
                        ),
                      ),
                    );
                  },
                  child: const Text('open picker'),
                ),
              ),
            ),
          ),
          overrides: [
            allPortsProvider.overrideWith((ref) async => <Port>[]),
          ],
        ),
      );
      await pumpScreen(tester);

      await tester.tap(find.text('open picker'));
      await pumpScreen(tester);

      await tester.tap(find.text('Confirm'));
      await pumpScreen(tester);

      expect(result, isNotNull);
      expect(result!.point.latitude, closeTo(39.5, 0.0001));
      expect(result!.point.longitude, closeTo(2.6, 0.0001));
      expect(result!.name, isNull);

      await drain(tester);
    });

    testWidgets('tapping a port marker selects the port and fills its name',
        (tester) async {
      setPhoneSize(tester);
      installTileNoiseFilter();
      // Port at the default map center so its marker is on screen.
      const port = Port(
        id: 'port-1',
        name: 'Port Andratx',
        lat: 39.57,
        lon: 2.63,
        country: 'ES',
        portType: PortType.marina,
      );
      await tester.pumpWidget(buildSubject(showNameField: true, ports: [port]));
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Port Andratx'));
      await pumpScreen(tester);

      // Name field is pre-filled with the port name and confirm unlocks.
      expect(find.text('Port Andratx'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.ancestor(
              of: find.byTooltip('Confirm location'),
              matching: find.byType(IconButton),
            ))
            .onPressed,
        isNotNull,
      );

      await drain(tester);
    });
  });
}
