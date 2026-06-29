import 'package:flutter/material.dart';

import '../planner/models/workout_plan_models.dart';
import '../tutorial/exercise_catalog.dart';
import '../tutorial/muscle_models.dart';

const Color _kPrimaryColor = Color(0xFF4CAF50);

Future<PlanExercise?> showExercisePickerSheet(BuildContext context) {
  return showModalBottomSheet<PlanExercise>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) => const _ExercisePickerSheet(),
  );
}

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet();

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  MuscleId? _selectedMuscle;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TutorialExercise> get _filteredExercises {
    Iterable<TutorialExercise> list = allTutorialExercises;
    if (_selectedMuscle != null) {
      list = list.where((TutorialExercise e) => e.muscle == _selectedMuscle);
    }
    if (_query.isNotEmpty) {
      final String lower = _query.toLowerCase();
      list = list.where(
        (TutorialExercise e) => e.title.toLowerCase().contains(lower),
      );
    }
    return list.toList()
      ..sort((TutorialExercise a, TutorialExercise b) =>
          a.title.compareTo(b.title));
  }

  void _selectExercise(TutorialExercise exercise) {
    Navigator.of(context).pop(
      PlanExercise(
        exerciseId: exercise.id,
        title: exercise.title,
        setsLabel: exercise.subtitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return SizedBox(
      height: maxHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Add exercise',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search exercises',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (String value) =>
                  setState(() => _query = value.trim()),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _selectedMuscle == null,
                    onSelected: (_) => setState(() => _selectedMuscle = null),
                    selectedColor: _kPrimaryColor.withValues(alpha: 0.2),
                    checkmarkColor: _kPrimaryColor,
                  ),
                ),
                for (final MuscleId muscle in MuscleId.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(muscle.label),
                      selected: _selectedMuscle == muscle,
                      onSelected: (_) =>
                          setState(() => _selectedMuscle = muscle),
                      selectedColor: _kPrimaryColor.withValues(alpha: 0.2),
                      checkmarkColor: _kPrimaryColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: _filteredExercises.length,
              itemBuilder: (BuildContext context, int index) {
                final TutorialExercise exercise = _filteredExercises[index];
                return ListTile(
                  title: Text(exercise.title),
                  subtitle: Text(exercise.subtitle),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => _selectExercise(exercise),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
