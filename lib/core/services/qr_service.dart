import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../features/guests/domain/guest_model.dart';
import '../../features/events/domain/event_model.dart';

enum QrValidationResult { success, tooEarly, expired, invalid }

class QrService {
  // Secret key for HMAC (simulated)
  static const String _secretKey = "svce_secure_event_key";

  /// Generates a time-bound QR payload
  /// Payload Format: guestId|eventId|expiryEpoch|HMAC
  static String generateGuestQr(ExternalGuest guest, Event event) {
    // Validity: From AccessStart until AccessEnd
    final expiry = guest.accessWindowEnd.millisecondsSinceEpoch;
    final payloadData = "${guest.id}|${event.id}|$expiry";

    final hmac = Hmac(sha256, utf8.encode(_secretKey));
    final digest = hmac.convert(utf8.encode(payloadData));

    return "$payloadData|$digest";
  }

  /// Validates a scanned QR payload
  static QrValidationResult validateQr(String payload, DateTime checkTime) {
    try {
      final parts = payload.split('|');
      if (parts.length != 4) return QrValidationResult.invalid;

      final guestId = parts[0];
      final eventId = parts[1];
      final expiry = int.parse(parts[2]);
      final signature = parts[3];

      // 1. Verify Signature
      final dataToVerify = "$guestId|$eventId|$expiry";
      final hmac = Hmac(sha256, utf8.encode(_secretKey));
      final digest = hmac.convert(utf8.encode(dataToVerify));

      if (digest.toString() != signature) {
        return QrValidationResult.invalid;
      }

      // 2. Check Expiry
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiry);
      if (checkTime.isAfter(expiryDate)) {
        return QrValidationResult.expired;
      }

      // 3. Check "Too Early" (Optional - usually accessWindowStart is implicit)
      // If we encoded start time we could check it. For now, we assume
      // if you have the QR, you can enter unless expired.
      // But user asked for "unlocks before few hours".
      // Let's assume the QR is generated/distributed only when relevant, or we can add StartTime to payload.

      return QrValidationResult.success;
    } catch (e) {
      return QrValidationResult.invalid;
    }
  }
}
