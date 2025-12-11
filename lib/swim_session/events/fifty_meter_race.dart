import '../../objects/pool_length.dart';
import 'checkpoint.dart';
import 'event.dart';

class FiftyMeterRace extends Event {
  final bool fromDive;

  /// true = 25m (short course), false = 50m (long course)
  final bool isShortCourse;

  const FiftyMeterRace({
    required super.stroke,
    this.fromDive = true,
    this.isShortCourse = true,
  });

  @override
  String get name => '50m ${stroke.description}';

  @override
  int get distance => 50;

  @override
  PoolLength get poolLength => isShortCourse ? PoolLength.m25 : PoolLength.m50;

  @override
  List<CheckPoint> get checkPoints {
    // Common beginning (depends on dive)
    final startSeq = fromDive
        ? [
            CheckPoint.start,
            CheckPoint.offTheBlock,
          ]
        : [
            CheckPoint.offTheBlock,
          ];

    final firstUnderwater = [
      CheckPoint.breakOut,
      CheckPoint.fifteenMeterMark,
    ];

    // If short course → include turn + second breakout
    final turnSeq = [
      CheckPoint.turn,
      CheckPoint.breakOut,
      CheckPoint.fifteenMeterMark,
    ];

    final second = [CheckPoint.thirthyFiveMeterMark];

    final finishSeq = [
      CheckPoint.finish,
    ];

    return isShortCourse
        ? [
            ...startSeq,
            ...firstUnderwater,
            ...turnSeq,
            ...finishSeq,
          ]
        : [
            ...startSeq,
            ...firstUnderwater,
            // ⛔ long course = NO turn
            ...second,
            ...finishSeq,
          ];
  }
}
