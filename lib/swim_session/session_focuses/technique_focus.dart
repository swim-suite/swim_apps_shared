import '../../objects/intensity_zones.dart';
import '../generator/enums/equipment.dart';
import 'training_focus.dart';

class TechniqueFocus extends TrainingFocus {
  @override
  String get name => 'Technique';

  @override
  int get warmUpRatio => 10;
  @override
  int get preSetRatio => 10;
  @override
  int get mainSetRatio => 70;
  @override
  int get coolDownRatio => 10;

  @override
  String get description =>
      'Develop stroke efficiency, control, and balance through focused, low-intensity drills.';
  @override
  String get aiPurpose =>
      'Improve technique precision and body alignment while minimizing fatigue.';
  @override
  String get recommendedSetTypes =>
      'Drill progressions, sculling, kick technique, stroke segments, and underwater control.';
  @override
  List<String> get coachingCues => [
    'long strokes',
    'relaxed tempo',
    'balance and alignment',
    'feel for the water',
    'precision turns',
  ];

  @override
  List<EquipmentType> get recommendedEquipment => [
    EquipmentType.fins,
    EquipmentType.snorkel,
    EquipmentType.paddles,
  ];

  @override
  List<IntensityZone> get preferredIntensityZones => [
    IntensityZone.i1,
    IntensityZone.i2,
  ];

  @override
  List<String> get aiPromptTags => ['technique', 'drills', 'form', 'efficiency'];

  @override
  String generatePrompt() => """
### Training Focus: $name
**Description:** $description
**AI Purpose:** $aiPurpose
**Recommended Set Types:** $recommendedSetTypes
**Preferred Intensity Zones:** ${preferredIntensityZones.map((z) => z.name).join(", ")} (mainly for main set, lightly reflected in warm-up and pre-set)
**Coaching Cues:** ${coachingCues.join(', ')}
**Structure Ratios:** Warm-up $warmUpRatio%, Pre-set $preSetRatio%, Main-set $mainSetRatio%, Cool-down $coolDownRatio%
**Recommended Equipment:** ${recommendedEquipment.map((e) => e.name).join(", ")}

You are generating a **$name-focused swim session** emphasizing technique precision and efficiency.

Guidelines:
- Use ${preferredIntensityZones.map((z) => z.name).join(", ")} zones — mostly low to moderate effort.
- Include drills like ${recommendedSetTypes.toLowerCase()}.
- Warm-up and pre-set should reinforce stroke control and body alignment.
- Keep focus on ${coachingCues.take(3).join(', ')}.

Session Requirements:
- Limit total load to 2000–4000m.
- Return only plain-text workout formatted for textToSessionParser.
""";
}
