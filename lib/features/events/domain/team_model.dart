import 'package:equatable/equatable.dart';

class Team extends Equatable {
  final String id;
  final String name;
  final String leaderRollNumber;
  final List<String> memberRollNumbers;
  final String eventId;
  final bool isCheckedIn;

  const Team({
    required this.id,
    required this.name,
    required this.leaderRollNumber,
    required this.memberRollNumbers,
    required this.eventId,
    this.isCheckedIn = false,
  });

  Team copyWith({
    String? id,
    String? name,
    String? leaderRollNumber,
    List<String>? memberRollNumbers,
    String? eventId,
    bool? isCheckedIn,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      leaderRollNumber: leaderRollNumber ?? this.leaderRollNumber,
      memberRollNumbers: memberRollNumbers ?? this.memberRollNumbers,
      eventId: eventId ?? this.eventId,
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    leaderRollNumber,
    memberRollNumbers,
    eventId,
    isCheckedIn,
  ];
}
