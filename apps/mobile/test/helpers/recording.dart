import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/logbook/presentation/providers/trip_recording_provider.dart';

/// A recording state that just *is*, with no GPS behind it.
///
/// Shared rather than private to one test file because three screens now ask
/// whether a trip is running — Today, the forecast and the chart all label
/// their sail action from it.
class FakeRecordingNotifier extends StateNotifier<TripRecordingState>
    with Mock
    implements TripRecordingNotifier {
  FakeRecordingNotifier(super.state);
}

/// A trip in progress on [boatId].
Override recordingOverride({
  RecordingStatus status = RecordingStatus.recording,
  String? boatId,
}) =>
    tripRecordingProvider.overrideWith(
      (ref) => FakeRecordingNotifier(
        TripRecordingState(status: status, boatId: boatId),
      ),
    );
