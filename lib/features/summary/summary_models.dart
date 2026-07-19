library;

class WeightLog {
  const WeightLog({required this.at, required this.kg});
  final DateTime at;
  final double kg;
}

class WorkoutLog {
  const WorkoutLog({required this.at, required this.sets, required this.title});
  final DateTime at;
  final int sets;
  final String title;
}

class ChartPoint {
  const ChartPoint({
    required this.label,
    required this.weight,
    required this.metric,
    required this.sets,
    this.date,
  });

  final String label;

  final double? weight;

  final int metric;

  final int sets;

  final DateTime? date;
}

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

class SummaryData {
  SummaryData({required this.weights, required this.workouts});

  final List<WeightLog> weights;

  final List<WorkoutLog> workouts;

  bool get isEmpty => weights.isEmpty && workouts.isEmpty;

  static const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  DateTime _dayEnd(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

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
        (WorkoutLog w) => w.at.year == y && w.at.month == m && w.at.day == day,
      );
      for (final WorkoutLog w in onDay) {
        cumulative += 1;
        cumulativeSets += _setsFor(w);
      }
      pts.add(
        ChartPoint(
          label: '$day',
          weight: weightOn(d),
          metric: cumulative,
          sets: cumulativeSets,
          date: d,
        ),
      );
    }
    return pts;
  }

  List<ChartPoint> yearPoints(DateTime anchor, {DateTime? today}) {
    final DateTime now = today ?? DateTime.now();
    final int y = anchor.year;
    final int upToMonth = y == now.year ? now.month : 12;

    final List<ChartPoint> pts = <ChartPoint>[];
    for (int m = 1; m <= upToMonth; m++) {
      final Iterable<WorkoutLog> inMonth = workouts.where(
        (WorkoutLog w) => w.at.year == y && w.at.month == m,
      );
      final int count = inMonth.length;
      final int sets = inMonth.fold<int>(
        0,
        (int s, WorkoutLog w) => s + _setsFor(w),
      );
      final DateTime monthEnd = DateTime(y, m + 1, 0);
      final DateTime ref = monthEnd.isAfter(now) ? now : monthEnd;
      pts.add(
        ChartPoint(
          label: months[m - 1],
          weight: weightOn(ref),
          metric: count,
          sets: sets,
          date: DateTime(y, m, 15),
        ),
      );
    }
    return pts;
  }

  List<WorkoutLog> sessionsInMonth(DateTime anchor) {
    final List<WorkoutLog> list =
        workouts
            .where(
              (WorkoutLog w) =>
                  w.at.year == anchor.year && w.at.month == anchor.month,
            )
            .toList()
          ..sort((WorkoutLog a, WorkoutLog b) => b.at.compareTo(a.at));
    return list;
  }

  PeriodSummary summarize(List<ChartPoint> points) {
    final List<double> ws = <double>[
      for (final ChartPoint p in points)
        if (p.weight != null) p.weight!,
    ];
    final bool hasWeight = ws.isNotEmpty;
    final double delta = hasWeight ? ws.last - ws.first : 0;

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

  bool _isCumulative(List<ChartPoint> points) {
    for (int i = 1; i < points.length; i++) {
      if (points[i].metric < points[i - 1].metric) return false;
    }

    return points.isNotEmpty && int.tryParse(points.first.label) != null;
  }
}
