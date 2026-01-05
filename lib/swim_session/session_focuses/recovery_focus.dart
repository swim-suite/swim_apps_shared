import '../../objects/intensity_zones.dart';
import '../generator/enums/equipment.dart';
import 'training_focus.dart';

class RecoveryFocus extends TrainingFocus {
  @override
  String get name => 'Recovery';

  @override
  int get warmUpRatio => 30;
  @override
  int get preSetRatio => 10;
  @override
  int get mainSetRatio => 40;
  @override
  int get coolDownRatio => 20;

  @override
  String get description =>
      'Facilitate active recovery, promote circulation, and restore movement quality.';
  @override
  String get aiPurpose =>
      'Support muscle regeneration and relaxation while reinforcing efficient technique.';
  @override
  String get recommendedSetTypes =>
      'Easy aerobic swims, mixed-stroke drills, light kick sets, and long pull sets.';
  @override
  List<String> get coachingCues => [
    'relaxed breathing',
    'smooth strokes',
    'loose shoulders',
    'steady rhythm',
  ];

  @override
  List<EquipmentType> get recommendedEquipment => [
    EquipmentType.fins,
    EquipmentType.snorkel,
  ];

  @override
  List<IntensityZone> get preferredIntensityZones => [
    IntensityZone.i1,
    IntensityZone.i3,
  ];

  @override
  List<String> get aiPromptTags => ['recovery', 'aerobic', 'relaxation', 'drills'];

  @override
  String generatePrompt() => """
### Training Focus: $name
**Description:** $description
**AI Purpose:** $aiPurpose
**Recommended Set Types:** $recommendedSetTypes
**Preferred Intensity Zones:** ${preferredIntensityZones.map((z) => z.name).join(", ")} (main set and throughout warm-up/pre-set)
**Coaching Cues:** ${coachingCues.join(', ')}
**Structure Ratios:** Warm-up $warmUpRatio%, Pre-set $preSetRatio%, Main-set $mainSetRatio%, Cool-down $coolDownRatio%
**Recommended Equipment:** ${recommendedEquipment.map((e) => e.name).join(", ")}

You are generating a **$name-focused swim session** centered on light movement and restoration.

Guidelines:
- Maintain ${preferredIntensityZones.map((z) => z.name).join(", ")} effort — easy and controlled.
- Include technique work and drills for efficiency.
- Use equipment for assistance and posture control.
- Focus on ${coachingCues.take(2).join(' and ')}.
- Keep total volume between 1500–3000m.

Session Requirements:
- Avoid fatigue accumulation.
- Maintain flow and smooth rhythm throughout.
- Return only plain-text workout formatted for textToSessionParser.
""";
}
