class RiderPhone {
  static String normalize(String value) {
    const message = 'Enter a phone number using up to 30 characters.';
    final phone = value.trim();
    if (value.length > 30 ||
        !RegExp(r'^[+\d ()-]+$').hasMatch(phone) ||
        !RegExp(r'\d').hasMatch(phone)) {
      throw const FormatException(message);
    }
    return phone;
  }
}
