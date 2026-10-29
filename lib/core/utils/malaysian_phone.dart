class MalaysianPhone {
  static String normalize(String value) {
    const message =
        'Enter a valid Malaysian phone number, e.g. 0123456789 or +60123456789.';
    if (value.length > 30 || !RegExp(r'^[+\d\s()-]+$').hasMatch(value)) {
      throw const FormatException(message);
    }
    var phone = value.replaceAll(RegExp(r'[\s()+-]'), '');
    if (phone.startsWith('0060')) {
      phone = '0${phone.substring(4)}';
    } else if (phone.startsWith('60')) {
      phone = '0${phone.substring(2)}';
    }
    if (!RegExp(r'^0[1-9]\d{7,9}$').hasMatch(phone)) {
      throw const FormatException(message);
    }
    return '+60${phone.substring(1)}';
  }
}
