class EmailService {
  /// Simulates sending an email with the ticket/QR code.
  /// Returns [true] if successful.
  static Future<bool> sendTicketEmail(
    String email,
    String eventName,
    String qrPayload,
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // In a real app, this would call a backend API (e.g., SendGrid/Firebase).
    print("----------------------------------------------------------------");
    print("EMAIL SENT TO: $email");
    print("SUBJECT: Your Ticket for $eventName");
    print("BODY: Here is your QR Code access token: $qrPayload");
    print("Please present this at the venue entrance.");
    print("----------------------------------------------------------------");

    return true;
  }
}
