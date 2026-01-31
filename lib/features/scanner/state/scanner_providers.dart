import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/shared_prefs_provider.dart';
import '../../../core/services/permission_service.dart';

export '../../../data/providers/student_provider.dart';

// Permission Service Provider
final permissionServiceProvider = Provider<PermissionService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PermissionService(prefs);
});
