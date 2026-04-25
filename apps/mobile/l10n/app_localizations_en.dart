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
}
