import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/discipline_repository.dart';
import '../../domain/entities/discipline_case.dart';
import '../repositories/discipline_repository_impl.dart';
import '../../features/auth/state/auth_provider.dart';
import '../../features/auth/state/auth_state.dart';
import '../../core/config/role_config.dart';

final disciplineRepositoryProvider = Provider<DisciplineRepository>((ref) {
  return DisciplineRepositoryImpl(FirebaseFirestore.instance);
});

final facultyHistoryProvider = FutureProvider.autoDispose<List<DisciplineCase>>(
  (ref) async {
    final authState = ref.watch(authProvider);
    final repository = ref.watch(disciplineRepositoryProvider);

    if (authState.status == AuthStatus.authenticated &&
        authState.user != null) {
      final user = authState.user!;
      final role = user.role;

      // Admins, Heads, and Security see all recent activity
      if (role == UserRole.admin ||
          role == UserRole.hod ||
          role == UserRole.principal ||
          role == UserRole.securityAdmin ||
          role == UserRole.security) {
        return repository.getRecentCases();
      }

      // Faculty and Security see only their reports
      return repository.getReportedCases(user.id);
    }
    return [];
  },
);
