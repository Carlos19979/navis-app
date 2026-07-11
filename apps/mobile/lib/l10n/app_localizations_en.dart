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
  String get charts => 'Map';

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
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountSubtitle =>
      'Permanently delete your account and all your data';

  @override
  String get deleteAccountWarning =>
      'This permanently deletes your account: boats, documents, trips, maintenance history, groups you own and all uploaded files. This cannot be undone.';

  @override
  String deleteAccountTypeToConfirm(String word) {
    return 'Type $word to confirm';
  }

  @override
  String get deleteAccountConfirmWord => 'DELETE';

  @override
  String get deleteAccountFailed => 'Could not delete the account. Try again.';

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
  String get close => 'Close';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get paywallAutoRenewNotice =>
      'The subscription renews automatically unless you cancel it in your App Store account settings at least 24 hours before the end of the current period.';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutDescription =>
      'Your boat\'s digital logbook: documents, trips, maintenance and weather in one place.';

  @override
  String get couldNotOpenLink => 'Could not open the link';

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

  @override
  String get now => 'Now';

  @override
  String get hourlyForecast => 'Hourly Forecast';

  @override
  String get wcClear => 'Clear';

  @override
  String get wcPartlyCloudy => 'Partly Cloudy';

  @override
  String get wcCloudy => 'Cloudy';

  @override
  String get wcFog => 'Fog';

  @override
  String get wcDrizzle => 'Drizzle';

  @override
  String get wcRain => 'Rain';

  @override
  String get wcSnow => 'Snow';

  @override
  String get wcThunderstorm => 'Thunderstorm';

  @override
  String get wcUnknown => '—';

  @override
  String get inviteCode => 'Invite code';

  @override
  String get codeCopied => 'Code copied';

  @override
  String get copy => 'Copy';

  @override
  String get share => 'Share';

  @override
  String get join => 'Join';

  @override
  String get leave => 'Leave';

  @override
  String get view => 'View';

  @override
  String get remove => 'Remove';

  @override
  String get couldNotSave => 'Could not save';

  @override
  String get couldNotDelete => 'Could not delete';

  @override
  String errorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get membersLabel => 'Members';

  @override
  String get socialLoginFailed => 'Could not sign in with that provider';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get paywallDefaultReason =>
      'Keep your boat legal, maintained and safe. For less than a single fine for expired paperwork.';

  @override
  String get purchaseFailed => 'Could not complete the purchase.';

  @override
  String get nothingToRestore => 'No purchases to restore.';

  @override
  String get welcomeToPro => 'Welcome to Navis Pro!';

  @override
  String get subscribe => 'Subscribe';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get subscriptionsUnavailable =>
      'Subscriptions are not available right now. Try again later.';

  @override
  String get paywallMonthly => 'Monthly';

  @override
  String get paywallYearly => 'Yearly';

  @override
  String get paywallWeekly => 'Weekly';

  @override
  String get paywallLifetime => 'Lifetime';

  @override
  String get proBenefitReminders => 'Unlimited document expiry reminders';

  @override
  String get proBenefitMaintenance => 'Scheduled maintenance reminders';

  @override
  String get proBenefitBoats => 'Up to 3 boats';

  @override
  String get proBenefitGroups => 'Create clubs and events';

  @override
  String get proBenefitAttachments => 'Unlimited document attachments';

  @override
  String get planBoatLimitReached => 'You\'ve reached your plan\'s boat limit.';

  @override
  String get paywallReasonBoatLimit =>
      'Your Free plan allows 1 boat. Go Pro to manage up to 3.';

  @override
  String get joinBoat => 'Join a boat';

  @override
  String get joinedBoat => 'You\'ve joined the boat';

  @override
  String get invalidCodeOrJoinError => 'Invalid code or error joining';

  @override
  String get maintenanceAndExpenses => 'Maintenance & expenses';

  @override
  String get maintenanceAndExpensesSubtitle => 'Boat services and costs';

  @override
  String get shareBoat => 'Share boat';

  @override
  String get shareBoatSubtitle => 'Crew and co-owners';

  @override
  String get leaveSharedBoat => 'Leave shared boat';

  @override
  String get leaveSharedBoatSubtitle => 'Stop having access';

  @override
  String get couldNotGetCode => 'Could not get the code';

  @override
  String get shareBoatExplainer =>
      'Share this code. Whoever enters it will see the boat. Turn on \"can record trips\" below to grant editor permission.';

  @override
  String shareBoatMessage(String name, String code) {
    return 'Join my boat \"$name\" on Navis with the code: $code';
  }

  @override
  String get withAccess => 'With access';

  @override
  String get notSharedYet => 'You haven\'t shared with anyone yet.';

  @override
  String get leaveBoat => 'Leave boat';

  @override
  String leaveBoatConfirm(String name) {
    return 'You will lose access to \"$name\".';
  }

  @override
  String get removeAccess => 'Remove access';

  @override
  String get groupsTitle => 'Groups';

  @override
  String get publicLabel => 'Public';

  @override
  String get privateLabel => 'Private';

  @override
  String membersCount(int count) {
    return '$count members';
  }

  @override
  String get deleteGroup => 'Delete group';

  @override
  String get deleteGroupConfirm =>
      'Are you sure you want to delete this group? This cannot be undone.';

  @override
  String get leaveGroup => 'Leave group';

  @override
  String get leaveGroupConfirm => 'Do you want to leave this group?';

  @override
  String get groupDeleted => 'Group deleted';

  @override
  String get leftGroup => 'You\'ve left the group';

  @override
  String get couldNotLeave => 'Could not leave';

  @override
  String get admit => 'Admit';

  @override
  String get rejectAction => 'Reject';

  @override
  String get couldNotProcess => 'Could not process';

  @override
  String get noScheduledRegattas => 'No regattas scheduled.';

  @override
  String get expelMember => 'Remove';

  @override
  String get memberExpelled => 'Member removed';

  @override
  String get couldNotExpel => 'Could not remove';

  @override
  String get youLabel => 'You';

  @override
  String userLabel(String id) {
    return 'User $id';
  }

  @override
  String get scheduleAction => 'Schedule';

  @override
  String get groupCreated => 'Group created';

  @override
  String get couldNotCreateGroup => 'Could not create the group';

  @override
  String get createGroup => 'Create group';

  @override
  String get groupName => 'Group name';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get groupPublicSubtitle => 'Anyone can request to join (you approve).';

  @override
  String get groupPrivateSubtitle => 'Members join with an invite code only.';

  @override
  String get paywallReasonGroups =>
      'Creating clubs and events is a Navis Pro feature.';

  @override
  String get joinByCode => 'Join by code';

  @override
  String joinedGroup(String name) {
    return 'You\'ve joined $name';
  }

  @override
  String get requestSent => 'Request sent';

  @override
  String get couldNotRequest => 'Could not send request';

  @override
  String get requestAction => 'Request';

  @override
  String get notInAnyGroup => 'You\'re not in any group yet.';

  @override
  String get noPublicGroups => 'No public groups to discover.';

  @override
  String get cancelTrip => 'Cancel trip';

  @override
  String get cancelTripRegattaWarning =>
      'The regatta will return to \"scheduled\" and the recording will be discarded.';

  @override
  String get cancelTripWarning => 'This trip will be discarded without saving.';

  @override
  String get exitWithoutSaving => 'Exit without saving';

  @override
  String get exitRegattaWarning =>
      'The recording will be discarded and the regatta will return to \"scheduled\".';

  @override
  String get exitTripWarning =>
      'You will leave the map and the recording will be discarded without saving the trip.';

  @override
  String get keepGoing => 'Keep going';

  @override
  String get noMaintenanceRecords => 'No maintenance records';

  @override
  String get invoiceLabel => 'Invoice';

  @override
  String get maintenanceTypeHint => 'Type (e.g. oil change)';

  @override
  String get costOptional => 'Cost € (opt.)';

  @override
  String get providerOptional => 'Provider (opt.)';

  @override
  String dateWithValue(String date) {
    return 'Date: $date';
  }

  @override
  String get totalSpent => 'Total spent';

  @override
  String get noExpensesRecorded => 'No expenses recorded';

  @override
  String get categoryLabel => 'Category';

  @override
  String get amountEur => 'Amount €';

  @override
  String get couldNotUploadInvoice => 'Could not upload the invoice';

  @override
  String get attachInvoice => 'Attach invoice';

  @override
  String get expenseCategoryFuel => 'Fuel';

  @override
  String get expenseCategoryMooring => 'Mooring';

  @override
  String get expenseCategoryInsurance => 'Insurance';

  @override
  String get expenseCategoryRepair => 'Repair';

  @override
  String get expenseCategoryCleaning => 'Cleaning';

  @override
  String get expenseCategoryOther => 'Other';

  @override
  String get safetyChecklist => 'Safety checklist';

  @override
  String get addItem => 'Add item';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get couldNotAdd => 'Could not add';

  @override
  String get couldNotUpdate => 'Could not update';

  @override
  String get couldNotStart => 'Could not start';

  @override
  String get checklistSkipHint =>
      'We recommend checking every safety item, but you may set sail anyway at your own responsibility.';

  @override
  String get checklistLifejackets => 'Lifejackets for the whole crew';

  @override
  String get checklistFlares => 'Flares and pyrotechnic signals in date';

  @override
  String get checklistVhf => 'VHF radio working';

  @override
  String get checklistFuel => 'Sufficient fuel level';

  @override
  String get checklistBilgePump => 'Bilge pump working';

  @override
  String get checklistFirstAid => 'First aid kit';

  @override
  String get checklistAnchor => 'Anchor and lines in good condition';

  @override
  String get checklistNavLights => 'Navigation lights working';

  @override
  String get checklistWeather => 'Weather forecast checked';

  @override
  String get checklistFloatPlan => 'Passage plan shared ashore';

  @override
  String get areYouGoing => 'Are you going?';

  @override
  String get prepareChecklistAndSail => 'Prepare checklist and set sail';

  @override
  String get cancelRegatta => 'Cancel regatta';

  @override
  String get regattaInProgress => 'The regatta is under way (recording).';

  @override
  String get deleteRegatta => 'Delete regatta';

  @override
  String get deleteRegattaConfirm =>
      'This regatta will be permanently deleted.';

  @override
  String get regattaDeleted => 'Regatta deleted';

  @override
  String get regattaCancelled => 'Regatta cancelled';

  @override
  String get couldNotCancel => 'Could not cancel';

  @override
  String get couldNotRespond => 'Could not respond';

  @override
  String get rsvpGoing => 'Going';

  @override
  String get rsvpMaybe => 'Maybe';

  @override
  String get rsvpNotGoing => 'Not going';

  @override
  String get rsvpGoingCount => 'Going';

  @override
  String get rsvpNotGoingCount => 'Not going';

  @override
  String get selectABoat => 'Select a boat';

  @override
  String get selectDeparturePortFirst => 'Select the departure port';

  @override
  String get regattaScheduled => 'Regatta scheduled';

  @override
  String get couldNotSchedule => 'Could not schedule';

  @override
  String get scheduleRegatta => 'Schedule regatta';

  @override
  String get regattaTitleHint => 'Title (e.g. Spring regatta)';

  @override
  String get selectBoatFirst => 'Select a boat first.';

  @override
  String get addBoatFirst => 'Add a boat first.';

  @override
  String get addCrewMemberHint => 'Add crew member…';

  @override
  String get checkEmailTitle => 'Check your email';

  @override
  String checkEmailBody(String email) {
    return 'We\'ve sent a confirmation link to $email. Open it to activate your account, then log in.';
  }

  @override
  String get resendEmail => 'Resend email';

  @override
  String get emailResent => 'Email sent';

  @override
  String get couldNotResend => 'Could not resend the email';

  @override
  String get backToLogin => 'Back to login';

  @override
  String get orDivider => 'or';

  @override
  String get completeAndSail => 'Complete and set sail';

  @override
  String get sailAnyway => 'Set sail anyway';

  @override
  String get statusScheduled => 'Scheduled';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get regattaLabel => 'Regatta';

  @override
  String get memberLabel => 'Member';

  @override
  String get joinAsGroup => 'Join as a group';

  @override
  String get selectAGroup => 'Select a group';

  @override
  String get joinedWithGroup => 'You\'ve joined with your group';

  @override
  String get couldNotJoin => 'Could not join';

  @override
  String get groupLabel => 'Group';

  @override
  String get createGroupFirst => 'Create a group first to join with your team.';

  @override
  String get joinWithMyGroup => 'Join with my group';

  @override
  String get sharedWithMe => 'Shared with me';

  @override
  String get sharedBoatInfo =>
      'This boat is shared with you. You have the permissions its owner granted.';

  @override
  String permissionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count permissions',
      one: '1 permission',
    );
    return '$_temp0';
  }

  @override
  String get permRecordTrips => 'Record trips';

  @override
  String get permManageExpenses => 'Manage expenses';

  @override
  String get permManageMaintenance => 'Manage maintenance';

  @override
  String get permViewDocuments => 'View documents';

  @override
  String get permManageDocuments => 'Manage documents';

  @override
  String get maintenanceTab => 'Maintenance';

  @override
  String get expensesTab => 'Expenses';

  @override
  String get newMaintenance => 'New maintenance';

  @override
  String get newExpense => 'New expense';

  @override
  String get editExpense => 'Edit expense';

  @override
  String get invoiceAttached => 'Invoice attached';

  @override
  String get regattasAndOutings => 'Regattas & outings';

  @override
  String requestsCount(int count) {
    return 'Requests ($count)';
  }

  @override
  String get requestAdmitted => 'Request admitted';

  @override
  String get requestRejected => 'Request rejected';

  @override
  String get roleOwner => 'Owner';

  @override
  String get visibilityLabel => 'Visibility';

  @override
  String get myGroupsTab => 'My groups';

  @override
  String get discoverTab => 'Discover';

  @override
  String get pendingLabel => 'Pending';

  @override
  String pendingCountShort(int count) {
    return '$count pending';
  }

  @override
  String get followLive => 'Watch live';

  @override
  String get couldNotOpenLive => 'Could not open the live stream';

  @override
  String get backgroundLocationAdvice =>
      'To keep recording with the screen off, allow “Always” location access for Navis in Settings.';

  @override
  String get resumeRecordingTitle => 'Recording in progress';

  @override
  String get resumeRecordingBody =>
      'A trip recording was interrupted. Do you want to resume it?';

  @override
  String get resumeAction => 'Resume';

  @override
  String get discardRecording => 'Discard';

  @override
  String get noBoatsValueProp =>
      'Add your boat to track document expiry, get reminders before fines, and keep your maintenance log in one place.';

  @override
  String get home => 'Home';

  @override
  String get community => 'Community';

  @override
  String get communityRegattas => 'Regattas';

  @override
  String get communityClubs => 'Clubs';

  @override
  String get sailConditionsGood => 'Good conditions to sail';

  @override
  String get sailConditionsModerate => 'Moderate conditions';

  @override
  String get sailConditionsAdverse => 'Adverse conditions';

  @override
  String windWavesSummary(String wind, String wave) {
    return 'Wind $wind kt · Waves $wave m';
  }

  @override
  String get tides => 'Tides';

  @override
  String tideRange(String range) {
    return 'Range $range m';
  }

  @override
  String get tideHigh => 'High tide';

  @override
  String get tideLow => 'Low tide';
}
