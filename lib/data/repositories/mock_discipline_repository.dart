import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/discipline_case.dart';

abstract class DisciplineRepository {
  Future<List<DisciplineCase>> getHistory(String studentId);
  Future<void> raiseCase(DisciplineCase disciplineCase);
}

class MockDisciplineRepository implements DisciplineRepository {
  // In-memory store for the session
  final List<DisciplineCase> _cases = [
    DisciplineCase(
      id: '1',
      studentId: '24BFA33L12',
      category: 'Administrative Services',
      subCategory: 'Late Arrival',
      subject: 'Late Entry',
      description: 'Arrived after 8:30 AM',
      severity: 'Normal',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      reportedBy: 'System',
    ),
    DisciplineCase(
      id: '2',
      studentId: '24BFA33L12',
      category: 'Academic Affairs',
      subCategory: 'Uniform',
      subject: 'Uniform Issue',
      description: 'No ID Card worn',
      severity: 'Normal',
      timestamp: DateTime.now().subtract(const Duration(days: 5)),
      reportedBy: 'Dr. Sharma',
    ),
  ];

  @override
  Future<List<DisciplineCase>> getHistory(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 500)); // Sim network
    return _cases.where((c) => c.studentId == studentId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<List<DisciplineCase>> getFacultyHistory(String facultyId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Return all cases for simplicity or filter by reportedBy
    return _cases.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Future<void> raiseCase(DisciplineCase disciplineCase) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _cases.add(disciplineCase);
  }
}

final disciplineRepositoryProvider = Provider<MockDisciplineRepository>((ref) {
  return MockDisciplineRepository();
});

final facultyHistoryProvider = FutureProvider.autoDispose<List<DisciplineCase>>(
  (ref) async {
    final repo = ref.watch(disciplineRepositoryProvider);
    // Mock ID
    return repo.getFacultyHistory('Dr. Sharma');
  },
);
