import '../../objects/pool_length.dart';
import 'checkpoint.dart';
import 'event.dart';

class TwentyFiveMeterRace extends Event {
  final bool fromDive;

  TwentyFiveMeterRace({
    required super.stroke,
    this.fromDive = true,
  });

  @override
  String get name => '25m ${stroke.description}';

  @override
  int get distance => 25;

  @override
  PoolLength get poolLength => PoolLength.m25;

  @override
  List<CheckPoint> get checkPoints {
    final checkpoints = <CheckPoint>[];

    // --- Start ---
    if (fromDive) {
      checkpoints.add(CheckPoint.start);
    }

    checkpoints.add(CheckPoint.offTheBlock);
    checkpoints.add(CheckPoint.waterEntry);

    // --- Underwater & finish ---
    checkpoints.addAll([
      CheckPoint.breakout,
      CheckPoint.meter10,
      CheckPoint.meter15,
      CheckPoint.meter15,
      CheckPoint.finish,
    ]);

    return checkpoints;
  }
}
