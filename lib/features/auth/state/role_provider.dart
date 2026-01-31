import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/role_config.dart';

// StateProvider to manage the selected role from the avatar selector.
// Defaults to null as per requirement "No default selection".
final selectedRoleProvider = StateProvider<UserRole?>((ref) => null);
