import 'package:flutter_inappwebview/flutter_inappwebview.dart'
    show PermissionResourceType;

/// Lower-case names for the resources of a native permission request.
/// CAMERA_AND_MICROPHONE is reported as both; others by their own name.
List<String> permissionResourceNames(List<PermissionResourceType> resources) {
  final names = <String>[];
  for (final r in resources) {
    final value = r.toValue();
    if (value == PermissionResourceType.CAMERA_AND_MICROPHONE.toValue()) {
      names.addAll(const ['camera', 'microphone']);
    } else {
      names.add(value.toLowerCase());
    }
  }
  return names;
}
