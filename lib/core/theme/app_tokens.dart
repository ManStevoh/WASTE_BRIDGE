/// Design tokens for spacing, radii, and touch targets.
/// Prefer these over magic numbers in new UI; migrate existing screens opportunistically.
library;

abstract final class AppSpacing {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppRadius {
  static const double input = 14;
  static const double card = 16;
  static const double sheet = 20;
}

abstract final class AppTouchTarget {
  /// Material minimum for primary tap targets.
  static const double minSize = 48;
}
