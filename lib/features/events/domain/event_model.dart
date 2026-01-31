import 'package:equatable/equatable.dart';

enum EventType { individual, team }

enum EventAccessType { studentsOnly, public }

class Event extends Equatable {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String location;
  final bool requiresLiveVerification;
  final int checkedInCount;
  final int totalRegistrations;
  final String? externalDetailsUrl;
  final EventType eventType;
  final EventAccessType accessType;

  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    required this.requiresLiveVerification,
    this.checkedInCount = 0,
    this.totalRegistrations = 0,
    this.externalDetailsUrl,
    this.eventType = EventType.individual,
    this.accessType = EventAccessType.studentsOnly,
  });

  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    String? location,
    bool? requiresLiveVerification,
    int? checkedInCount,
    int? totalRegistrations,
    String? externalDetailsUrl,
    EventType? eventType,
    EventAccessType? accessType,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      location: location ?? this.location,
      requiresLiveVerification:
          requiresLiveVerification ?? this.requiresLiveVerification,
      checkedInCount: checkedInCount ?? this.checkedInCount,
      totalRegistrations: totalRegistrations ?? this.totalRegistrations,
      externalDetailsUrl: externalDetailsUrl ?? this.externalDetailsUrl,
      eventType: eventType ?? this.eventType,
      accessType: accessType ?? this.accessType,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    date,
    location,
    requiresLiveVerification,
    checkedInCount,
    totalRegistrations,
    externalDetailsUrl,
    eventType,
    accessType,
  ];
}

// Student class removed to avoid collision with domain/entities/student.dart
