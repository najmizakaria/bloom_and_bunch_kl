class Money {
  Money._();

  static int toSen(num value) => (value * 100).round();
  static double round(num value) => toSen(value) / 100;

  // Round a complete bouquet once, including any legacy fractional stem prices.
  static double customTotal(Iterable<double> stemLines, double decorations) =>
      round(stemLines.fold(decorations, (sum, line) => sum + line));
}
