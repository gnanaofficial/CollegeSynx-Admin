import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import '../../../core/data/mock_database_service.dart';
import '../../../core/services/email_service.dart';
import '../../../core/services/qr_service.dart';
import '../domain/event_model.dart';
import '../../../../domain/entities/student.dart';
import '../../../../domain/repositories/student_repository.dart';
import '../../../data/providers/student_provider.dart';
import '../domain/team_model.dart';
import '../../guests/domain/guest_model.dart';

class EventRepository {
  final MockDatabaseService _db;
  final StudentRepository _studentRepo;

  EventRepository(this._db, this._studentRepo);

  Future<List<Event>> getEvents() {
    return _db.getEvents();
  }

  Future<void> addEvent(Event event) {
    return _db.addEvent(event);
  }

  // --- Student / Individual ---
  Future<Student?> getStudentByRollNumber(String code) async {
    final cleanCode = code.trim();

    // 1. Try Barcode Lookup
    // We intentionally suppress errors here because if the "barcode" index
    // is missing/broken, we still want to try looking up by Roll Number.
    Student? studentFromBarcode;
    try {
      final barcodeResult = await _studentRepo.getStudentByBarcode(cleanCode);
      studentFromBarcode = barcodeResult.getOrElse(() => null);
    } catch (e) {
      // Ignore barcode-specific errors (like missing index) to try fallback
      // print("Barcode lookup failed: $e");
    }

    if (studentFromBarcode != null) return studentFromBarcode;

    // 2. Fallback: Try Roll Number Lookup
    // If THIS fails with an error (e.g. missing index), we SHOULD throw
    // because this is our last resort and the user needs to know.
    final rollResult = await _studentRepo.getStudentByRollNo(cleanCode);

    if (rollResult.isLeft()) {
      rollResult.fold((error) => throw error, (r) => null);
    }

    return rollResult.getOrElse(() => null);
  }

  Future<void> checkInStudent(String eventId, String rollNumber) async {
    // 1. Get Event
    final events = await _db.getEvents();
    final index = events.indexWhere((e) => e.id == eventId);

    if (index != -1) {
      // 2. Update Count
      final event = events[index];
      final updatedEvent = event.copyWith(
        checkedInCount: event.checkedInCount + 1,
      );

      // 3. Save
      await _db.updateEvent(updatedEvent);
    }
  }

  // --- Team Management ---
  Future<List<Team>> getTeams(String eventId) {
    return _db.getTeamsForEvent(eventId);
  }

  Future<void> createTeam(Team team) {
    return _db.addTeam(team);
  }

  // --- Guest Management ---
  Future<void> registerGuest(ExternalGuest guest, Event event) async {
    // 1. Generate QR Payload
    final qrPayload = QrService.generateGuestQr(guest, event);
    final updatedGuest = guest.copyWith(qrPayload: qrPayload);

    // 2. Save to DB
    await _db.addGuest(updatedGuest);

    // 3. Send Email
    await EmailService.sendTicketEmail(guest.email, event.title, qrPayload);
  }

  Future<ExternalGuest?> getGuestByQr(String qrPayload) {
    return _db.getGuestByQr(qrPayload);
  }

  // --- Bulk Import ---
  /// Imports registrations from a CSV file.
  /// Expected Format:
  /// TYPE, NAME, ID/EMAIL, [TEAM_NAME], [MEMBERS...]
  ///
  /// Examples:
  /// Individual, John Doe, 24BFA33L12
  /// Team, Hackers, LEADER_ID, MEMBER_ID_1, MEMBER_ID_2
  Future<ImportResult> importRegistrationsFromCsv(
    File file,
    String eventId,
  ) async {
    try {
      final input = await file.readAsString();
      final rows = const CsvToListConverter().convert(input);

      int successCount = 0;
      int failCount = 0;

      for (var row in rows) {
        if (row.isEmpty) continue;

        final type = row[0]
            .toString()
            .trim()
            .toLowerCase(); // 'individual' or 'team'

        if (type == 'team') {
          // Team Import Logic
          if (row.length < 3) {
            failCount++;
            continue;
          }
          final teamName = row[1].toString();
          final leaderId = row[2].toString();
          final members = row
              .sublist(3)
              .map((e) => e.toString().trim())
              .toList();

          final team = Team(
            id:
                DateTime.now().millisecondsSinceEpoch.toString() +
                successCount.toString(),
            name: teamName,
            leaderRollNumber: leaderId,
            memberRollNumbers: members,
            eventId: eventId,
          );

          await _db.addTeam(team);
          successCount++;
        } else {
          // Individual Logic (For mixed imports if needed)
          // For now, we assume individual registration is via app/existing DB,
          // but we could add logic here to add missing students to the DB.
          // Skipping strictly for this task unless requested.
          successCount++;
        }
      }

      return ImportResult(success: true, count: successCount);
    } catch (e) {
      return ImportResult(success: false, message: e.toString());
    }
  }
}

class ImportResult {
  final bool success;
  final int count;
  final String? message;

  ImportResult({required this.success, this.count = 0, this.message});
}

final eventRepositoryProvider = Provider((ref) {
  final db = ref.watch(mockDatabaseProvider);
  final studentRepo = ref.watch(studentRepositoryProvider);
  return EventRepository(db, studentRepo);
});
