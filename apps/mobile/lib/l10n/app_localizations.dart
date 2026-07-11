import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Navis'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccount;

  /// No description provided for @hasAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get hasAccount;

  /// No description provided for @boats.
  ///
  /// In en, this message translates to:
  /// **'Boats'**
  String get boats;

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @trips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get trips;

  /// No description provided for @weather.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get weather;

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events;

  /// No description provided for @charts.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get charts;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @noBoats.
  ///
  /// In en, this message translates to:
  /// **'No boats yet. Add your first boat!'**
  String get noBoats;

  /// No description provided for @noDocuments.
  ///
  /// In en, this message translates to:
  /// **'No documents yet. Add your first document!'**
  String get noDocuments;

  /// No description provided for @noTrips.
  ///
  /// In en, this message translates to:
  /// **'No trips recorded yet. Start your first trip!'**
  String get noTrips;

  /// No description provided for @noEvents.
  ///
  /// In en, this message translates to:
  /// **'No upcoming events.'**
  String get noEvents;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @critical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get critical;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @valid.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get valid;

  /// No description provided for @daysRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} days remaining'**
  String daysRemaining(int count);

  /// No description provided for @daysOverdue.
  ///
  /// In en, this message translates to:
  /// **'{count} days overdue'**
  String daysOverdue(int count);

  /// No description provided for @nauticalMiles.
  ///
  /// In en, this message translates to:
  /// **'NM'**
  String get nauticalMiles;

  /// No description provided for @knots.
  ///
  /// In en, this message translates to:
  /// **'kt'**
  String get knots;

  /// No description provided for @kilometers.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get kilometers;

  /// No description provided for @meters.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get meters;

  /// No description provided for @boatName.
  ///
  /// In en, this message translates to:
  /// **'Boat Name'**
  String get boatName;

  /// No description provided for @registration.
  ///
  /// In en, this message translates to:
  /// **'Registration Number'**
  String get registration;

  /// No description provided for @boatType.
  ///
  /// In en, this message translates to:
  /// **'Boat Type'**
  String get boatType;

  /// No description provided for @length.
  ///
  /// In en, this message translates to:
  /// **'Length (m)'**
  String get length;

  /// No description provided for @homePort.
  ///
  /// In en, this message translates to:
  /// **'Home Port'**
  String get homePort;

  /// No description provided for @sailboat.
  ///
  /// In en, this message translates to:
  /// **'Sailboat'**
  String get sailboat;

  /// No description provided for @motorboat.
  ///
  /// In en, this message translates to:
  /// **'Motorboat'**
  String get motorboat;

  /// No description provided for @catamaran.
  ///
  /// In en, this message translates to:
  /// **'Catamaran'**
  String get catamaran;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @documentType.
  ///
  /// In en, this message translates to:
  /// **'Document Type'**
  String get documentType;

  /// No description provided for @expiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get expiryDate;

  /// No description provided for @alertDays.
  ///
  /// In en, this message translates to:
  /// **'Alert Days Before Expiry'**
  String get alertDays;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get addPhoto;

  /// No description provided for @departure.
  ///
  /// In en, this message translates to:
  /// **'Departure'**
  String get departure;

  /// No description provided for @arrival.
  ///
  /// In en, this message translates to:
  /// **'Arrival'**
  String get arrival;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @maxSpeed.
  ///
  /// In en, this message translates to:
  /// **'Max Speed'**
  String get maxSpeed;

  /// No description provided for @avgSpeed.
  ///
  /// In en, this message translates to:
  /// **'Avg Speed'**
  String get avgSpeed;

  /// No description provided for @startTrip.
  ///
  /// In en, this message translates to:
  /// **'Start Trip'**
  String get startTrip;

  /// No description provided for @stopTrip.
  ///
  /// In en, this message translates to:
  /// **'Stop Trip'**
  String get stopTrip;

  /// No description provided for @pauseTrip.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseTrip;

  /// No description provided for @resumeTrip.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeTrip;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get recording;

  /// No description provided for @totalTrips.
  ///
  /// In en, this message translates to:
  /// **'Total Trips'**
  String get totalTrips;

  /// No description provided for @tripStatistics.
  ///
  /// In en, this message translates to:
  /// **'Trip Statistics'**
  String get tripStatistics;

  /// No description provided for @totalDistanceNm.
  ///
  /// In en, this message translates to:
  /// **'NM sailed'**
  String get totalDistanceNm;

  /// No description provided for @totalHoursAtSea.
  ///
  /// In en, this message translates to:
  /// **'Hours at sea'**
  String get totalHoursAtSea;

  /// No description provided for @portsVisited.
  ///
  /// In en, this message translates to:
  /// **'Ports visited'**
  String get portsVisited;

  /// No description provided for @topSpeed.
  ///
  /// In en, this message translates to:
  /// **'Top speed'**
  String get topSpeed;

  /// No description provided for @fuelConsumed.
  ///
  /// In en, this message translates to:
  /// **'Fuel consumed'**
  String get fuelConsumed;

  /// No description provided for @engineHoursTotal.
  ///
  /// In en, this message translates to:
  /// **'Engine hours'**
  String get engineHoursTotal;

  /// No description provided for @yearInReview.
  ///
  /// In en, this message translates to:
  /// **'Year in Review'**
  String get yearInReview;

  /// No description provided for @monthlyActivity.
  ///
  /// In en, this message translates to:
  /// **'Monthly Activity'**
  String get monthlyActivity;

  /// No description provided for @tripsLabel.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get tripsLabel;

  /// No description provided for @distanceNmLabel.
  ///
  /// In en, this message translates to:
  /// **'NM'**
  String get distanceNmLabel;

  /// No description provided for @hoursLabel.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hoursLabel;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// No description provided for @totalDistance.
  ///
  /// In en, this message translates to:
  /// **'Total Distance'**
  String get totalDistance;

  /// No description provided for @totalHours.
  ///
  /// In en, this message translates to:
  /// **'Total Hours'**
  String get totalHours;

  /// No description provided for @temperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperature;

  /// No description provided for @windSpeed.
  ///
  /// In en, this message translates to:
  /// **'Wind Speed'**
  String get windSpeed;

  /// No description provided for @windDirection.
  ///
  /// In en, this message translates to:
  /// **'Wind Direction'**
  String get windDirection;

  /// No description provided for @waveHeight.
  ///
  /// In en, this message translates to:
  /// **'Wave Height'**
  String get waveHeight;

  /// No description provided for @forecast.
  ///
  /// In en, this message translates to:
  /// **'Forecast'**
  String get forecast;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @eventDate.
  ///
  /// In en, this message translates to:
  /// **'Event Date'**
  String get eventDate;

  /// No description provided for @eventLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get eventLocation;

  /// No description provided for @registerForEvent.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerForEvent;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logoutConfirm;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this?'**
  String get deleteConfirm;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get requiredField;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get invalidEmail;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @engineHours.
  ///
  /// In en, this message translates to:
  /// **'Engine Hours'**
  String get engineHours;

  /// No description provided for @fuelUsed.
  ///
  /// In en, this message translates to:
  /// **'Fuel Used'**
  String get fuelUsed;

  /// No description provided for @crew.
  ///
  /// In en, this message translates to:
  /// **'Crew'**
  String get crew;

  /// No description provided for @logbook.
  ///
  /// In en, this message translates to:
  /// **'Logbook'**
  String get logbook;

  /// No description provided for @tripDetails.
  ///
  /// In en, this message translates to:
  /// **'Trip Details'**
  String get tripDetails;

  /// No description provided for @editBoat.
  ///
  /// In en, this message translates to:
  /// **'Edit Boat'**
  String get editBoat;

  /// No description provided for @myBoats.
  ///
  /// In en, this message translates to:
  /// **'My Boats'**
  String get myBoats;

  /// No description provided for @addBoat.
  ///
  /// In en, this message translates to:
  /// **'Add Boat'**
  String get addBoat;

  /// No description provided for @newDocument.
  ///
  /// In en, this message translates to:
  /// **'New Document'**
  String get newDocument;

  /// No description provided for @editDocument.
  ///
  /// In en, this message translates to:
  /// **'Edit Document'**
  String get editDocument;

  /// No description provided for @renewDocument.
  ///
  /// In en, this message translates to:
  /// **'Renew Document'**
  String get renewDocument;

  /// No description provided for @documentDetails.
  ///
  /// In en, this message translates to:
  /// **'Document Details'**
  String get documentDetails;

  /// No description provided for @renewalCost.
  ///
  /// In en, this message translates to:
  /// **'Renewal Cost'**
  String get renewalCost;

  /// No description provided for @renewalProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider / Company'**
  String get renewalProvider;

  /// No description provided for @lastRenewal.
  ///
  /// In en, this message translates to:
  /// **'Last Renewal'**
  String get lastRenewal;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @cost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get cost;

  /// No description provided for @provider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get provider;

  /// No description provided for @deleteDocument.
  ///
  /// In en, this message translates to:
  /// **'Delete Document'**
  String get deleteDocument;

  /// No description provided for @deleteDocumentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this document?'**
  String get deleteDocumentConfirm;

  /// No description provided for @documentDeleted.
  ///
  /// In en, this message translates to:
  /// **'Document deleted'**
  String get documentDeleted;

  /// No description provided for @documentSaved.
  ///
  /// In en, this message translates to:
  /// **'Document saved'**
  String get documentSaved;

  /// No description provided for @documentUpdated.
  ///
  /// In en, this message translates to:
  /// **'Document updated'**
  String get documentUpdated;

  /// No description provided for @documentRenewed.
  ///
  /// In en, this message translates to:
  /// **'Document renewed'**
  String get documentRenewed;

  /// No description provided for @failedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save document'**
  String get failedToSave;

  /// No description provided for @failedToDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete'**
  String get failedToDelete;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// No description provided for @addScan.
  ///
  /// In en, this message translates to:
  /// **'Add Scan'**
  String get addScan;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @alertDaysBeforeExpiry.
  ///
  /// In en, this message translates to:
  /// **'Alert Days Before Expiry'**
  String get alertDaysBeforeExpiry;

  /// No description provided for @validNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get validNumber;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploading;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternetConnection;

  /// No description provided for @offlineWithPending.
  ///
  /// In en, this message translates to:
  /// **'Offline • {count} pending'**
  String offlineWithPending(int count);

  /// No description provided for @syncingChanges.
  ///
  /// In en, this message translates to:
  /// **'Syncing {count} changes…'**
  String syncingChanges(int count);

  /// No description provided for @searchEvents.
  ///
  /// In en, this message translates to:
  /// **'Search events...'**
  String get searchEvents;

  /// No description provided for @noEventsFound.
  ///
  /// In en, this message translates to:
  /// **'No events found'**
  String get noEventsFound;

  /// No description provided for @featured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get featured;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @darkThemeActive.
  ///
  /// In en, this message translates to:
  /// **'Dark theme active'**
  String get darkThemeActive;

  /// No description provided for @lightThemeActive.
  ///
  /// In en, this message translates to:
  /// **'Light theme active'**
  String get lightThemeActive;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @documentExpiryAlerts.
  ///
  /// In en, this message translates to:
  /// **'Document Expiry Alerts'**
  String get documentExpiryAlerts;

  /// No description provided for @expiryAlertsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get notified before documents expire'**
  String get expiryAlertsSubtitle;

  /// No description provided for @eventReminders.
  ///
  /// In en, this message translates to:
  /// **'Event Reminders'**
  String get eventReminders;

  /// No description provided for @eventRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get reminded about upcoming events'**
  String get eventRemindersSubtitle;

  /// No description provided for @dataAndStorage.
  ///
  /// In en, this message translates to:
  /// **'Data & Storage'**
  String get dataAndStorage;

  /// No description provided for @clearImageCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Image Cache'**
  String get clearImageCache;

  /// No description provided for @clearImageCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove cached photos and map tiles'**
  String get clearImageCacheSubtitle;

  /// No description provided for @clearOfflineData.
  ///
  /// In en, this message translates to:
  /// **'Clear Offline Data'**
  String get clearOfflineData;

  /// No description provided for @clearOfflineDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove cached boats, documents, trips'**
  String get clearOfflineDataSubtitle;

  /// No description provided for @imageCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Image cache cleared'**
  String get imageCacheCleared;

  /// No description provided for @offlineDataCleared.
  ///
  /// In en, this message translates to:
  /// **'Offline data cleared'**
  String get offlineDataCleared;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account and all your data'**
  String get deleteAccountSubtitle;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account: boats, documents, trips, maintenance history, groups you own and all uploaded files. This cannot be undone.'**
  String get deleteAccountWarning;

  /// No description provided for @deleteAccountTypeToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type {word} to confirm'**
  String deleteAccountTypeToConfirm(String word);

  /// No description provided for @deleteAccountConfirmWord.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteAccountConfirmWord;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the account. Try again.'**
  String get deleteAccountFailed;

  /// No description provided for @deleteBoat.
  ///
  /// In en, this message translates to:
  /// **'Delete Boat'**
  String get deleteBoat;

  /// No description provided for @deleteBoatConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This will also remove all associated documents and trips.'**
  String deleteBoatConfirm(String name);

  /// No description provided for @certificates.
  ///
  /// In en, this message translates to:
  /// **'Certificates, insurance, inspections'**
  String get certificates;

  /// No description provided for @tripHistory.
  ///
  /// In en, this message translates to:
  /// **'Trip history and statistics'**
  String get tripHistory;

  /// No description provided for @modifyBoatDetails.
  ///
  /// In en, this message translates to:
  /// **'Modify boat details'**
  String get modifyBoatDetails;

  /// No description provided for @removePermanently.
  ///
  /// In en, this message translates to:
  /// **'Remove this boat permanently'**
  String get removePermanently;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @recordTrip.
  ///
  /// In en, this message translates to:
  /// **'Record Trip'**
  String get recordTrip;

  /// No description provided for @boat.
  ///
  /// In en, this message translates to:
  /// **'Boat'**
  String get boat;

  /// No description provided for @boatPhoto.
  ///
  /// In en, this message translates to:
  /// **'Boat photo'**
  String get boatPhoto;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get goBack;

  /// No description provided for @addNewBoat.
  ///
  /// In en, this message translates to:
  /// **'Add new boat'**
  String get addNewBoat;

  /// No description provided for @homePortOptional.
  ///
  /// In en, this message translates to:
  /// **'Home Port (optional)'**
  String get homePortOptional;

  /// No description provided for @wind.
  ///
  /// In en, this message translates to:
  /// **'Wind'**
  String get wind;

  /// No description provided for @waves.
  ///
  /// In en, this message translates to:
  /// **'Waves'**
  String get waves;

  /// No description provided for @humidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get humidity;

  /// No description provided for @currentConditions.
  ///
  /// In en, this message translates to:
  /// **'Current Conditions'**
  String get currentConditions;

  /// No description provided for @calm.
  ///
  /// In en, this message translates to:
  /// **'Calm'**
  String get calm;

  /// No description provided for @moderate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get moderate;

  /// No description provided for @rough.
  ///
  /// In en, this message translates to:
  /// **'Rough'**
  String get rough;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// No description provided for @passwordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent. Check your inbox.'**
  String get passwordResetSent;

  /// No description provided for @failedToSendResetEmail.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset email'**
  String get failedToSendResetEmail;

  /// No description provided for @tripSaved.
  ///
  /// In en, this message translates to:
  /// **'Trip saved!'**
  String get tripSaved;

  /// No description provided for @failedToSaveTrip.
  ///
  /// In en, this message translates to:
  /// **'Failed to save trip'**
  String get failedToSaveTrip;

  /// No description provided for @tripDeleted.
  ///
  /// In en, this message translates to:
  /// **'Trip deleted'**
  String get tripDeleted;

  /// No description provided for @selectArrivalPort.
  ///
  /// In en, this message translates to:
  /// **'Select Arrival Port'**
  String get selectArrivalPort;

  /// No description provided for @commaSeparatedNames.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated names'**
  String get commaSeparatedNames;

  /// No description provided for @crewMembers.
  ///
  /// In en, this message translates to:
  /// **'Crew Members'**
  String get crewMembers;

  /// No description provided for @updateTrip.
  ///
  /// In en, this message translates to:
  /// **'Update Trip'**
  String get updateTrip;

  /// No description provided for @saveTrip.
  ///
  /// In en, this message translates to:
  /// **'Save Trip'**
  String get saveTrip;

  /// No description provided for @notLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get notLoggedIn;

  /// No description provided for @helpAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpAndSupport;

  /// No description provided for @aboutNavis.
  ///
  /// In en, this message translates to:
  /// **'About Navis'**
  String get aboutNavis;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @paywallAutoRenewNotice.
  ///
  /// In en, this message translates to:
  /// **'The subscription renews automatically unless you cancel it in your App Store account settings at least 24 hours before the end of the current period.'**
  String get paywallAutoRenewNotice;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Your boat\'s digital logbook: documents, trips, maintenance and weather in one place.'**
  String get aboutDescription;

  /// No description provided for @couldNotOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link'**
  String get couldNotOpenLink;

  /// No description provided for @speedAbbr.
  ///
  /// In en, this message translates to:
  /// **'SPD'**
  String get speedAbbr;

  /// No description provided for @headingAbbr.
  ///
  /// In en, this message translates to:
  /// **'HDG'**
  String get headingAbbr;

  /// No description provided for @distanceAbbr.
  ///
  /// In en, this message translates to:
  /// **'DIST'**
  String get distanceAbbr;

  /// No description provided for @timeAbbr.
  ///
  /// In en, this message translates to:
  /// **'TIME'**
  String get timeAbbr;

  /// No description provided for @alert.
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get alert;

  /// No description provided for @daysBeforeExpiry.
  ///
  /// In en, this message translates to:
  /// **'days before expiry'**
  String get daysBeforeExpiry;

  /// No description provided for @selectLocation.
  ///
  /// In en, this message translates to:
  /// **'Select Location'**
  String get selectLocation;

  /// No description provided for @totalEngineHours.
  ///
  /// In en, this message translates to:
  /// **'Total engine hours'**
  String get totalEngineHours;

  /// No description provided for @averageSpeed.
  ///
  /// In en, this message translates to:
  /// **'Average speed'**
  String get averageSpeed;

  /// No description provided for @thisYear.
  ///
  /// In en, this message translates to:
  /// **'This Year ({year})'**
  String thisYear(String year);

  /// No description provided for @locationAccessNeeded.
  ///
  /// In en, this message translates to:
  /// **'Location access is needed\nfor weather data.'**
  String get locationAccessNeeded;

  /// No description provided for @sevenDayForecast.
  ///
  /// In en, this message translates to:
  /// **'7-Day Forecast'**
  String get sevenDayForecast;

  /// No description provided for @forecastNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Forecast data not available.'**
  String get forecastNotAvailable;

  /// No description provided for @memberSince.
  ///
  /// In en, this message translates to:
  /// **'Member since {date}'**
  String memberSince(String date);

  /// No description provided for @deleteTrip.
  ///
  /// In en, this message translates to:
  /// **'Delete Trip'**
  String get deleteTrip;

  /// No description provided for @deleteTripConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this trip?'**
  String get deleteTripConfirm;

  /// No description provided for @shareTrip.
  ///
  /// In en, this message translates to:
  /// **'Share trip'**
  String get shareTrip;

  /// No description provided for @editTrip.
  ///
  /// In en, this message translates to:
  /// **'Edit trip'**
  String get editTrip;

  /// No description provided for @notRecorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get notRecorded;

  /// No description provided for @enterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get enterValidNumber;

  /// No description provided for @completeTrip.
  ///
  /// In en, this message translates to:
  /// **'Complete Trip'**
  String get completeTrip;

  /// No description provided for @arrivalPort.
  ///
  /// In en, this message translates to:
  /// **'Arrival Port'**
  String get arrivalPort;

  /// No description provided for @savingTrip.
  ///
  /// In en, this message translates to:
  /// **'Saving trip...'**
  String get savingTrip;

  /// No description provided for @fuelUnit.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get fuelUnit;

  /// No description provided for @locationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to record trips'**
  String get locationPermissionRequired;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission permanently denied. Enable in settings.'**
  String get locationPermissionDenied;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// No description provided for @boatManagement.
  ///
  /// In en, this message translates to:
  /// **'BOAT MANAGEMENT'**
  String get boatManagement;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @pleaseEnterBoatName.
  ///
  /// In en, this message translates to:
  /// **'Please enter the boat name'**
  String get pleaseEnterBoatName;

  /// No description provided for @pleaseEnterRegistration.
  ///
  /// In en, this message translates to:
  /// **'Please enter the registration number'**
  String get pleaseEnterRegistration;

  /// No description provided for @pleaseEnterLength.
  ///
  /// In en, this message translates to:
  /// **'Please enter the length'**
  String get pleaseEnterLength;

  /// No description provided for @pleaseEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterEmail;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterPassword;

  /// No description provided for @boatUpdated.
  ///
  /// In en, this message translates to:
  /// **'Boat updated successfully'**
  String get boatUpdated;

  /// No description provided for @boatCreated.
  ///
  /// In en, this message translates to:
  /// **'Boat created successfully'**
  String get boatCreated;

  /// No description provided for @failedToSaveBoat.
  ///
  /// In en, this message translates to:
  /// **'Failed to save boat'**
  String get failedToSaveBoat;

  /// No description provided for @newBoat.
  ///
  /// In en, this message translates to:
  /// **'New Boat'**
  String get newBoat;

  /// No description provided for @boatDetailsSection.
  ///
  /// In en, this message translates to:
  /// **'Boat Details'**
  String get boatDetailsSection;

  /// No description provided for @pickLocationOnMap.
  ///
  /// In en, this message translates to:
  /// **'Pick location on map'**
  String get pickLocationOnMap;

  /// No description provided for @updateBoat.
  ///
  /// In en, this message translates to:
  /// **'Update Boat'**
  String get updateBoat;

  /// No description provided for @createBoat.
  ///
  /// In en, this message translates to:
  /// **'Create Boat'**
  String get createBoat;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @joinNavisSubtitle.
  ///
  /// In en, this message translates to:
  /// **'JOIN NAVIS AND MANAGE YOUR BOAT'**
  String get joinNavisSubtitle;

  /// No description provided for @pleaseConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get pleaseConfirmPassword;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @selectHomePort.
  ///
  /// In en, this message translates to:
  /// **'Select Home Port'**
  String get selectHomePort;

  /// No description provided for @documentInfo.
  ///
  /// In en, this message translates to:
  /// **'Document Info'**
  String get documentInfo;

  /// No description provided for @alertsAndNotes.
  ///
  /// In en, this message translates to:
  /// **'Alerts & Notes'**
  String get alertsAndNotes;

  /// No description provided for @renewalDetails.
  ///
  /// In en, this message translates to:
  /// **'Renewal Details'**
  String get renewalDetails;

  /// No description provided for @documentScan.
  ///
  /// In en, this message translates to:
  /// **'Document scan'**
  String get documentScan;

  /// No description provided for @saveDocument.
  ///
  /// In en, this message translates to:
  /// **'Save Document'**
  String get saveDocument;

  /// No description provided for @updateDocument.
  ///
  /// In en, this message translates to:
  /// **'Update Document'**
  String get updateDocument;

  /// No description provided for @interested.
  ///
  /// In en, this message translates to:
  /// **'Interested'**
  String get interested;

  /// No description provided for @notInterested.
  ///
  /// In en, this message translates to:
  /// **'Not Interested'**
  String get notInterested;

  /// No description provided for @eventDetails.
  ///
  /// In en, this message translates to:
  /// **'Event Details'**
  String get eventDetails;

  /// No description provided for @departurePort.
  ///
  /// In en, this message translates to:
  /// **'Departure Port'**
  String get departurePort;

  /// No description provided for @pleaseEnterDeparturePort.
  ///
  /// In en, this message translates to:
  /// **'Please enter the departure port'**
  String get pleaseEnterDeparturePort;

  /// No description provided for @arrivalPortOptional.
  ///
  /// In en, this message translates to:
  /// **'Arrival Port (optional)'**
  String get arrivalPortOptional;

  /// No description provided for @engineHoursOptional.
  ///
  /// In en, this message translates to:
  /// **'Engine Hours (optional)'**
  String get engineHoursOptional;

  /// No description provided for @fuelUsedOptional.
  ///
  /// In en, this message translates to:
  /// **'Fuel Used (liters, optional)'**
  String get fuelUsedOptional;

  /// No description provided for @crewMembersCommaSeparated.
  ///
  /// In en, this message translates to:
  /// **'Crew Members (comma-separated)'**
  String get crewMembersCommaSeparated;

  /// No description provided for @tripUpdated.
  ///
  /// In en, this message translates to:
  /// **'Trip updated'**
  String get tripUpdated;

  /// No description provided for @failedToUpdateTrip.
  ///
  /// In en, this message translates to:
  /// **'Failed to update trip'**
  String get failedToUpdateTrip;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @navisUser.
  ///
  /// In en, this message translates to:
  /// **'Navis User'**
  String get navisUser;

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @nearbyPorts.
  ///
  /// In en, this message translates to:
  /// **'Nearby Ports'**
  String get nearbyPorts;

  /// No description provided for @portTypeMarina.
  ///
  /// In en, this message translates to:
  /// **'Marina'**
  String get portTypeMarina;

  /// No description provided for @portTypeAnchorage.
  ///
  /// In en, this message translates to:
  /// **'Anchorage'**
  String get portTypeAnchorage;

  /// No description provided for @portTypeFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel Station'**
  String get portTypeFuel;

  /// No description provided for @portTypeCommercial.
  ///
  /// In en, this message translates to:
  /// **'Commercial'**
  String get portTypeCommercial;

  /// No description provided for @portTypeFishing.
  ///
  /// In en, this message translates to:
  /// **'Fishing Port'**
  String get portTypeFishing;

  /// No description provided for @portTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get portTypeOther;

  /// No description provided for @depthLabel.
  ///
  /// In en, this message translates to:
  /// **'Depth: {depth}m'**
  String depthLabel(Object depth);

  /// No description provided for @vhfChannelLabel.
  ///
  /// In en, this message translates to:
  /// **'VHF Ch {channel}'**
  String vhfChannelLabel(Object channel);

  /// No description provided for @portFacilities.
  ///
  /// In en, this message translates to:
  /// **'Facilities'**
  String get portFacilities;

  /// No description provided for @noNearbyPorts.
  ///
  /// In en, this message translates to:
  /// **'No ports found nearby'**
  String get noNearbyPorts;

  /// No description provided for @tapPortForDetails.
  ///
  /// In en, this message translates to:
  /// **'Tap a port marker for details'**
  String get tapPortForDetails;

  /// No description provided for @docTypeRegistration.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get docTypeRegistration;

  /// No description provided for @docTypeInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get docTypeInsurance;

  /// No description provided for @docTypeInspection.
  ///
  /// In en, this message translates to:
  /// **'Inspection'**
  String get docTypeInspection;

  /// No description provided for @docTypeLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get docTypeLicense;

  /// No description provided for @docTypeSafetyCertificate.
  ///
  /// In en, this message translates to:
  /// **'Safety Certificate'**
  String get docTypeSafetyCertificate;

  /// No description provided for @docTypeRadioLicense.
  ///
  /// In en, this message translates to:
  /// **'Radio License'**
  String get docTypeRadioLicense;

  /// No description provided for @docTypePollutionCertificate.
  ///
  /// In en, this message translates to:
  /// **'Pollution Certificate'**
  String get docTypePollutionCertificate;

  /// No description provided for @docTypeMedicalCertificate.
  ///
  /// In en, this message translates to:
  /// **'Medical Certificate'**
  String get docTypeMedicalCertificate;

  /// No description provided for @docTypeLifeRaft.
  ///
  /// In en, this message translates to:
  /// **'Life Raft'**
  String get docTypeLifeRaft;

  /// No description provided for @docTypeFireExtinguisher.
  ///
  /// In en, this message translates to:
  /// **'Fire Extinguisher'**
  String get docTypeFireExtinguisher;

  /// No description provided for @docTypeFlares.
  ///
  /// In en, this message translates to:
  /// **'Flares'**
  String get docTypeFlares;

  /// No description provided for @docTypeFirstAidKit.
  ///
  /// In en, this message translates to:
  /// **'First Aid Kit'**
  String get docTypeFirstAidKit;

  /// No description provided for @docTypeFishingPermit.
  ///
  /// In en, this message translates to:
  /// **'Fishing Permit'**
  String get docTypeFishingPermit;

  /// No description provided for @confirmLocation.
  ///
  /// In en, this message translates to:
  /// **'Confirm location'**
  String get confirmLocation;

  /// No description provided for @portNameHint.
  ///
  /// In en, this message translates to:
  /// **'Port name (e.g. Cala Blava)'**
  String get portNameHint;

  /// No description provided for @tapMapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to select a location'**
  String get tapMapToSelect;

  /// No description provided for @tapMapToSetHomePort.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to set your home port'**
  String get tapMapToSetHomePort;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @centerOnGps.
  ///
  /// In en, this message translates to:
  /// **'Center on GPS'**
  String get centerOnGps;

  /// No description provided for @toggleSeamarks.
  ///
  /// In en, this message translates to:
  /// **'Toggle sea marks'**
  String get toggleSeamarks;

  /// No description provided for @togglePorts.
  ///
  /// In en, this message translates to:
  /// **'Show ports'**
  String get togglePorts;

  /// No description provided for @toggleTripTracks.
  ///
  /// In en, this message translates to:
  /// **'Show trip tracks'**
  String get toggleTripTracks;

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// No description provided for @hourlyForecast.
  ///
  /// In en, this message translates to:
  /// **'Hourly Forecast'**
  String get hourlyForecast;

  /// No description provided for @wcClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get wcClear;

  /// No description provided for @wcPartlyCloudy.
  ///
  /// In en, this message translates to:
  /// **'Partly Cloudy'**
  String get wcPartlyCloudy;

  /// No description provided for @wcCloudy.
  ///
  /// In en, this message translates to:
  /// **'Cloudy'**
  String get wcCloudy;

  /// No description provided for @wcFog.
  ///
  /// In en, this message translates to:
  /// **'Fog'**
  String get wcFog;

  /// No description provided for @wcDrizzle.
  ///
  /// In en, this message translates to:
  /// **'Drizzle'**
  String get wcDrizzle;

  /// No description provided for @wcRain.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get wcRain;

  /// No description provided for @wcSnow.
  ///
  /// In en, this message translates to:
  /// **'Snow'**
  String get wcSnow;

  /// No description provided for @wcThunderstorm.
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm'**
  String get wcThunderstorm;

  /// No description provided for @wcUnknown.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get wcUnknown;

  /// No description provided for @inviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCode;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get codeCopied;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @couldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save'**
  String get couldNotSave;

  /// No description provided for @couldNotDelete.
  ///
  /// In en, this message translates to:
  /// **'Could not delete'**
  String get couldNotDelete;

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorWithMessage(String message);

  /// No description provided for @membersLabel.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get membersLabel;

  /// No description provided for @socialLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in with that provider'**
  String get socialLoginFailed;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @paywallDefaultReason.
  ///
  /// In en, this message translates to:
  /// **'Keep your boat legal, maintained and safe. For less than a single fine for expired paperwork.'**
  String get paywallDefaultReason;

  /// No description provided for @purchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not complete the purchase.'**
  String get purchaseFailed;

  /// No description provided for @nothingToRestore.
  ///
  /// In en, this message translates to:
  /// **'No purchases to restore.'**
  String get nothingToRestore;

  /// No description provided for @welcomeToPro.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Navis Pro!'**
  String get welcomeToPro;

  /// No description provided for @subscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get subscribe;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restorePurchases;

  /// No description provided for @subscriptionsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions are not available right now. Try again later.'**
  String get subscriptionsUnavailable;

  /// No description provided for @paywallMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get paywallMonthly;

  /// No description provided for @paywallYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get paywallYearly;

  /// No description provided for @paywallWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get paywallWeekly;

  /// No description provided for @paywallLifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get paywallLifetime;

  /// No description provided for @proBenefitReminders.
  ///
  /// In en, this message translates to:
  /// **'Unlimited document expiry reminders'**
  String get proBenefitReminders;

  /// No description provided for @proBenefitMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Scheduled maintenance reminders'**
  String get proBenefitMaintenance;

  /// No description provided for @proBenefitBoats.
  ///
  /// In en, this message translates to:
  /// **'Up to 3 boats'**
  String get proBenefitBoats;

  /// No description provided for @proBenefitGroups.
  ///
  /// In en, this message translates to:
  /// **'Create clubs and events'**
  String get proBenefitGroups;

  /// No description provided for @proBenefitAttachments.
  ///
  /// In en, this message translates to:
  /// **'Unlimited document attachments'**
  String get proBenefitAttachments;

  /// No description provided for @planBoatLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached your plan\'s boat limit.'**
  String get planBoatLimitReached;

  /// No description provided for @paywallReasonBoatLimit.
  ///
  /// In en, this message translates to:
  /// **'Your Free plan allows 1 boat. Go Pro to manage up to 3.'**
  String get paywallReasonBoatLimit;

  /// No description provided for @joinBoat.
  ///
  /// In en, this message translates to:
  /// **'Join a boat'**
  String get joinBoat;

  /// No description provided for @joinedBoat.
  ///
  /// In en, this message translates to:
  /// **'You\'ve joined the boat'**
  String get joinedBoat;

  /// No description provided for @invalidCodeOrJoinError.
  ///
  /// In en, this message translates to:
  /// **'Invalid code or error joining'**
  String get invalidCodeOrJoinError;

  /// No description provided for @maintenanceAndExpenses.
  ///
  /// In en, this message translates to:
  /// **'Maintenance & expenses'**
  String get maintenanceAndExpenses;

  /// No description provided for @maintenanceAndExpensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Boat services and costs'**
  String get maintenanceAndExpensesSubtitle;

  /// No description provided for @shareBoat.
  ///
  /// In en, this message translates to:
  /// **'Share boat'**
  String get shareBoat;

  /// No description provided for @shareBoatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Crew and co-owners'**
  String get shareBoatSubtitle;

  /// No description provided for @leaveSharedBoat.
  ///
  /// In en, this message translates to:
  /// **'Leave shared boat'**
  String get leaveSharedBoat;

  /// No description provided for @leaveSharedBoatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stop having access'**
  String get leaveSharedBoatSubtitle;

  /// No description provided for @couldNotGetCode.
  ///
  /// In en, this message translates to:
  /// **'Could not get the code'**
  String get couldNotGetCode;

  /// No description provided for @shareBoatExplainer.
  ///
  /// In en, this message translates to:
  /// **'Share this code. Whoever enters it will see the boat. Turn on \"can record trips\" below to grant editor permission.'**
  String get shareBoatExplainer;

  /// No description provided for @shareBoatMessage.
  ///
  /// In en, this message translates to:
  /// **'Join my boat \"{name}\" on Navis with the code: {code}'**
  String shareBoatMessage(String name, String code);

  /// No description provided for @withAccess.
  ///
  /// In en, this message translates to:
  /// **'With access'**
  String get withAccess;

  /// No description provided for @notSharedYet.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t shared with anyone yet.'**
  String get notSharedYet;

  /// No description provided for @leaveBoat.
  ///
  /// In en, this message translates to:
  /// **'Leave boat'**
  String get leaveBoat;

  /// No description provided for @leaveBoatConfirm.
  ///
  /// In en, this message translates to:
  /// **'You will lose access to \"{name}\".'**
  String leaveBoatConfirm(String name);

  /// No description provided for @removeAccess.
  ///
  /// In en, this message translates to:
  /// **'Remove access'**
  String get removeAccess;

  /// No description provided for @groupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groupsTitle;

  /// No description provided for @publicLabel.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get publicLabel;

  /// No description provided for @privateLabel.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get privateLabel;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String membersCount(int count);

  /// No description provided for @deleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get deleteGroup;

  /// No description provided for @deleteGroupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this group? This cannot be undone.'**
  String get deleteGroupConfirm;

  /// No description provided for @leaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get leaveGroup;

  /// No description provided for @leaveGroupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you want to leave this group?'**
  String get leaveGroupConfirm;

  /// No description provided for @groupDeleted.
  ///
  /// In en, this message translates to:
  /// **'Group deleted'**
  String get groupDeleted;

  /// No description provided for @leftGroup.
  ///
  /// In en, this message translates to:
  /// **'You\'ve left the group'**
  String get leftGroup;

  /// No description provided for @couldNotLeave.
  ///
  /// In en, this message translates to:
  /// **'Could not leave'**
  String get couldNotLeave;

  /// No description provided for @admit.
  ///
  /// In en, this message translates to:
  /// **'Admit'**
  String get admit;

  /// No description provided for @rejectAction.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectAction;

  /// No description provided for @couldNotProcess.
  ///
  /// In en, this message translates to:
  /// **'Could not process'**
  String get couldNotProcess;

  /// No description provided for @noScheduledRegattas.
  ///
  /// In en, this message translates to:
  /// **'No regattas scheduled.'**
  String get noScheduledRegattas;

  /// No description provided for @expelMember.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get expelMember;

  /// No description provided for @memberExpelled.
  ///
  /// In en, this message translates to:
  /// **'Member removed'**
  String get memberExpelled;

  /// No description provided for @couldNotExpel.
  ///
  /// In en, this message translates to:
  /// **'Could not remove'**
  String get couldNotExpel;

  /// No description provided for @youLabel.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get youLabel;

  /// No description provided for @userLabel.
  ///
  /// In en, this message translates to:
  /// **'User {id}'**
  String userLabel(String id);

  /// No description provided for @scheduleAction.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleAction;

  /// No description provided for @groupCreated.
  ///
  /// In en, this message translates to:
  /// **'Group created'**
  String get groupCreated;

  /// No description provided for @couldNotCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Could not create the group'**
  String get couldNotCreateGroup;

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get createGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptional;

  /// No description provided for @groupPublicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Anyone can request to join (you approve).'**
  String get groupPublicSubtitle;

  /// No description provided for @groupPrivateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Members join with an invite code only.'**
  String get groupPrivateSubtitle;

  /// No description provided for @paywallReasonGroups.
  ///
  /// In en, this message translates to:
  /// **'Creating clubs and events is a Navis Pro feature.'**
  String get paywallReasonGroups;

  /// No description provided for @joinByCode.
  ///
  /// In en, this message translates to:
  /// **'Join by code'**
  String get joinByCode;

  /// No description provided for @joinedGroup.
  ///
  /// In en, this message translates to:
  /// **'You\'ve joined {name}'**
  String joinedGroup(String name);

  /// No description provided for @requestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get requestSent;

  /// No description provided for @couldNotRequest.
  ///
  /// In en, this message translates to:
  /// **'Could not send request'**
  String get couldNotRequest;

  /// No description provided for @requestAction.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get requestAction;

  /// No description provided for @notInAnyGroup.
  ///
  /// In en, this message translates to:
  /// **'You\'re not in any group yet.'**
  String get notInAnyGroup;

  /// No description provided for @noPublicGroups.
  ///
  /// In en, this message translates to:
  /// **'No public groups to discover.'**
  String get noPublicGroups;

  /// No description provided for @cancelTrip.
  ///
  /// In en, this message translates to:
  /// **'Cancel trip'**
  String get cancelTrip;

  /// No description provided for @cancelTripRegattaWarning.
  ///
  /// In en, this message translates to:
  /// **'The regatta will return to \"scheduled\" and the recording will be discarded.'**
  String get cancelTripRegattaWarning;

  /// No description provided for @cancelTripWarning.
  ///
  /// In en, this message translates to:
  /// **'This trip will be discarded without saving.'**
  String get cancelTripWarning;

  /// No description provided for @exitWithoutSaving.
  ///
  /// In en, this message translates to:
  /// **'Exit without saving'**
  String get exitWithoutSaving;

  /// No description provided for @exitRegattaWarning.
  ///
  /// In en, this message translates to:
  /// **'The recording will be discarded and the regatta will return to \"scheduled\".'**
  String get exitRegattaWarning;

  /// No description provided for @exitTripWarning.
  ///
  /// In en, this message translates to:
  /// **'You will leave the map and the recording will be discarded without saving the trip.'**
  String get exitTripWarning;

  /// No description provided for @keepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get keepGoing;

  /// No description provided for @noMaintenanceRecords.
  ///
  /// In en, this message translates to:
  /// **'No maintenance records'**
  String get noMaintenanceRecords;

  /// No description provided for @invoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoiceLabel;

  /// No description provided for @maintenanceTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Type (e.g. oil change)'**
  String get maintenanceTypeHint;

  /// No description provided for @costOptional.
  ///
  /// In en, this message translates to:
  /// **'Cost € (opt.)'**
  String get costOptional;

  /// No description provided for @providerOptional.
  ///
  /// In en, this message translates to:
  /// **'Provider (opt.)'**
  String get providerOptional;

  /// No description provided for @dateWithValue.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String dateWithValue(String date);

  /// No description provided for @totalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total spent'**
  String get totalSpent;

  /// No description provided for @noExpensesRecorded.
  ///
  /// In en, this message translates to:
  /// **'No expenses recorded'**
  String get noExpensesRecorded;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @amountEur.
  ///
  /// In en, this message translates to:
  /// **'Amount €'**
  String get amountEur;

  /// No description provided for @couldNotUploadInvoice.
  ///
  /// In en, this message translates to:
  /// **'Could not upload the invoice'**
  String get couldNotUploadInvoice;

  /// No description provided for @attachInvoice.
  ///
  /// In en, this message translates to:
  /// **'Attach invoice'**
  String get attachInvoice;

  /// No description provided for @expenseCategoryFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get expenseCategoryFuel;

  /// No description provided for @expenseCategoryMooring.
  ///
  /// In en, this message translates to:
  /// **'Mooring'**
  String get expenseCategoryMooring;

  /// No description provided for @expenseCategoryInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get expenseCategoryInsurance;

  /// No description provided for @expenseCategoryRepair.
  ///
  /// In en, this message translates to:
  /// **'Repair'**
  String get expenseCategoryRepair;

  /// No description provided for @expenseCategoryCleaning.
  ///
  /// In en, this message translates to:
  /// **'Cleaning'**
  String get expenseCategoryCleaning;

  /// No description provided for @expenseCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get expenseCategoryOther;

  /// No description provided for @safetyChecklist.
  ///
  /// In en, this message translates to:
  /// **'Safety checklist'**
  String get safetyChecklist;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get addItem;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @couldNotAdd.
  ///
  /// In en, this message translates to:
  /// **'Could not add'**
  String get couldNotAdd;

  /// No description provided for @couldNotUpdate.
  ///
  /// In en, this message translates to:
  /// **'Could not update'**
  String get couldNotUpdate;

  /// No description provided for @couldNotStart.
  ///
  /// In en, this message translates to:
  /// **'Could not start'**
  String get couldNotStart;

  /// No description provided for @checklistSkipHint.
  ///
  /// In en, this message translates to:
  /// **'We recommend checking every safety item, but you may set sail anyway at your own responsibility.'**
  String get checklistSkipHint;

  /// No description provided for @checklistLifejackets.
  ///
  /// In en, this message translates to:
  /// **'Lifejackets for the whole crew'**
  String get checklistLifejackets;

  /// No description provided for @checklistFlares.
  ///
  /// In en, this message translates to:
  /// **'Flares and pyrotechnic signals in date'**
  String get checklistFlares;

  /// No description provided for @checklistVhf.
  ///
  /// In en, this message translates to:
  /// **'VHF radio working'**
  String get checklistVhf;

  /// No description provided for @checklistFuel.
  ///
  /// In en, this message translates to:
  /// **'Sufficient fuel level'**
  String get checklistFuel;

  /// No description provided for @checklistBilgePump.
  ///
  /// In en, this message translates to:
  /// **'Bilge pump working'**
  String get checklistBilgePump;

  /// No description provided for @checklistFirstAid.
  ///
  /// In en, this message translates to:
  /// **'First aid kit'**
  String get checklistFirstAid;

  /// No description provided for @checklistAnchor.
  ///
  /// In en, this message translates to:
  /// **'Anchor and lines in good condition'**
  String get checklistAnchor;

  /// No description provided for @checklistNavLights.
  ///
  /// In en, this message translates to:
  /// **'Navigation lights working'**
  String get checklistNavLights;

  /// No description provided for @checklistWeather.
  ///
  /// In en, this message translates to:
  /// **'Weather forecast checked'**
  String get checklistWeather;

  /// No description provided for @checklistFloatPlan.
  ///
  /// In en, this message translates to:
  /// **'Passage plan shared ashore'**
  String get checklistFloatPlan;

  /// No description provided for @areYouGoing.
  ///
  /// In en, this message translates to:
  /// **'Are you going?'**
  String get areYouGoing;

  /// No description provided for @prepareChecklistAndSail.
  ///
  /// In en, this message translates to:
  /// **'Prepare checklist and set sail'**
  String get prepareChecklistAndSail;

  /// No description provided for @cancelRegatta.
  ///
  /// In en, this message translates to:
  /// **'Cancel regatta'**
  String get cancelRegatta;

  /// No description provided for @regattaInProgress.
  ///
  /// In en, this message translates to:
  /// **'The regatta is under way (recording).'**
  String get regattaInProgress;

  /// No description provided for @deleteRegatta.
  ///
  /// In en, this message translates to:
  /// **'Delete regatta'**
  String get deleteRegatta;

  /// No description provided for @deleteRegattaConfirm.
  ///
  /// In en, this message translates to:
  /// **'This regatta will be permanently deleted.'**
  String get deleteRegattaConfirm;

  /// No description provided for @regattaDeleted.
  ///
  /// In en, this message translates to:
  /// **'Regatta deleted'**
  String get regattaDeleted;

  /// No description provided for @regattaCancelled.
  ///
  /// In en, this message translates to:
  /// **'Regatta cancelled'**
  String get regattaCancelled;

  /// No description provided for @couldNotCancel.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel'**
  String get couldNotCancel;

  /// No description provided for @couldNotRespond.
  ///
  /// In en, this message translates to:
  /// **'Could not respond'**
  String get couldNotRespond;

  /// No description provided for @rsvpGoing.
  ///
  /// In en, this message translates to:
  /// **'Going'**
  String get rsvpGoing;

  /// No description provided for @rsvpMaybe.
  ///
  /// In en, this message translates to:
  /// **'Maybe'**
  String get rsvpMaybe;

  /// No description provided for @rsvpNotGoing.
  ///
  /// In en, this message translates to:
  /// **'Not going'**
  String get rsvpNotGoing;

  /// No description provided for @rsvpGoingCount.
  ///
  /// In en, this message translates to:
  /// **'Going'**
  String get rsvpGoingCount;

  /// No description provided for @rsvpNotGoingCount.
  ///
  /// In en, this message translates to:
  /// **'Not going'**
  String get rsvpNotGoingCount;

  /// No description provided for @selectABoat.
  ///
  /// In en, this message translates to:
  /// **'Select a boat'**
  String get selectABoat;

  /// No description provided for @selectDeparturePortFirst.
  ///
  /// In en, this message translates to:
  /// **'Select the departure port'**
  String get selectDeparturePortFirst;

  /// No description provided for @regattaScheduled.
  ///
  /// In en, this message translates to:
  /// **'Regatta scheduled'**
  String get regattaScheduled;

  /// No description provided for @couldNotSchedule.
  ///
  /// In en, this message translates to:
  /// **'Could not schedule'**
  String get couldNotSchedule;

  /// No description provided for @scheduleRegatta.
  ///
  /// In en, this message translates to:
  /// **'Schedule regatta'**
  String get scheduleRegatta;

  /// No description provided for @regattaTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Title (e.g. Spring regatta)'**
  String get regattaTitleHint;

  /// No description provided for @selectBoatFirst.
  ///
  /// In en, this message translates to:
  /// **'Select a boat first.'**
  String get selectBoatFirst;

  /// No description provided for @addBoatFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a boat first.'**
  String get addBoatFirst;

  /// No description provided for @addCrewMemberHint.
  ///
  /// In en, this message translates to:
  /// **'Add crew member…'**
  String get addCrewMemberHint;

  /// No description provided for @checkEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkEmailTitle;

  /// No description provided for @checkEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a confirmation link to {email}. Open it to activate your account, then log in.'**
  String checkEmailBody(String email);

  /// No description provided for @resendEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get resendEmail;

  /// No description provided for @emailResent.
  ///
  /// In en, this message translates to:
  /// **'Email sent'**
  String get emailResent;

  /// No description provided for @couldNotResend.
  ///
  /// In en, this message translates to:
  /// **'Could not resend the email'**
  String get couldNotResend;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get backToLogin;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orDivider;

  /// No description provided for @completeAndSail.
  ///
  /// In en, this message translates to:
  /// **'Complete and set sail'**
  String get completeAndSail;

  /// No description provided for @sailAnyway.
  ///
  /// In en, this message translates to:
  /// **'Set sail anyway'**
  String get sailAnyway;

  /// No description provided for @statusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get statusScheduled;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusInProgress;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @regattaLabel.
  ///
  /// In en, this message translates to:
  /// **'Regatta'**
  String get regattaLabel;

  /// No description provided for @memberLabel.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get memberLabel;

  /// No description provided for @joinAsGroup.
  ///
  /// In en, this message translates to:
  /// **'Join as a group'**
  String get joinAsGroup;

  /// No description provided for @selectAGroup.
  ///
  /// In en, this message translates to:
  /// **'Select a group'**
  String get selectAGroup;

  /// No description provided for @joinedWithGroup.
  ///
  /// In en, this message translates to:
  /// **'You\'ve joined with your group'**
  String get joinedWithGroup;

  /// No description provided for @couldNotJoin.
  ///
  /// In en, this message translates to:
  /// **'Could not join'**
  String get couldNotJoin;

  /// No description provided for @groupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get groupLabel;

  /// No description provided for @createGroupFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a group first to join with your team.'**
  String get createGroupFirst;

  /// No description provided for @joinWithMyGroup.
  ///
  /// In en, this message translates to:
  /// **'Join with my group'**
  String get joinWithMyGroup;

  /// No description provided for @sharedWithMe.
  ///
  /// In en, this message translates to:
  /// **'Shared with me'**
  String get sharedWithMe;

  /// No description provided for @sharedBoatInfo.
  ///
  /// In en, this message translates to:
  /// **'This boat is shared with you. You have the permissions its owner granted.'**
  String get sharedBoatInfo;

  /// No description provided for @permissionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 permission} other{{count} permissions}}'**
  String permissionsCount(int count);

  /// No description provided for @permRecordTrips.
  ///
  /// In en, this message translates to:
  /// **'Record trips'**
  String get permRecordTrips;

  /// No description provided for @permManageExpenses.
  ///
  /// In en, this message translates to:
  /// **'Manage expenses'**
  String get permManageExpenses;

  /// No description provided for @permManageMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Manage maintenance'**
  String get permManageMaintenance;

  /// No description provided for @permViewDocuments.
  ///
  /// In en, this message translates to:
  /// **'View documents'**
  String get permViewDocuments;

  /// No description provided for @permManageDocuments.
  ///
  /// In en, this message translates to:
  /// **'Manage documents'**
  String get permManageDocuments;

  /// No description provided for @maintenanceTab.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenanceTab;

  /// No description provided for @expensesTab.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesTab;

  /// No description provided for @newMaintenance.
  ///
  /// In en, this message translates to:
  /// **'New maintenance'**
  String get newMaintenance;

  /// No description provided for @newExpense.
  ///
  /// In en, this message translates to:
  /// **'New expense'**
  String get newExpense;

  /// No description provided for @editExpense.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get editExpense;

  /// No description provided for @invoiceAttached.
  ///
  /// In en, this message translates to:
  /// **'Invoice attached'**
  String get invoiceAttached;

  /// No description provided for @regattasAndOutings.
  ///
  /// In en, this message translates to:
  /// **'Regattas & outings'**
  String get regattasAndOutings;

  /// No description provided for @requestsCount.
  ///
  /// In en, this message translates to:
  /// **'Requests ({count})'**
  String requestsCount(int count);

  /// No description provided for @requestAdmitted.
  ///
  /// In en, this message translates to:
  /// **'Request admitted'**
  String get requestAdmitted;

  /// No description provided for @requestRejected.
  ///
  /// In en, this message translates to:
  /// **'Request rejected'**
  String get requestRejected;

  /// No description provided for @roleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwner;

  /// No description provided for @visibilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get visibilityLabel;

  /// No description provided for @myGroupsTab.
  ///
  /// In en, this message translates to:
  /// **'My groups'**
  String get myGroupsTab;

  /// No description provided for @discoverTab.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discoverTab;

  /// No description provided for @pendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingLabel;

  /// No description provided for @pendingCountShort.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String pendingCountShort(int count);

  /// No description provided for @followLive.
  ///
  /// In en, this message translates to:
  /// **'Watch live'**
  String get followLive;

  /// No description provided for @couldNotOpenLive.
  ///
  /// In en, this message translates to:
  /// **'Could not open the live stream'**
  String get couldNotOpenLive;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
