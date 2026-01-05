import 'package:flutter/material.dart';

enum IntensityZone { max, sp3, sp2, sp1, i4, i3, i2, i1, racePace }

extension IntensityZonesColoring on IntensityZone {
  Color intensityColor() {
    switch (this) {
      case IntensityZone.max:
        return Colors.red;
      case IntensityZone.sp3:
        return Colors.redAccent;
      case IntensityZone.sp2:
        return Colors.purple;
      case IntensityZone.sp1:
        return Colors.purpleAccent;
      case IntensityZone.i4:
        return Colors.purpleAccent.withBlue(10);
        case IntensityZone.i3:
        return Colors.cyanAccent;
      case IntensityZone.i2:
        return Colors.cyan;
      case IntensityZone.i1:
        return Colors.blue;
      case IntensityZone.racePace:
        return Colors.orange;
    }
  }
}

extension IntensityZoneHeartRate on IntensityZone {
  /// Returns a pair of (minPercent, maxPercent) of HRmax for the intensity zone.
  /// These are general estimations and can vary.
  (int, int) get hrMaxPercentRange {
    switch (this) {
      case IntensityZone.i1: // Very light activity, active recovery
        return (50, 65);
      case IntensityZone.i2: // Light to moderate aerobic, endurance base
        return (65, 75);
      case IntensityZone.i3: // Moderate to vigorous aerobic, building aerobic fitness, "tempo"
        return (75, 85);
      case IntensityZone.i4: // Vigorous to very hard, anaerobic threshold / VO2 max
        return (85, 95);
      case IntensityZone.sp1: // Sprint endurance, very hard, above anaerobic threshold
        return (90, 98); // Can overlap with i4 and sp2, depends on duration
      case IntensityZone.sp2: // Shorter sprints, very hard
        return (92, 100);
      case IntensityZone.sp3: // Max effort sprints, extremely hard
        return (95, 100);
      case IntensityZone.max: // All-out maximal effort, peak HR
        return (98, 100);
      case IntensityZone.racePace: // Dependent on race distance, but generally high
      // For longer races, it might be closer to i3/i4. For sprints, closer to sp2/sp3/max.
      // This is a broad estimate assuming sustained race effort.
        return (85, 100);
    }
  }

  /// Returns a descriptive string for the HR zone.
  String get hrZoneDescription {
    switch (this) {
      case IntensityZone.i1:
        return "Zone 1 (Recovery): 50-65% HRmax. Very light activity, helps recovery.";
      case IntensityZone.i2:
        return "Zone 2 (Endurance Base): 65-75% HRmax. Builds endurance, burns fat.";
      case IntensityZone.i3:
        return "Zone 3 (Aerobic/Tempo): 75-85% HRmax. Improves aerobic fitness and lactate threshold.";
      case IntensityZone.i4:
        return "Zone 4 (Threshold/VO2 Max): 85-95% HRmax. Increases max performance capacity.";
      case IntensityZone.sp1:
        return "SP1 (Sprint Endurance): 90-98% HRmax. Improves ability to sustain high speeds.";
      case IntensityZone.sp2:
        return "SP2 (Speed Work): 92-100% HRmax. Develops speed and power.";
      case IntensityZone.sp3:
        return "SP3 (Max Speed/Power): 95-100% HRmax. Peak speed development.";
      case IntensityZone.max:
        return "MAX (Maximal Effort): 98-100% HRmax. All-out short bursts.";
      case IntensityZone.racePace:
        return "Race Pace: 85-100% HRmax (varies by distance). Simulates race conditions.";
    }
  }
}

@Deprecated('will be replaced by IntensityTerminology')
extension IntensityZoneParsingHelper on IntensityZone {
  // Renamed
  String toShortString() {
    // Used for output, but parser needs to recognize various inputs
    // This MUST match how you want it displayed AND one of the ways it can be parsed
    switch (this) {
      case IntensityZone.i1:
        return "EN1";
      case IntensityZone.i2:
        return "EN2";
      case IntensityZone.i3:
        return "EN3";
      case IntensityZone.sp1:
        return "SP1";
      case IntensityZone.sp2:
        return "SP2";
      case IntensityZone.sp3:
        return "SP3";
      case IntensityZone.max:
        return "MAX";
      case IntensityZone.racePace:
        return "RACE_PACE";
      case IntensityZone.i4:
        return 'EN4';
    }
  }

  List<String> get parsingKeywords {
    // Keywords to recognize this intensity
    List<String> keywords = [name.toLowerCase(), toShortString().toLowerCase()];
    if (name.startsWith("zone")) {
      keywords.add(name.replaceAll("zone", "z").toLowerCase()); // z1, z2
      keywords.add("zone ${name.substring(4)}"); // zone 1, zone 2
    }
    // Add other common aliases if needed
    if (this == IntensityZone.max) keywords.addAll(["race pace", "rp"]);
    return keywords.toSet().toList(); // Ensure unique
  }
}

extension IntensitySorting on IntensityZone {
  int get sortOrder {
    switch (this) {
      case IntensityZone.i1:
        return 1;
      case IntensityZone.i2:
        return 2;
      case IntensityZone.i3:
        return 3;
      case IntensityZone.i4:
        return 4;
      case IntensityZone.racePace:
        return 5;
      case IntensityZone.sp1:
        return 6;
      case IntensityZone.sp2:
        return 7;
      case IntensityZone.sp3:
        return 8;
      case IntensityZone.max:
        return 9;
    }
  }
}
