import 'package:flutter/material.dart';

enum BodySide { front, back }

enum MuscleId { arms, chest, abs, legs, shoulders, back, glutes }

extension MuscleIdLabel on MuscleId {
  String get label {
    switch (this) {
      case MuscleId.arms:
        return 'Arms';
      case MuscleId.chest:
        return 'Chest';
      case MuscleId.abs:
        return 'Abs';
      case MuscleId.legs:
        return 'Legs';
      case MuscleId.shoulders:
        return 'Shoulders';
      case MuscleId.back:
        return 'Back';
      case MuscleId.glutes:
        return 'Glutes';
    }
  }
}

class MuscleRegion {
  const MuscleRegion({
    required this.id,
    required this.side,
    required this.pathBuilder,
  });

  final MuscleId id;
  final BodySide side;
  final Path Function(Size size) pathBuilder;

  bool hitTest(Offset point, Size size) => pathBuilder(size).contains(point);
}
