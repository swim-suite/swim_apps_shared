import 'package:swim_apps_shared/objects/stroke.dart';
import 'package:swim_apps_shared/training_results/training_result_set.dart';

abstract class TrainingResultRepository {
  Future<void> saveResultSet(TrainingResultSet resultSet);

  Stream<List<TrainingResultSet>> getResultsForSwimmer(
    String clubId,
    String swimmerId,
  );

  Stream<List<TrainingResultSet>> queryResults({
    required String clubId,
    String? swimmerId,
    Stroke? stroke,
    int? distance,
    int? intensity,
    DateTime? from,
    DateTime? to,
  });
}
