class PhoneUtils {
  /// Formats any phone number input to standard South Africa (RSA) international format (+27 XX XXX XXXX).
  /// If the user enters a normal local number (e.g. 0821234567 or 821234567), it automatically defaults to RSA +27.
  static String formatRSAPhone(String rawPhone) {
    if (rawPhone.trim().isEmpty) return rawPhone;
    
    // Remove extra spaces and characters except digits and leading +
    String cleaned = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (cleaned.startsWith('0')) {
      cleaned = '+27${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('+')) {
      cleaned = '+27$cleaned';
    }

    // Standard RSA formatting: +27 82 123 4567
    final match = RegExp(r'^\+27(\d{2})(\d{3})(\d{4})$').firstMatch(cleaned);
    if (match != null) {
      return '+27 ${match.group(1)} ${match.group(2)} ${match.group(3)}';
    }

    return cleaned;
  }

  /// Returns raw unformatted clean phone number for API / SMS gateways (e.g., +27821234567)
  static String toCleanRSAPhone(String rawPhone) {
    final formatted = formatRSAPhone(rawPhone);
    return formatted.replaceAll(RegExp(r'[^\d+]'), '');
  }
}
