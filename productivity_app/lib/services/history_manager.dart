
//import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:productivity_app/models/task.dart';
import 'package:productivity_app/models/history_entry.dart';

class HistoryManager {
  static const String _lastRunKey = 'lastRun';

  static Future<void> moveTasksToHistoryIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRunString = prefs.getString(_lastRunKey);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (lastRunString != null) {
        final lastRun = DateTime.parse(lastRunString);
        if (lastRun.isAtSameMomentAs(today)) {
          final historyBox = Hive.box<HistoryEntry>('historyBox');
          final hasTodayEntry = historyBox.values.any((entry) => entry.date.isAtSameMomentAs(today));
          if (!hasTodayEntry) {
            await historyBox.add(HistoryEntry(date: today));
          }
          return;
        }
      }

      final tasksBox = Hive.box<Task>('tasks');
      final historyBox = Hive.box<HistoryEntry>('historyBox');
      final allTasks = tasksBox.values.toList();

    final Map<DateTime, List<Task>> oldTasksByDate = {};
    final List<Task> tasksToDelete = [];

    for (final task in allTasks) {
      final taskDate = DateTime(task.createdAt.year, task.createdAt.month, task.createdAt.day);
      if (taskDate.isBefore(today)) {
        if (oldTasksByDate[taskDate] == null) {
          oldTasksByDate[taskDate] = [];
        }
        oldTasksByDate[taskDate]!.add(task);
        tasksToDelete.add(task);
      }
    }

    if (oldTasksByDate.isNotEmpty) {
      for (final entry in oldTasksByDate.entries) {
        final date = entry.key;
        final tasks = entry.value;
        
        final archivedTasks = tasks.map((task) => task.toMap()).toList();

        final existingEntryIndex = historyBox.values.toList().indexWhere((e) => e.date.isAtSameMomentAs(date));

        if (existingEntryIndex != -1) {
          final existingEntry = historyBox.getAt(existingEntryIndex) as HistoryEntry;
          existingEntry.tasks.addAll(archivedTasks);
          await existingEntry.save();
        } else {
          final newHistoryEntry = HistoryEntry(
            date: date,
            tasks: archivedTasks,
          );
          await historyBox.add(newHistoryEntry);
        }
      }

      for (final task in tasksToDelete) {
        await task.delete();
      }
    }

    final hasTodayEntry = historyBox.values.any((entry) => entry.date.isAtSameMomentAs(today));
    if (!hasTodayEntry) {
      await historyBox.add(HistoryEntry(date: today));
    }

    await prefs.setString(_lastRunKey, today.toIso8601String());
    } catch (e) {
      print('HistoryManager failed: $e');
      return;
    }
  }
}

extension on Task {
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isDone': isDone,
      'createdAt': createdAt.toIso8601String(),
      'dueTime': dueTime != null ? '${dueTime!.hour}:${dueTime!.minute}' : null,
      'plannedHours': plannedHours,
      'completionDescription': completionDescription,
      'rating': rating,
    };
  }
}
