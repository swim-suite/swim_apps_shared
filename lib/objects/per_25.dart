/// Helper container for 25m metric results
class Per25mMetrics {
  final List<int> strokes;
  final List<double> frequencies;
  final List<double> lengths;

  Per25mMetrics({
    required this.strokes,
    required this.frequencies,
    required this.lengths,
  });
}
