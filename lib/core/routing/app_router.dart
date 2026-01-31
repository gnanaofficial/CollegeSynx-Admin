import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/state/auth_provider.dart';
import '../../features/auth/state/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/set_mpin_screen.dart';
import '../../features/auth/presentation/verify_mpin_screen.dart';
import '../../features/dashboard/faculty_dashboard.dart';
import '../../features/scanner/presentation/scanner_screen.dart';
import '../../features/scanner/presentation/student_preview_screen.dart';
import '../../features/scanner/presentation/improved_event_scan_screen.dart';
import '../../features/verification/presentation/student_verification_screen.dart';
import '../../domain/entities/student.dart';

import '../../features/dashboard/hod_dashboard.dart';
import '../../features/dashboard/security_admin_dashboard.dart';
import '../../features/dashboard/security_dashboard.dart';
import '../../core/config/role_config.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: AuthNotifierListenable(ref.read(authProvider.notifier)),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoggedIn = authState.status == AuthStatus.authenticated;
      final isLoggingIn = state.uri.toString() == '/login';

      // Safety Guard: If user tries to go to deleted student dashboard, redirect to Faculty
      if (state.uri.toString() == '/student-dashboard') {
        return '/faculty-dashboard';
      }

      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login';
      }

      // User is logged in. Check MPIN status.
      final mpinService = ref.read(mpinServiceProvider);
      final isMpinSet = mpinService.isMpinSet;
      final isMpinVerified = authState.isMpinVerified;

      // 1. If MPIN is NOT set, Force them to set it.
      if (!isMpinSet) {
        if (state.uri.toString() == '/set-mpin') return null;
        return '/set-mpin';
      }

      // 2. If MPIN IS set, but NOT verified, Force verification.
      if (!isMpinVerified) {
        if (state.uri.toString() == '/verify-mpin') return null;
        return '/verify-mpin';
      }

      // 3. Authenticated & Verified & MPIN Set.
      // If trying to access login or mpin pages, redirect to dashboard.
      if (isLoggingIn ||
          state.uri.toString() == '/set-mpin' ||
          state.uri.toString() == '/verify-mpin') {
        // Redirect based on ROLE
        final role = authState.user?.role;
        switch (role) {
          case UserRole.hod:
            return '/hod-dashboard';
          case UserRole.securityAdmin:
            return '/security-admin-dashboard';
          case UserRole.security:
            return '/security-dashboard';
          case UserRole.faculty:
            return '/faculty-dashboard';

          default:
            return '/faculty-dashboard'; // Default
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/set-mpin',
        builder: (context, state) => const SetMpinScreen(),
      ),
      GoRoute(
        path: '/verify-mpin',
        builder: (context, state) => const VerifyMpinScreen(),
      ),
      GoRoute(
        path: '/faculty-dashboard',
        builder: (context, state) => const FacultyDashboard(),
      ),

      GoRoute(
        path: '/hod-dashboard',
        builder: (context, state) => const HodDashboard(),
      ),
      GoRoute(
        path: '/security-admin-dashboard',
        builder: (context, state) => const SecurityAdminDashboard(),
      ),
      GoRoute(
        path: '/security-dashboard',
        builder: (context, state) => const SecurityDashboard(),
      ),
      GoRoute(
        path: '/scanner',
        builder: (context, state) => const ScannerScreen(),
      ),
      GoRoute(
        path: '/student-preview',
        builder: (context, state) {
          final student = state.extra as Student;
          return StudentPreviewScreen(student: student);
        },
      ),
      GoRoute(
        path: '/event-scan',
        builder: (context, state) => const ImprovedEventScanScreen(),
      ),
      GoRoute(
        path: '/verification',
        builder: (context, state) {
          final student = state.extra as Student;
          return StudentVerificationScreen(student: student);
        },
      ),
    ],
  );
});

// Helper to notify router when auth state changes
class AuthNotifierListenable extends ChangeNotifier {
  final AuthNotifier _notifier;
  late final StreamSubscription<AuthState> _subscription;

  AuthNotifierListenable(this._notifier) {
    _subscription = _notifier.stream.listen((state) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
