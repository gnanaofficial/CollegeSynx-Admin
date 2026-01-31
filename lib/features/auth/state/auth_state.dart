import 'package:equatable/equatable.dart';
import '../../../../domain/entities/user_entity.dart';

enum AuthStatus { initial, authenticated, unauthenticated }

class AuthState extends Equatable {
  final AuthStatus status;
  final UserEntity? user;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isMpinVerified = false,
  });

  final bool isMpinVerified;

  AuthState copyWith({
    AuthStatus? status,
    UserEntity? user,
    bool? isLoading,
    String? errorMessage,
    bool? isMpinVerified,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      isMpinVerified: isMpinVerified ?? this.isMpinVerified,
    );
  }

  @override
  List<Object?> get props => [
    status,
    user,
    isLoading,
    errorMessage,
    isMpinVerified,
  ];
}
