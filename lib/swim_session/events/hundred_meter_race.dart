import '../../objects/pool_length.dart';
import 'checkpoint.dart';
import 'event.dart';

class HundredMetersRace extends Event {
  HundredMetersRace({
    required super.stroke,
    required super.isShortCourse,
  });

  @override
  String get name => '100m ${stroke.description}';

  @override
  int get distance => 100;

  @override
  PoolLength get poolLength => PoolLength.m25;

  @override
  List<CheckPoint> get checkPoints {
    final checkpoints = <CheckPoint>[
      // --- Start length ---
      CheckPoint.start,
      CheckPoint.offTheBlock,
      CheckPoint.waterEntry,
      CheckPoint.breakout,
      CheckPoint.meter10,
      CheckPoint.meter15,
      CheckPoint.meter20,
      CheckPoint.meter25,
    ];

    // --- Turns at 25m, 50m, 75m ---
    for (int i = 0; i < 3; i++) {
      checkpoints.addAll([
        CheckPoint.turn,
        CheckPoint.waterEntry,
        CheckPoint.breakout,
        CheckPoint.meter10,
        CheckPoint.meter15,
        CheckPoint.meter20,
      ]);
    }

    // --- Finish length ---
    checkpoints.addAll([
      CheckPoint.meter10,
      CheckPoint.meter15,
      CheckPoint.meter20,
      CheckPoint.finish,
    ]);

    return checkpoints;
  }
}
