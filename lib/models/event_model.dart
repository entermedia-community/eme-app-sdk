/// The signed-in user's response to an event.
enum EventRsvp {
  none,
  interested,
  going;

  static EventRsvp parse(Object? value) {
    switch (value?.toString().toLowerCase()) {
      case 'interested':
        return EventRsvp.interested;
      case 'going':
        return EventRsvp.going;
      default:
        return EventRsvp.none;
    }
  }
}

/// An event (`collectiveevent`) from `emeevent/events.json`.
class EventModel {
  final String id;
  final String name;
  final String description;
  final String location;
  final String? imageUrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? hostId;
  final String? hostName;
  final int goingCount;
  final int interestedCount;
  final EventRsvp myRsvp;

  const EventModel({
    required this.id,
    required this.name,
    this.description = '',
    this.location = '',
    this.imageUrl,
    this.startDate,
    this.endDate,
    this.hostId,
    this.hostName,
    this.goingCount = 0,
    this.interestedCount = 0,
    this.myRsvp = EventRsvp.none,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final value = json[key]?.toString() ?? '';
      return value.isEmpty ? null : value;
    }

    return EventModel(
      id: json['id']?.toString() ?? '',
      name: text('name') ?? '',
      description: text('description') ?? '',
      location: text('location') ?? '',
      imageUrl: text('imageurl'),
      startDate: DateTime.tryParse(text('startdate') ?? ''),
      endDate: DateTime.tryParse(text('enddate') ?? ''),
      hostId: text('hostid'),
      hostName: text('hostname'),
      goingCount: int.tryParse('${json['goingcount'] ?? ''}') ?? 0,
      interestedCount: int.tryParse('${json['interestedcount'] ?? ''}') ?? 0,
      myRsvp: EventRsvp.parse(json['myrsvp']),
    );
  }

  EventModel copyWith({
    int? goingCount,
    int? interestedCount,
    EventRsvp? myRsvp,
  }) {
    return EventModel(
      id: id,
      name: name,
      description: description,
      location: location,
      imageUrl: imageUrl,
      startDate: startDate,
      endDate: endDate,
      hostId: hostId,
      hostName: hostName,
      goingCount: goingCount ?? this.goingCount,
      interestedCount: interestedCount ?? this.interestedCount,
      myRsvp: myRsvp ?? this.myRsvp,
    );
  }
}

/// Result of `emeevent/rsvp.json`: the fresh counts and the user's response.
class EventRsvpResult {
  final int goingCount;
  final int interestedCount;
  final EventRsvp myRsvp;

  const EventRsvpResult({
    required this.goingCount,
    required this.interestedCount,
    required this.myRsvp,
  });

  factory EventRsvpResult.fromJson(Map<String, dynamic> json) {
    return EventRsvpResult(
      goingCount: int.tryParse('${json['goingcount'] ?? ''}') ?? 0,
      interestedCount: int.tryParse('${json['interestedcount'] ?? ''}') ?? 0,
      myRsvp: EventRsvp.parse(json['myrsvp']),
    );
  }
}
