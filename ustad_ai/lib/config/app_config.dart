// lib/config/app_config.dart

class AppConfig {
  /// Toggle for demo presentation mode.
  /// When true: Quick 1-tap demo logins for Principal & Teacher are shown on login screen.
  /// When false: Clean production login mode (no demo buttons, strict production security).
  static bool isDemoMode = true;

  /// Clean school mode (fresh school deployment: no sample students, no sample teachers, ONLY Admin & Principal).
  static bool isCleanDataMode = false;
}
