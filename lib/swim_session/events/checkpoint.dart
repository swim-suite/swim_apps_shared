enum CheckPoint {
  // --- Events ---
  start,
  offTheBlock,
  waterEntry,
  breakout,
  turn,
  finish,

  // --- Distance marks ---
  meter5,
  meter10,
  meter15,
  meter20,
  meter25,
  meter35,
  meter40,
  meter45,
}

extension CheckPointDisplay on CheckPoint {
  String toDisplayString() {
    switch (this) {
      case CheckPoint.start:
        return "Start";
      case CheckPoint.offTheBlock:
        return "Off the block";
      case CheckPoint.waterEntry:
        return "Water entry";
      case CheckPoint.breakout:
        return "Breakout";
      case CheckPoint.turn:
        return "Turn";
      case CheckPoint.finish:
        return "Finish";

      case CheckPoint.meter5:
        return "5 m";
      case CheckPoint.meter10:
        return "10 m";
      case CheckPoint.meter15:
        return "15 m";
      case CheckPoint.meter20:
        return "20 m";
      case CheckPoint.meter25:
        return "25 m";
      case CheckPoint.meter35:
        return "35 m";
      case CheckPoint.meter40:
        return "40 m";
      case CheckPoint.meter45:
        return "45 m";
    }
  }
}

extension CheckPointDistance on CheckPoint {
  /// Returns the OFFICIAL summary distance for this checkpoint.
  /// Used for reporting & UI (NOT for precise interpolation).
  double expectedDistance({
    required int poolLengthMeters, // 25 or 50
    required int raceDistanceMeters, // 50, 100, 200, etc.
  }) {
    switch (this) {
      case CheckPoint.start:
        return 0.0;

      case CheckPoint.offTheBlock:
      case CheckPoint.waterEntry:
      case CheckPoint.breakout:
        // Conservative, neutral reporting distance
        return 5.0;

      case CheckPoint.meter5:
        return 5.0;
      case CheckPoint.meter10:
        return 10.0;
      case CheckPoint.meter15:
        return 15.0;
      case CheckPoint.meter20:
        return 20.0;
      case CheckPoint.meter25:
        return 25.0;
      case CheckPoint.meter35:
        return 35.0;
      case CheckPoint.meter40:
        return 40.0;
      case CheckPoint.meter45:
        return 45.0;

      case CheckPoint.turn:
        // No turn in 50 LC
        if (raceDistanceMeters == 50 && poolLengthMeters == 50) {
          return 0.0;
        }
        return poolLengthMeters.toDouble();

      case CheckPoint.finish:
        return raceDistanceMeters.toDouble();
    }
  }
}
