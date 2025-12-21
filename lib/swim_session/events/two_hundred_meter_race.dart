import '../../objects/pool_length.dart';
import 'checkpoint.dart';
import 'event.dart';

class TwoHundredMeterRace extends Event {
  TwoHundredMeterRace({required super.stroke});

  @override
  String get name => '200m ${stroke.description}';

  @override
  int get distance => 200;

  @override
  PoolLength get poolLength => PoolLength.m25;

  @override
  List<CheckPoint> get checkPoints {
    final checkpoints = <CheckPoint>[
      // --- Start ---
      CheckPoint.start,
      CheckPoint.offTheBlock,
      CheckPoint.breakout,
      CheckPoint.meter15,
    ];

    // --- Turns at 25m → 175m (7 turns) ---
    for (int i = 0; i < 7; i++) {
      checkpoints.addAll([
        CheckPoint.turn,
        CheckPoint.breakout,
        CheckPoint.meter15,
      ]);
    }

    // --- Finish ---
    checkpoints.add(CheckPoint.finish);

    return checkpoints;
  }
}
