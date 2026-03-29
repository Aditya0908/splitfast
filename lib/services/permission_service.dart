import 'package:permission_handler/permission_handler.dart';

/// Centralized permission handling for contacts and camera.
class PermissionService {
  PermissionService._();
  static final instance = PermissionService._();

  /// Request contacts permission. Returns true if granted.
  Future<bool> requestContacts() async {
    var status = await Permission.contacts.status;
    if (status.isGranted) return true;

    status = await Permission.contacts.request();
    return status.isGranted;
  }

  /// Request camera permission. Returns true if granted.
  Future<bool> requestCamera() async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;

    status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Check if contacts permission is granted without requesting.
  Future<bool> hasContactsPermission() => Permission.contacts.isGranted;

  /// Check if camera permission is granted without requesting.
  Future<bool> hasCameraPermission() => Permission.camera.isGranted;

  /// Returns true if the permission was permanently denied
  /// (user must go to system settings).
  Future<bool> isContactsPermanentlyDenied() =>
      Permission.contacts.isPermanentlyDenied;

  Future<bool> isCameraPermanentlyDenied() =>
      Permission.camera.isPermanentlyDenied;
}
