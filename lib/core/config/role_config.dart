enum UserRole { student, faculty, admin, hod, principal, security }

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.faculty:
        return 'Faculty';
      case UserRole.admin:
        return 'Admin';
      case UserRole.hod:
        return 'HOD';
      case UserRole.principal:
        return 'Principal';
      case UserRole.security:
        return 'Security';
    }
  }
}
