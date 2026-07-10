/// Data models + bucketing for the Home "Your progress" summary chart.
///
/// Two real signals are plotted together:
/// - body weight (kg), recorded only occasionally (whenever the user updates
///   it), so it is carried forward day-to-day;
/// - workouts completed (from marking plan days done).
library;

/// A single recorded body-weight reading.
class WeightLog {
  const WeightLog({required this.at, required this.kg});
  final DateTime at;
  final double kg;
}

/// A single completed workout day.
class WorkoutLog {
  const WorkoutLog({required this.at, required this.sets, required this.title});
  final DateTime at;
  final int sets;
  final String title;
}

/// One plotted point on the chart.
class ChartPoint {
  const ChartPoint({
    required this.label,
    required this.weight,
    required this.metric,
    required this.sets,
    this.date,
  });

  /// X-axis label (day number for month view, month name for year view).
  final String label;

  /// Carried-forward weight for this point; null when no reading exists yet.
  final double? weight;

  /// The "workouts" line value — a running total within a month, or the
  /// number of workouts in that month for the year view.
  final int metric;

  /// Total sets represented by this point (for the details panel).
  final int sets;

  /// The calendar date this point anchors to (used to drill down).
  final DateTime? date;
}

/// Summary of one visible period (month or year) for the details panel.
class PeriodSummary {
  const PeriodSummary({
    required this.weightDelta,
    required this.hasWeight,
    required this.totalWorkouts,
    required this.totalSets,
  });

  final double weightDelta;
  final bool hasWeight;
  final int totalWorkouts;
  final int totalSets;
}

/// All of a user's logs, with helpers to bucket them into chart points.
class SummaryData {
  SummaryData({required this.weights, required this.workouts});

  /// Sorted ascending by [WeightLog.at].
  final List<WeightLog> weights;

  /// Sorted ascending by [WorkoutLog.at].
  final List<WorkoutLog> workouts;

  bool get isEmpty => weights.isEmpty && workouts.isEmpty;

  static const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  DateTime _dayEnd(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  /// Latest weight recorded on or before [day]; null if none yet.
  double? weightOn(DateTime day) {
    final DateTime cutoff = _dayEnd(day);
    double? v;
    for (final WeightLog w in weights) {
      if (!w.at.isAfter(cutoff)) {
        v = w.kg;
      } else {
        break;
      }
    }
    return v;
  }

  int _setsFor(WorkoutLog w) => w.sets;

  /// Points for one calendar month (x = day of month), workouts cumulative.
  List<ChartPoint> monthPoints(DateTime anchor, {DateTime? today}) {
    final DateTime now = today ?? DateTime.now();
    final int y = anchor.year, m = anchor.month;
    final int lastDay = DateTime(y, m + 1, 0).day;
    final bool isCurrentMonth = y == now.year && m == now.month;
    final int upTo = isCurrentMonth ? now.day : lastDay;

    final List<ChartPoint> pts = <ChartPoint>[];
    int cumulative = 0;
    int cumulativeSets = 0;
    for (int day = 1; day <= upTo; day++) {
      final DateTime d = DateTime(y, m, day);
      final Iterable<WorkoutLog> onDay = workouts.where(
        (WorkoutLog w) =>
            w.at.year == y && w.at.month == m && w.at.day == day,
      );
      for (final WorkoutLog w in onDay) {
        cumulative += 1;
        cumulativeSets += _setsFor(w);
      }
      pts.add(ChartPoint(
        label: '$day',
        weight: weightOn(d),
        metric: cumulative,
        sets: cumulativeSets,
        date: d,
      ));
    }
    return pts;
  }

  /// Points for one calendar year (x = month), workouts counted per month.
  List<ChartPoint> yearPoints(DateTime anchor, {DateTime? today}) {
    final DateTime now = today ?? DateTime.now();
    final int y = anchor.year;
    final int upToMonth = y == now.year ? now.month : 12;

    final List<ChartPoint> pts = <ChartPoint>[];
    for (int m = 1; m <= upToMonth; m++) {
      final Iterable<WorkoutLog> inMonth =
          workouts.where((WorkoutLog w) => w.at.year == y && w.at.month == m);
      final int count = inMonth.length;
      final int sets =
          inMonth.fold<int>(0, (int s, WorkoutLog w) => s + _setsFor(w));
      final DateTime monthEnd = DateTime(y, m + 1, 0);
      final DateTime ref = monthEnd.isAfter(now) ? now : monthEnd;
      pts.add(ChartPoint(
        label: months[m - 1],
        weight: weightOn(ref),
        metric: count,
        sets: sets,
        date: DateTime(y, m, 15),
      ));
    }
    return pts;
  }

  /// Workout sessions inside one calendar month, newest first.
  List<WorkoutLog> sessionsInMonth(DateTime anchor) {
    final List<WorkoutLog> list = workouts
        .where((WorkoutLog w) =>
            w.at.year == anchor.year && w.at.month == anchor.month)
        .toList()
      ..sort((WorkoutLog a, WorkoutLog b) => b.at.compareTo(a.at));
    return list;
  }

  /// Aggregates for the details panel of the given points.
  PeriodSummary summarize(List<ChartPoint> points) {
    final List<double> ws = <double>[
      for (final ChartPoint p in points)
        if (p.weight != null) p.weight!,
    ];
    final bool hasWeight = ws.isNotEmpty;
    final double delta = hasWeight ? ws.last - ws.first : 0;

    // Month view stores cumulative metric/sets (take the last point); year view
    // stores per-month values (sum them).
    final bool cumulative = _isCumulative(points);
    final int totalWorkouts = points.isEmpty
        ? 0
        : (cumulative
            ? points.last.metric
            : points.fold<int>(0, (int s, ChartPoint p) => s + p.metric));
    final int totalSets = points.isEmpty
        ? 0
        : (cumulative
            ? points.last.sets
            : points.fold<int>(0, (int s, ChartPoint p) => s + p.sets));

    return PeriodSummary(
      weightDelta: (delta * 10).roundToDouble() / 10,
      hasWeight: hasWeight,
      totalWorkouts: totalWorkouts,
      totalSets: totalSets,
    );
  }

  /// Month view stores cumulative values; year view stores per-bucket values.
  bool _isCumulative(List<ChartPoint> points) {
    // Cumulative series never decreases.
    for (int i = 1; i < points.length; i++) {
      if (points[i].metric < points[i - 1].metric) return false;
    }
    // A month view has day-number labels ("1".."31"); year view has month names.
    return points.isNotEmpty && int.tryParse(points.first.label) != null;
  }
}
