enum CheckPoint {
  start,
  offTheBlock,
  breakOut,
  fifteenMeterMark,
  thirthyFiveMeterMark,
  turn,
  finish
}

extension CheckPointDisplay on CheckPoint {
  String toDisplayString() {
    switch (this) {
      case CheckPoint.start:
        return "Start";
      case CheckPoint.offTheBlock:
        return "Left the block";
      case CheckPoint.breakOut:
        return "Breakout";
      case CheckPoint.fifteenMeterMark:
        return "15m Mark";
      case CheckPoint.turn:
        return "Turn";
      case CheckPoint.thirthyFiveMeterMark:
        return "35m Mark";
      case CheckPoint.finish:
        return "Finish";
    }
  }
}

extension CheckPointDistance on CheckPoint {
  /// Returns the OFFICIAL race distance associated with this checkpoint.
  /// Used ONLY for summary tables (NOT precise biomechanical measurement).
  double expectedDistance({
    required int poolLengthMeters, // 25 or 50
    required int raceDistanceMeters, // e.g. 50, 100, 200
  }) {
    switch (this) {
      case CheckPoint.start:
        return 0;

      case CheckPoint.offTheBlock:
      case CheckPoint.breakOut:
        // Summary estimation: breakout occurs ~5m into the race
        return 5;

      case CheckPoint.fifteenMeterMark:
        return 15;

      case CheckPoint.thirthyFiveMeterMark:
        return 35;

      case CheckPoint.turn:
        // A turn occurs at each pool length multiple, except:
        //   - 50m long course race (no turn)
        //
        // Examples:
        //   100 SC → turns at 25, 50, 75
        //   100 LC → turn at 50
        //   50  SC → turn at 25
        //   50  LC → NO turn
        if (raceDistanceMeters == 50 && poolLengthMeters == 50) {
          return 0; // Long course 50m → no turn exists, return neutral
        }

        return poolLengthMeters.toDouble();

      case CheckPoint.finish:
        return raceDistanceMeters.toDouble();
    }
  }
}
