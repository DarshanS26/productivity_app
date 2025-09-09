import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'task.g.dart';

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
  final int plannedHours;

  @HiveField(6)
  String? completionDescription;

  @HiveField(7)
  int? rating;

  @HiveField(8)
  double? actualHours;

  Task({
    required this.id,
    required this.title,
    this.isDone = false,
    required this.createdAt,
    this.dueTime,
    this.plannedHours = 0,
    this.completionDescription,
    this.rating,
    this.actualHours,
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
      plannedHours: json['plannedHours'] as int? ?? 0,
      completionDescription: json['completionDescription'] as String?,
      rating: json['rating'] as int?,
      actualHours: json['actualHours'] != null ? (json['actualHours'] as num).toDouble() : null,
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
    };
  }
}
