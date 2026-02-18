import 'package:swim_apps_shared/objects/user/swimmer.dart';

enum Stroke {
  butterfly('Butterfly', 'bu'),
  freestyle('Freestyle', 'fr'),
  backstroke('Backstroke', 'ba'),
  breaststroke('Breaststroke', 'br'),
  medley('Medley', 'IM'),
  choice('Choice', 'c'),
  unknown('Unknown', 'unknown'),
  bestStroke('Best stroke', 'best');

  final String description;
  final String short;

  const Stroke(this.description, this.short);

  // Helper to get Stroke from string name (for fromJson)
  static Stroke? fromString(String? name) {
    if (name == null) return null;
    try {
      return Stroke.values.firstWhere((e) => e.name == name);
    } catch (e) {
      return null; // Or a default, or rethrow
    }
  }

  // 🔥 The proper way: returns a Set
  static Set<Stroke> get all => {
    Stroke.butterfly,
    Stroke.freestyle,
    Stroke.backstroke,
    Stroke.breaststroke,
    Stroke.medley,
  };
}

extension StrokeParsingHelper on Stroke {
  List<String> get parsingKeywords {
    switch (this) {
      case Stroke.freestyle:
        return ['freestyle', 'free', 'fr'];
      case Stroke.backstroke:
        return ['backstroke', 'back', 'bk'];
      case Stroke.breaststroke:
        return ['breaststroke', 'breast', 'br'];
      case Stroke.butterfly:
        return ['butterfly', 'fly', 'bu', 'bf'];
      case Stroke.medley:
        return ['im', 'i.m.', 'medley', 'individual medley', 'me'];
      case Stroke.choice:
        return ['choice', 'ch', 'c'];
      case Stroke.unknown:
        return ['uk', 'unknown'];
      case Stroke.bestStroke:
        return ['best', 'best stroke'];
    }
  }
}

extension StrokeResolution on Stroke {
  Stroke resolveForSwimmer(Swimmer swimmer) {
    if (this != Stroke.bestStroke) return this;
    final primary = swimmer.primaryStroke;
    if (primary == null || primary == Stroke.bestStroke) {
      return Stroke.freestyle;
    }
    return primary;
  }
}

extension StrokeDisplayName on Stroke {
  String get displayName {
    if (this == Stroke.bestStroke) return 'Best stroke';
    return description;
  }
}
