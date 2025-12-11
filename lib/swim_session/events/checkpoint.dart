enum CheckPoint {
  start,
  offTheBlock,
  breakOut,
  fifteenMeterMark,
  twentyFiveMeterMark,
  thirtyFiveMeterMark,
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
      case CheckPoint.twentyFiveMeterMark:
        return "25m Mark";
      case CheckPoint.thirtyFiveMeterMark:
        return "35m Mark";
      case CheckPoint.turn:
        return "Turn";
      case CheckPoint.finish:
        return "Finish";
    }
  }
}

extension CheckPointDistance on CheckPoint {
  /// Returns the OFFICIAL summary distance for this checkpoint.
  /// NOTE: This is NOT used for breakout interpolation (that uses precise timing).
  double expectedDistance({
    required int poolLengthMeters, // 25 or 50
    required int raceDistanceMeters, // 50, 100, 200, etc.
  }) {
    switch (this) {
      case CheckPoint.start:
        return 0.0;

      case CheckPoint.offTheBlock:
      case CheckPoint.breakOut:
    // Standard estimation for reporting (not biomechanical)
      return 5.0;

      case CheckPoint.fifteenMeterMark:
        return 15.0;

      case CheckPoint.twentyFiveMeterMark:
        return 25.0;

      case CheckPoint.thirtyFiveMeterMark:
        return 35.0;

      case CheckPoint.turn:
      // A turn occurs at each poolLength multiple EXCEPT:
      //   LC 50m races → no turn
      //
      // Examples:
      //   50 SC → turn at 25
      //   50 LC → no turn
      //   100 SC → turn at 25, 50, 75
      //   100 LC → turn at 50 only
        if (raceDistanceMeters == 50 && poolLengthMeters == 50) {
          return 0.0; // LC 50m → no turn
        }

        return poolLengthMeters.toDouble();

      case CheckPoint.finish:
        return raceDistanceMeters.toDouble();
    }
  }
}
