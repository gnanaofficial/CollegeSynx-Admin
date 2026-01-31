import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class MpinService {
  final SharedPreferences _prefs;
  final LocalAuthentication _localAuth;

  static const String _mpinKey = 'user_mpin';
  static const String _biometricEnabledKey = 'biometric_enabled';

  MpinService(this._prefs) : _localAuth = LocalAuthentication();

  /// Check if MPIN is set
  bool get isMpinSet => _prefs.getString(_mpinKey) != null;

  /// Authenticate with MPIN
  bool verifyMpin(String mpin) {
    final storedMpin = _prefs.getString(_mpinKey);
    return storedMpin == mpin;
  }

  /// Set user MPIN
  Future<void> setMpin(String mpin) async {
    await _prefs.setString(_mpinKey, mpin);
  }

  /// Check if Biometrics is enabled by user
  bool get isBiometricEnabled => _prefs.getBool(_biometricEnabledKey) ?? false;

  /// Enable/Disable Biometrics
  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool(_biometricEnabledKey, enabled);
  }

  /// Check if device supports biometrics
  Future<bool> get isBiometricAvailable async {
    try {
      final bool canAuthenticateWithBiometrics =
          await _localAuth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Authenticate using Biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      final isAvailable = await isBiometricAvailable;
      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access the app',
        biometricOnly: true,
      );
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Clear all data (Logout)z
  Future<void> clear() async {
    await _prefs.remove(_mpinKey);
    await _prefs.remove(_biometricEnabledKey);
  }
}
