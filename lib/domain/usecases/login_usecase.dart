import 'package:dartz/dartz.dart';
import '../../core/config/role_config.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<Either<Exception, UserEntity>> call({
    required String collegeId,
    required String password,
    required UserRole role,
  }) {
    return repository.login(
      collegeId: collegeId,
      password: password,
      role: role,
    );
  }
}
