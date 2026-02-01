import '../entities/discipline_case.dart';

abstract class DisciplineRepository {
  Future<List<DisciplineCase>> getHistory(String studentId);
  Future<void> raiseCase(DisciplineCase disciplineCase);
  Future<List<String>> getDisputeTypes();
  Future<void> deleteCase(String caseId, String studentId);
  Future<void> resetCredits(String studentId);
  Future<List<DisciplineCase>> getReportedCases(String reporterId);
  Future<List<DisciplineCase>> getRecentCases({int limit = 20});
}
