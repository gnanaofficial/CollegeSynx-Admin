import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/role_config.dart';
import '../../../../core/config/shared_prefs_provider.dart';
import '../../../../data/repositories/auth_repository_impl.dart';
import '../../../../domain/repositories/auth_repository.dart';
import '../../../../domain/usecases/login_usecase.dart';
import '../services/mpin_service.dart';
import 'auth_state.dart';

// Dependency Injection
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthRepositoryImpl(prefs);
});

final mpinServiceProvider = Provider<MpinService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return MpinService(prefs);
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});

// State Management
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(loginUseCaseProvider),
    ref.watch(mpinServiceProvider),
    ref.watch(authRepositoryProvider),
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  final LoginUseCase _loginUseCase;
  final MpinService _mpinService;
  final AuthRepository _authRepository;

  AuthNotifier(this._loginUseCase, this._mpinService, this._authRepository)
    : super(const AuthState()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final result = await _authRepository.getCurrentUser();
    result.fold(
      (error) => state = const AuthState(status: AuthStatus.unauthenticated),
      (user) {
        if (user != null) {
          // User found in local storage
          state = state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            isMpinVerified: false, // Require MPIN on restore
          );
        } else {
          state = const AuthState(status: AuthStatus.unauthenticated);
        }
      },
    );
  }

  // Called when MPIN is verified (Biometric or Pin)
  void verifyMpin() {
    state = state.copyWith(isMpinVerified: true);
  }

  Future<void> login({
    required String collegeId,
    required String password,
    required UserRole role,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _loginUseCase(
      collegeId: collegeId,
      password: password,
      role: role,
    );

    result.fold(
      (error) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
          status: AuthStatus.unauthenticated,
        );
      },
      (user) {
        // If login successful, we consider the user verified by password.
        // The router will still divert to Setup MPIN if it's not set.
        state = state.copyWith(
          isLoading: false,
          user: user,
          status: AuthStatus.authenticated,
          isMpinVerified: true,
        );
      },
    );
  }

  Future<void> logout() async {
    await _mpinService.clear(); // Optional: clear MPIN on logout? Maybe not.
    // Usually MPIN is tied to the account on the device.
    // If we logout, we probably should clear MPIN so next user doesn't get confused or stuck.
    // For this app, let's clear it.
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
