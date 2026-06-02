/// Immutable app metadata resolved once at startup (from `package_info_plus`)
/// and provided to the widget tree, so the app version has a single source of
/// truth instead of being hardcoded in multiple places.
class AppInfo {
  const AppInfo({required this.version});

  /// The app version (e.g. `1.0.0`), without the build number.
  final String version;
}
