import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'task.g.dart';
part 'history_entry.g.dart';
part 'journal_entry.g.dart';
part 'archived_task.g.dart';

@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  bool isDone;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final TimeOfDay? dueTime;

  @HiveField(5)
  final double plannedHours;

  @HiveField(6)
  String? completionDescription;

  @HiveField(7)
  int? rating;

  @HiveField(8)
  double? actualHours;

  @HiveField(9)
  DateTime? completedAt;

  Task({
    required this.id,
    required this.title,
    this.isDone = false,
    required this.createdAt,
    this.dueTime,
    this.plannedHours = 0.0,
    this.completionDescription,
    this.rating,
    this.actualHours,
    this.completedAt,
  });

  // JSON serialization
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      isDone: json['isDone'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      dueTime: json['dueTime'] != null
          ? TimeOfDay(
              hour: int.parse((json['dueTime'] as String).split(':')[0]),
              minute: int.parse((json['dueTime'] as String).split(':')[1]),
            )
          : null,
      plannedHours: (json['plannedHours'] as num?)?.toDouble() ?? 0.0,
      completionDescription: json['completionDescription'] as String?,
      rating: json['rating'] as int?,
      actualHours: json['actualHours'] != null ? (json['actualHours'] as num).toDouble() : null,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isDone': isDone,
      'createdAt': createdAt.toIso8601String(),
      'dueTime': dueTime != null ? '${dueTime!.hour}:${dueTime!.minute}' : null,
      'plannedHours': plannedHours,
      'completionDescription': completionDescription,
      'rating': rating,
      'actualHours': actualHours,
      'completedAt': completedAt?.toIso8601String(),
    };
  }
}

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

@HiveType(typeId: 1)
class JournalEntry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String content;

  @HiveField(2)
  final DateTime createdAt;

  JournalEntry({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  // JSON serialization
  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

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
  final double plannedHours;

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