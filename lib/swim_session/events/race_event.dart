import '../../objects/pool_length.dart';
import '../../objects/stroke.dart';

class RaceEvent {
  final Stroke stroke;
  final int distance;
  final PoolLength poolLength;

  // Context
  final bool isCompetition;
  final bool withDive;
  final bool relayStart;

  // Optional metadata
  final Gender gender;
  final String? ageGroup;
  final RaceRound round;
  final int? lane;

  bool get isShortCourse => poolLength == PoolLength.m25;

  bool get isLongCourse => poolLength == PoolLength.m50;

  RaceEvent({
    required this.stroke,
    required this.distance,
    required this.poolLength,
    this.isCompetition = true,
    this.withDive = true,
    this.relayStart = false,
    this.gender = Gender.unknown,
    this.ageGroup,
    this.round = RaceRound.heatEvent,
    this.lane,
  }) : assert(!(withDive && relayStart),
            'Race cannot start with both dive and relay start');

  String get name => '${distance}m ${stroke.description}';
}

enum Gender { male, female, mixed, unknown }

enum RaceRound { heatEvent, semifinalEvent, finalEvent, timeTrial }
