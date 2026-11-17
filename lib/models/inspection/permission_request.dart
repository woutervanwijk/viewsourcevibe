/// A native permission request (camera, microphone, location, ...) a page
/// made. The app always denies it; this only records that it was asked.
class PermissionRequestEvent {
  /// Who asked, e.g. https://maps.test
  final String origin;

  /// Lower-case names: 'camera', 'microphone', 'geolocation', ...
  final List<String> resources;

  /// Time since the last main-frame load start; null when none was seen.
  final Duration? sinceLoadStart;

  const PermissionRequestEvent({
    required this.origin,
    required this.resources,
    required this.sinceLoadStart,
  });
}
