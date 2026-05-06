// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Navis';

  @override
  String get login => 'Log In';

  @override
  String get register => 'Register';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get noAccount => 'Don\'t have an account?';

  @override
  String get hasAccount => 'Already have an account?';

  @override
  String get boats => 'Boats';

  @override
  String get documents => 'Documents';

  @override
  String get trips => 'Trips';

  @override
  String get weather => 'Weather';

  @override
  String get events => 'Events';

  @override
  String get charts => 'Charts';

  @override
  String get profile => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get noBoats => 'No boats yet. Add your first boat!';

  @override
  String get noDocuments => 'No documents yet. Add your first document!';

  @override
  String get noTrips => 'No trips recorded yet. Start your first trip!';

  @override
  String get noEvents => 'No upcoming events.';

  @override
  String get expired => 'Expired';

  @override
  String get warning => 'Warning';

  @override
  String get critical => 'Critical';

  @override
  String get ok => 'OK';

  @override
  String get valid => 'Valid';

  @override
  String daysRemaining(int count) {
    return '$count days remaining';
  }

  @override
  String daysOverdue(int count) {
    return '$count days overdue';
  }

  @override
  String get nauticalMiles => 'NM';

  @override
  String get knots => 'kt';

  @override
  String get kilometers => 'km';

  @override
  String get meters => 'm';

  @override
  String get boatName => 'Boat Name';

  @override
  String get registration => 'Registration Number';

  @override
  String get boatType => 'Boat Type';

  @override
  String get length => 'Length (m)';

  @override
  String get homePort => 'Home Port';

  @override
  String get sailboat => 'Sailboat';

  @override
  String get motorboat => 'Motorboat';

  @override
  String get catamaran => 'Catamaran';

  @override
  String get other => 'Other';

  @override
  String get documentType => 'Document Type';

  @override
  String get expiryDate => 'Expiry Date';

  @override
  String get alertDays => 'Alert Days Before Expiry';

  @override
  String get notes => 'Notes';

  @override
  String get photo => 'Photo';

  @override
  String get addPhoto => 'Add Photo';

  @override
  String get departure => 'Departure';

  @override
  String get arrival => 'Arrival';

  @override
  String get distance => 'Distance';

  @override
  String get duration => 'Duration';

  @override
  String get maxSpeed => 'Max Speed';

  @override
  String get avgSpeed => 'Avg Speed';

  @override
  String get startTrip => 'Start Trip';

  @override
  String get stopTrip => 'Stop Trip';

  @override
  String get pauseTrip => 'Pause';

  @override
  String get resumeTrip => 'Resume';

  @override
  String get recording => 'Recording...';

  @override
  String get totalTrips => 'Total Trips';

  @override
  String get tripStatistics => 'Trip Statistics';

  @override
  String get totalDistanceNm => 'NM sailed';

  @override
  String get totalHoursAtSea => 'Hours at sea';

  @override
  String get portsVisited => 'Ports visited';

  @override
  String get topSpeed => 'Top speed';

  @override
  String get fuelConsumed => 'Fuel consumed';

  @override
  String get engineHoursTotal => 'Engine hours';

  @override
  String get yearInReview => 'Year in Review';

  @override
  String get monthlyActivity => 'Monthly Activity';

  @override
  String get tripsLabel => 'Trips';

  @override
  String get distanceNmLabel => 'NM';

  @override
  String get hoursLabel => 'Hours';

  @override
  String get allTime => 'All Time';

  @override
  String get totalDistance => 'Total Distance';

  @override
  String get totalHours => 'Total Hours';

  @override
  String get temperature => 'Temperature';

  @override
  String get windSpeed => 'Wind Speed';

  @override
  String get windDirection => 'Wind Direction';

  @override
  String get waveHeight => 'Wave Height';

  @override
  String get forecast => 'Forecast';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get eventDate => 'Event Date';

  @override
  String get eventLocation => 'Location';

  @override
  String get registerForEvent => 'Register';

  @override
  String get theme => 'Theme';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get language => 'Language';

  @override
  String get notifications => 'Notifications';

  @override
  String get logout => 'Log Out';

  @override
  String get logoutConfirm => 'Are you sure you want to log out?';

  @override
  String get deleteConfirm => 'Are you sure you want to delete this?';

  @override
  String get requiredField => 'This field is required';

  @override
  String get invalidEmail => 'Please enter a valid email';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get engineHours => 'Engine Hours';

  @override
  String get fuelUsed => 'Fuel Used';

  @override
  String get crew => 'Crew';

  @override
  String get logbook => 'Logbook';

  @override
  String get tripDetails => 'Trip Details';

  @override
  String get editBoat => 'Edit Boat';

  @override
  String get myBoats => 'My Boats';

  @override
  String get addBoat => 'Add Boat';

  @override
  String get newDocument => 'New Document';

  @override
  String get editDocument => 'Edit Document';

  @override
  String get renewDocument => 'Renew Document';

  @override
  String get documentDetails => 'Document Details';

  @override
  String get renewalCost => 'Renewal Cost';

  @override
  String get renewalProvider => 'Provider / Company';

  @override
  String get lastRenewal => 'Last Renewal';

  @override
  String get date => 'Date';

  @override
  String get cost => 'Cost';

  @override
  String get provider => 'Provider';

  @override
  String get deleteDocument => 'Delete Document';

  @override
  String get deleteDocumentConfirm =>
      'Are you sure you want to delete this document?';

  @override
  String get documentDeleted => 'Document deleted';

  @override
  String get documentSaved => 'Document saved';

  @override
  String get documentUpdated => 'Document updated';

  @override
  String get documentRenewed => 'Document renewed';

  @override
  String get failedToSave => 'Failed to save document';

  @override
  String get failedToDelete => 'Failed to delete';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get addScan => 'Add Scan';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get alertDaysBeforeExpiry => 'Alert Days Before Expiry';

  @override
  String get validNumber => 'Please enter a valid number';

  @override
  String get uploading => 'Uploading...';

  @override
  String get noInternetConnection => 'No internet connection';

  @override
  String offlineWithPending(int count) {
    return 'Offline • $count pending';
  }

  @override
  String syncingChanges(int count) {
    return 'Syncing $count changes…';
  }

  @override
  String get searchEvents => 'Search events...';

  @override
  String get noEventsFound => 'No events found';

  @override
  String get featured => 'Featured';

  @override
  String get appearance => 'Appearance';

  @override
  String get darkThemeActive => 'Dark theme active';

  @override
  String get lightThemeActive => 'Light theme active';

  @override
  String get systemDefault => 'System default';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get documentExpiryAlerts => 'Document Expiry Alerts';

  @override
  String get expiryAlertsSubtitle => 'Get notified before documents expire';

  @override
  String get eventReminders => 'Event Reminders';

  @override
  String get eventRemindersSubtitle => 'Get reminded about upcoming events';

  @override
  String get dataAndStorage => 'Data & Storage';

  @override
  String get clearImageCache => 'Clear Image Cache';

  @override
  String get clearImageCacheSubtitle => 'Remove cached photos and map tiles';

  @override
  String get clearOfflineData => 'Clear Offline Data';

  @override
  String get clearOfflineDataSubtitle =>
      'Remove cached boats, documents, trips';

  @override
  String get imageCacheCleared => 'Image cache cleared';

  @override
  String get offlineDataCleared => 'Offline data cleared';

  @override
  String get account => 'Account';

  @override
  String get deleteBoat => 'Delete Boat';

  @override
  String deleteBoatConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"? This will also remove all associated documents and trips.';
  }

  @override
  String get certificates => 'Certificates, insurance, inspections';

  @override
  String get tripHistory => 'Trip history and statistics';

  @override
  String get modifyBoatDetails => 'Modify boat details';

  @override
  String get removePermanently => 'Remove this boat permanently';

  @override
  String get details => 'Details';

  @override
  String get type => 'Type';

  @override
  String get statistics => 'Statistics';

  @override
  String get recordTrip => 'Record Trip';

  @override
  String get boat => 'Boat';

  @override
  String get boatPhoto => 'Boat photo';

  @override
  String get goBack => 'Go back';

  @override
  String get addNewBoat => 'Add new boat';

  @override
  String get homePortOptional => 'Home Port (optional)';

  @override
  String get wind => 'Wind';

  @override
  String get waves => 'Waves';

  @override
  String get humidity => 'Humidity';

  @override
  String get currentConditions => 'Current Conditions';

  @override
  String get calm => 'Calm';

  @override
  String get moderate => 'Moderate';

  @override
  String get rough => 'Rough';

  @override
  String get sendResetLink => 'Send Reset Link';

  @override
  String get passwordResetSent =>
      'Password reset email sent. Check your inbox.';

  @override
  String get failedToSendResetEmail => 'Failed to send reset email';

  @override
  String get tripSaved => 'Trip saved!';

  @override
  String get failedToSaveTrip => 'Failed to save trip';

  @override
  String get tripDeleted => 'Trip deleted';

  @override
  String get selectArrivalPort => 'Select Arrival Port';

  @override
  String get commaSeparatedNames => 'Comma-separated names';

  @override
  String get crewMembers => 'Crew Members';

  @override
  String get updateTrip => 'Update Trip';

  @override
  String get saveTrip => 'Save Trip';

  @override
  String get notLoggedIn => 'Not logged in';

  @override
  String get helpAndSupport => 'Help & Support';

  @override
  String get aboutNavis => 'About Navis';

  @override
  String get speedAbbr => 'SPD';

  @override
  String get headingAbbr => 'HDG';

  @override
  String get distanceAbbr => 'DIST';

  @override
  String get timeAbbr => 'TIME';

  @override
  String get alert => 'Alert';

  @override
  String get daysBeforeExpiry => 'days before expiry';

  @override
  String get selectLocation => 'Select Location';

  @override
  String get totalEngineHours => 'Total engine hours';

  @override
  String get averageSpeed => 'Average speed';

  @override
  String thisYear(String year) {
    return 'This Year ($year)';
  }

  @override
  String get locationAccessNeeded =>
      'Location access is needed\nfor weather data.';

  @override
  String get sevenDayForecast => '7-Day Forecast';

  @override
  String get forecastNotAvailable => 'Forecast data not available.';

  @override
  String memberSince(String date) {
    return 'Member since $date';
  }

  @override
  String get deleteTrip => 'Delete Trip';

  @override
  String get deleteTripConfirm => 'Are you sure you want to delete this trip?';

  @override
  String get shareTrip => 'Share trip';

  @override
  String get editTrip => 'Edit trip';

  @override
  String get notRecorded => 'Not recorded';

  @override
  String get enterValidNumber => 'Enter a valid number';

  @override
  String get completeTrip => 'Complete Trip';

  @override
  String get arrivalPort => 'Arrival Port';

  @override
  String get savingTrip => 'Saving trip...';

  @override
  String get fuelUnit => 'L';

  @override
  String get locationPermissionRequired =>
      'Location permission is required to record trips';

  @override
  String get locationPermissionDenied =>
      'Location permission permanently denied. Enable in settings.';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get boatManagement => 'BOAT MANAGEMENT';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get pleaseEnterBoatName => 'Please enter the boat name';

  @override
  String get pleaseEnterRegistration => 'Please enter the registration number';

  @override
  String get pleaseEnterLength => 'Please enter the length';

  @override
  String get pleaseEnterEmail => 'Please enter your email';

  @override
  String get pleaseEnterPassword => 'Please enter your password';

  @override
  String get boatUpdated => 'Boat updated successfully';

  @override
  String get boatCreated => 'Boat created successfully';

  @override
  String get failedToSaveBoat => 'Failed to save boat';

  @override
  String get newBoat => 'New Boat';

  @override
  String get boatDetailsSection => 'Boat Details';

  @override
  String get pickLocationOnMap => 'Pick location on map';

  @override
  String get updateBoat => 'Update Boat';

  @override
  String get createBoat => 'Create Boat';

  @override
  String get createAccount => 'Create Account';

  @override
  String get joinNavisSubtitle => 'JOIN NAVIS AND MANAGE YOUR BOAT';

  @override
  String get pleaseConfirmPassword => 'Please confirm your password';

  @override
  String get confirm => 'Confirm';

  @override
  String get selectHomePort => 'Select Home Port';

  @override
  String get documentInfo => 'Document Info';

  @override
  String get alertsAndNotes => 'Alerts & Notes';

  @override
  String get renewalDetails => 'Renewal Details';

  @override
  String get documentScan => 'Document scan';

  @override
  String get saveDocument => 'Save Document';

  @override
  String get updateDocument => 'Update Document';

  @override
  String get interested => 'Interested';

  @override
  String get notInterested => 'Not Interested';

  @override
  String get eventDetails => 'Event Details';

  @override
  String get departurePort => 'Departure Port';

  @override
  String get pleaseEnterDeparturePort => 'Please enter the departure port';

  @override
  String get arrivalPortOptional => 'Arrival Port (optional)';

  @override
  String get engineHoursOptional => 'Engine Hours (optional)';

  @override
  String get fuelUsedOptional => 'Fuel Used (liters, optional)';

  @override
  String get crewMembersCommaSeparated => 'Crew Members (comma-separated)';

  @override
  String get tripUpdated => 'Trip updated';

  @override
  String get failedToUpdateTrip => 'Failed to update trip';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get navisUser => 'Navis User';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get nearbyPorts => 'Nearby Ports';

  @override
  String get portTypeMarina => 'Marina';

  @override
  String get portTypeAnchorage => 'Anchorage';

  @override
  String get portTypeFuel => 'Fuel Station';

  @override
  String get portTypeCommercial => 'Commercial';

  @override
  String get portTypeFishing => 'Fishing Port';

  @override
  String get portTypeOther => 'Other';

  @override
  String depthLabel(Object depth) {
    return 'Depth: ${depth}m';
  }

  @override
  String vhfChannelLabel(Object channel) {
    return 'VHF Ch $channel';
  }

  @override
  String get portFacilities => 'Facilities';

  @override
  String get noNearbyPorts => 'No ports found nearby';

  @override
  String get tapPortForDetails => 'Tap a port marker for details';

  @override
  String get docTypeRegistration => 'Registration';

  @override
  String get docTypeInsurance => 'Insurance';

  @override
  String get docTypeInspection => 'Inspection';

  @override
  String get docTypeLicense => 'License';

  @override
  String get docTypeSafetyCertificate => 'Safety Certificate';

  @override
  String get docTypeRadioLicense => 'Radio License';

  @override
  String get docTypePollutionCertificate => 'Pollution Certificate';

  @override
  String get docTypeMedicalCertificate => 'Medical Certificate';

  @override
  String get docTypeLifeRaft => 'Life Raft';

  @override
  String get docTypeFireExtinguisher => 'Fire Extinguisher';

  @override
  String get docTypeFlares => 'Flares';

  @override
  String get docTypeFirstAidKit => 'First Aid Kit';

  @override
  String get docTypeFishingPermit => 'Fishing Permit';

  @override
  String get confirmLocation => 'Confirm location';

  @override
  String get portNameHint => 'Port name (e.g. Cala Blava)';

  @override
  String get tapMapToSelect => 'Tap the map to select a location';

  @override
  String get tapMapToSetHomePort => 'Tap the map to set your home port';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get centerOnGps => 'Center on GPS';

  @override
  String get toggleSeamarks => 'Toggle sea marks';

  @override
  String get togglePorts => 'Show ports';

  @override
  String get toggleTripTracks => 'Show trip tracks';
}
