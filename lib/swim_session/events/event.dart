import '../../objects/pool_length.dart';
import '../../objects/stroke.dart';
import 'checkpoint.dart';

abstract class Event {
  final Stroke stroke;

  Event({required this.stroke, this.isShortCourse = true});

  bool isShortCourse;

  String get name;

  int get distance;

  PoolLength get poolLength;

  List<CheckPoint> get checkPoints;
}
