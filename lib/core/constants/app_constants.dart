/// App-wide constants shared across all features.
class AppConstants {
  AppConstants._();

  static const String appName = 'Aulens';
  static const String dbName = 'aulens.db';
  static const int dbVersion = 8;

  /// Subdirectory inside application documents for persisted note images.
  static const String imagesDirName = 'aulens_images';

  /// Grace window (minutes) used when matching notes to schedule slots.
  static const int sessionPreGraceMinutes = 0;
  static const int sessionPostGraceMinutes = 10;

  /// Weekday names indexed by [DateTime.weekday] convention (1 = Monday … 7 = Sunday).
  static const List<String> weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
}
