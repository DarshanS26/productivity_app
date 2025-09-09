import 'package:hive/hive.dart';

part 'history_entry.g.dart';

@HiveType(typeId: 2)
class HistoryEntry extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  double actualHours;

  // A list of maps is a simple and robust way to store task data
  // without needing complex sub-adapters.
  @HiveField(2)
  List<Map> tasks;

  HistoryEntry({
    required this.date,
    this.actualHours = 0.0,
    List<Map>? tasks,
  }) : tasks = tasks ?? [];

  // Computed properties from the list of maps
  int get tasksAdded => tasks.length;
  int get tasksCompleted => tasks.where((t) => t['isDone'] as bool).length;
  double get plannedHours => tasks.fold(0.0, (sum, t) => sum + (t['plannedHours'] as num));
}
