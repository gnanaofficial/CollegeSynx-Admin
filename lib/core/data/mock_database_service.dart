import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/events/domain/event_model.dart';
import '../../features/events/domain/team_model.dart';
// Duplicate imports removed
import '../../features/guests/domain/guest_model.dart';
import '../../features/verification/domain/verification_log.dart';
import '../../domain/entities/student.dart';

/// This service replicates a backend database.
/// In the future, replace internal lists with API calls/Hive boxes.
class MockDatabaseService {
  final List<Event> _events = [];
  final Map<String, Student> _students = {};
  Map<String, Student> get students => _students; // Public getter for seeding
  final List<VerificationLog> _logs = [];

  MockDatabaseService() {
    _initData();
  }

  void _initData() {
    // 1. Seed Students
    // Data removed as requested

    // 2. Seed Events
    _events.add(
      Event(
        id: 'annual_day_2026',
        title: 'Annual Day 2026',
        description: 'Open to all students with Face Verification.',
        date: DateTime(2026, 3, 15, 10, 0),
        location: 'Main Auditorium',
        requiresLiveVerification: true,
        checkedInCount: 0,
        totalRegistrations: 5000, // Implies "All"
        accessType: EventAccessType.studentsOnly,
        eventType: EventType.individual,
      ),
    );
  }

  // --- CRUD Operations ---

  // Events
  Future<List<Event>> getEvents() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.unmodifiable(_events);
  }

  Future<void> addEvent(Event event) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _events.add(event);
  }

  Future<void> updateEvent(Event event) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      _events[index] = event;
    }
  }

  // Students
  Future<Student?> getStudent(String rollNumber) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final key = rollNumber.trim().toUpperCase();

    // Allow case-insensitive search by keys
    for (var k in _students.keys) {
      if (k.toUpperCase() == key) return _students[k];
    }
    return null;
  }

  // Teams
  final List<Team> _teams = [];

  // Guests
  final List<ExternalGuest> _guests = [];

  // ... (previous helper methods if any) ...

  // --- Team Operations ---
  Future<void> addTeam(Team team) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _teams.add(team);
  }

  Future<List<Team>> getTeamsForEvent(String eventId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _teams.where((t) => t.eventId == eventId).toList();
  }

  // --- Guest Operations ---
  Future<void> addGuest(ExternalGuest guest) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _guests.add(guest);
  }

  Future<ExternalGuest?> getGuestByQr(String qrPayload) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      return _guests.firstWhere((g) => g.qrPayload == qrPayload);
    } catch (_) {
      return null;
    }
  }

  // Logs
  Future<void> addLog(VerificationLog log) async {
    _logs.add(log); // No delay needed for logs usually
  }

  Future<List<VerificationLog>> getLogs(String eventId) async {
    return _logs.where((l) => l.eventId == eventId).toList();
  }
}

final mockDatabaseProvider = Provider<MockDatabaseService>((ref) {
  return MockDatabaseService();
});
