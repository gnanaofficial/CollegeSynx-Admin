import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/mock_database_service.dart';
import '../../../core/services/qr_service.dart';
import '../../guests/domain/guest_model.dart';
import '../../events/domain/team_model.dart';
import '../domain/verification_log.dart';

class VerificationRepository {
  final MockDatabaseService _db;

  VerificationRepository(this._db);

  Future<void> saveLog(VerificationLog log) async {
    await _db.addLog(log);
  }

  Future<List<VerificationLog>> getLogsForEvent(String eventId) async {
    return _db.getLogs(eventId);
  }

  // --- New Logic for Guests ---
  Future<QrValidationResult> verifyGuestQr(String payload) async {
    // 1. Decode generic validation (time, integrity)
    final result = QrService.validateQr(payload, DateTime.now());
    if (result != QrValidationResult.success) {
      return result;
    }

    // 2. Check if text exists in DB
    final guest = await _db.getGuestByQr(payload);
    if (guest == null) {
      return QrValidationResult.invalid;
    }

    return QrValidationResult.success;
  }

  Future<ExternalGuest?> getGuest(String payload) {
    return _db.getGuestByQr(payload);
  }

  // --- New Logic for Teams ---
  Future<List<Team>> searchTeams(String eventId, String query) async {
    final teams = await _db.getTeamsForEvent(eventId);
    if (query.isEmpty) return teams;

    final lowerQuery = query.toLowerCase();
    return teams.where((t) {
      return t.name.toLowerCase().contains(lowerQuery) ||
          t.leaderRollNumber.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}

final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  final db = ref.watch(mockDatabaseProvider);
  return VerificationRepository(db);
});
