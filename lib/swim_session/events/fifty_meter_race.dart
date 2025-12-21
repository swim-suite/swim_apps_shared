import '../../objects/pool_length.dart';
import 'checkpoint.dart';
import 'event.dart';

class FiftyMeterRace extends Event {
  final bool fromDive;

  /// true = 25m (short course), false = 50m (long course)

  FiftyMeterRace({
    required super.stroke,
    required super.isShortCourse,
    this.fromDive = true,
  });

  @override
  String get name => '50m ${stroke.description}';

  @override
  int get distance => 50;

  @override
  PoolLength get poolLength => isShortCourse ? PoolLength.m25 : PoolLength.m50;

  @override
  List<CheckPoint> get checkPoints {
    // --- Start sequence ---
    final startSeq = fromDive
        ? [
            CheckPoint.start,
            CheckPoint.offTheBlock,
            CheckPoint.waterEntry,
          ]
        : [
            CheckPoint.offTheBlock,
          ];

    // --- First underwater phase ---
    final firstUnderwater = [
      CheckPoint.breakout,
      CheckPoint.meter10,
      CheckPoint.meter15,
      CheckPoint.meter20,
      CheckPoint.meter25,
    ];

    // --- Turn sequence (short course only) ---
    final turnSeq = [
      CheckPoint.turn,
      CheckPoint.breakout,
      CheckPoint.meter10,
      CheckPoint.meter15,
      CheckPoint.meter20,
    ];

    // --- Long course mid-pool reference ---
    final longCourseMarks = [
      CheckPoint.meter25,
      CheckPoint.meter35,
      CheckPoint.meter40,
      CheckPoint.meter45,
    ];

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
            // ⛔ No turn in 50m long course
            ...longCourseMarks,
            ...finishSeq,
          ];
  }
}
