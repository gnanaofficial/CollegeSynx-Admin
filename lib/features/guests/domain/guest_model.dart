import 'package:equatable/equatable.dart';

class ExternalGuest extends Equatable {
  final String id;
  final String name;
  final String email;
  final String eventId;
  final String? qrPayload; // Secure token for QR
  final DateTime accessWindowStart;
  final DateTime accessWindowEnd;
  final bool isCheckedIn;

  const ExternalGuest({
    required this.id,
    required this.name,
    required this.email,
    required this.eventId,
    required this.accessWindowStart,
    required this.accessWindowEnd,
    this.qrPayload,
    this.isCheckedIn = false,
  });

  ExternalGuest copyWith({
    String? id,
    String? name,
    String? email,
    String? eventId,
    String? qrPayload,
    DateTime? accessWindowStart,
    DateTime? accessWindowEnd,
    bool? isCheckedIn,
  }) {
    return ExternalGuest(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      eventId: eventId ?? this.eventId,
      qrPayload: qrPayload ?? this.qrPayload,
      accessWindowStart: accessWindowStart ?? this.accessWindowStart,
      accessWindowEnd: accessWindowEnd ?? this.accessWindowEnd,
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    eventId,
    qrPayload,
    accessWindowStart,
    accessWindowEnd,
    isCheckedIn,
  ];
}
