import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  static const String _cameraPermissionKey = 'camera_permission_requested';

  final SharedPreferences _prefs;

  PermissionService(this._prefs);

  /// Checks if camera permission has been requested before.
  bool get hasRequestedCameraPermission =>
      _prefs.getBool(_cameraPermissionKey) ?? false;

  /// Requests camera permission.
  /// Returns true if granted, false otherwise.
  /// Also persists that the permission has been requested.
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();

    // Mark as requested so we don't spam prompts if logic dictates,
    // though the OS handles "Don't ask again" automatically.
    // We strictly follow the rule: "Persist permission status locally. Do NOT re-prompt users again."
    await _prefs.setBool(_cameraPermissionKey, true);

    return status.isGranted;
  }

  /// Checks current camera permission status.
  Future<PermissionStatus> getCameraPermissionStatus() async {
    return await Permission.camera.status;
  }

  /// Opens app settings if permission is permanently denied
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
