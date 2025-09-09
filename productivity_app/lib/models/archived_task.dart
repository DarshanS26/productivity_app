import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'archived_task.g.dart';

@HiveType(typeId: 3)
class ArchivedTask {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final bool isDone;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final TimeOfDay? dueTime;

  @HiveField(5)
  final int plannedHours;

  @HiveField(6)
  final String? completionDescription;

  @HiveField(7)
  final int? rating;

  ArchivedTask({
    required this.id,
    required this.title,
    required this.isDone,
    required this.createdAt,
    this.dueTime,
    required this.plannedHours,
    this.completionDescription,
    this.rating,
  });
}