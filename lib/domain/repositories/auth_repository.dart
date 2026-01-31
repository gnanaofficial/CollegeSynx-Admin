import 'package:dartz/dartz.dart';
import '../entities/user_entity.dart';
import '../../core/config/role_config.dart';

abstract class AuthRepository {
  Future<Either<Exception, UserEntity>> login({
    required String collegeId,
    required String password,
    required UserRole role,
  });

  Future<void> logout();

  Future<Either<Exception, UserEntity?>> getCurrentUser();
}
