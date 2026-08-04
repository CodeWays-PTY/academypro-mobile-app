library;

/// Type parsing utilities ensuring safe runtime conversion between ints, doubles, strings, and booleans.
/// Prevents Dart TypeError exceptions when JSON payloads contain numbers vs strings for IDs, metrics, or counts.
class TypeParsers {
  /// Safely converts any dynamic value to a String
  static String parseString(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    return value.toString();
  }

  /// Safely converts any dynamic value to an int
  static int parseInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  /// Safely converts any dynamic value to a nullable int
  static int? parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  /// Safely converts any dynamic value to a double
  static double parseDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  /// Safely converts any dynamic value to a nullable double
  static double? parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  /// Safely converts any dynamic value (bool, int 1/0, string 'true'/'false') to a bool
  static bool parseBool(dynamic value, [bool fallback = false]) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value == 1 || value == '1' || value.toString().toLowerCase() == 'true') return true;
    if (value == 0 || value == '0' || value.toString().toLowerCase() == 'false') return false;
    return fallback;
  }
}
