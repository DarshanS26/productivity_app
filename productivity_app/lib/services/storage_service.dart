import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

// NEW: Reactive streams for live updates
class StorageService {
  // Stream controllers for reactive updates
  static final StreamController<Map<String, dynamic>> _taskStreamController = StreamController<Map<String, dynamic>>.broadcast();

  // Stream accessors
  static Stream<Map<String, dynamic>> get taskStream => _taskStreamController.stream;

  // Emit task update event
  static void _emitTaskUpdate({required DateTime date, required List<Task> tasks}) {
    final taskData = {
      'date': _getDateString(date),
      'tasks': tasks.map((t) => t.toJson()).toList(),
    };
    if (!_taskStreamController.isClosed) {
      _taskStreamController.add(taskData);
    }
  }

  static const String _appFolderName = 'ProductivityApp';
  static const String _tasksFolder = 'tasks';
  static const String _journalsFolder = 'journals';
  static const String _migrationKey = 'storage_migration_completed';
  static Future<String> getBaseDirectory() async {
    if (kIsWeb) {
      // For web, we'll use a virtual directory structure
      return 'productivity_app';
    } else {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final baseDir = '${directory.path}${Platform.pathSeparator}$_appFolderName';
        print('StorageService: Application documents directory: ${directory.path}');
        print('StorageService: Base directory will be: $baseDir');

        // Ensure the directory exists
        final dir = Directory(baseDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
          print('StorageService: Created base directory: $baseDir');
        }

        return baseDir;
      } catch (e, stackTrace) {
        print('StorageService: Error getting base directory: $e');
        print('StorageService: Stack trace: $stackTrace');

        // Fallback to a local directory in the app's working directory
        final fallbackDir = _appFolderName;
        print('StorageService: Using fallback directory: $fallbackDir');
        final dir = Directory(fallbackDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return fallbackDir;
      }
    }
  }

  static Future<void> initialize() async {
    print('StorageService: Initializing storage service');
    if (!kIsWeb) {
      try {
        final baseDir = await getBaseDirectory();
        print('StorageService: Base directory: $baseDir');

        // Create main directory
        final mainDir = Directory(baseDir);
        final mainDirExists = await mainDir.exists();
        print('StorageService: Main directory exists: $mainDirExists');

        if (!mainDirExists) {
          print('StorageService: Creating main directory');
          await mainDir.create(recursive: true);
          print('StorageService: Main directory created');
        }

        // Create subdirectories with error handling
        final tasksDir = Directory('$baseDir/$_tasksFolder');
        final journalsDir = Directory('$baseDir/$_journalsFolder');

        print('StorageService: Creating subdirectories');
        final tasksDirExists = await tasksDir.exists();
        final journalsDirExists = await journalsDir.exists();

        if (!tasksDirExists) {
          await tasksDir.create(recursive: true);
          print('StorageService: Tasks directory created');
        } else {
          print('StorageService: Tasks directory already exists');
        }

        if (!journalsDirExists) {
          await journalsDir.create(recursive: true);
          print('StorageService: Journals directory created');
        } else {
          print('StorageService: Journals directory already exists');
        }

        print('StorageService: Subdirectories created successfully');
      } catch (e, stackTrace) {
        print('StorageService: Error during directory creation: $e');
        print('StorageService: Stack trace: $stackTrace');
        // Don't rethrow - continue with initialization
      }
    }

    // Check if migration is needed
    try {
      final prefs = await SharedPreferences.getInstance();
      final migrated = prefs.getBool(_migrationKey) ?? false;
      print('StorageService: Migration needed: ${!migrated}');

      if (!migrated) {
        await _migrateFromHive();
        await prefs.setBool(_migrationKey, true);
        print('StorageService: Migration completed');
      }
    } catch (e, stackTrace) {
      print('StorageService: Error during migration check: $e');
      print('StorageService: Stack trace: $stackTrace');
    }

    print('StorageService: Initialization completed');
  }

  static Future<void> _migrateFromHive() async {
    // This will be implemented when we have access to existing Hive data
    print('Migration from Hive would happen here');
  }

  static String _getDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static Future<String> _getTasksFilePath(DateTime date) async {
    final baseDir = await getBaseDirectory();
    final dateStr = _getDateString(date);
    return '$baseDir/$_tasksFolder/tasks_$dateStr.json';
  }

  static Future<String> _getJournalFilePath(DateTime date) async {
    final baseDir = await getBaseDirectory();
    final dateStr = _getDateString(date);
    return '$baseDir/$_journalsFolder/journal_$dateStr.json';
  }


  // Task operations
  static Future<List<Task>> loadTasksForDate(DateTime date) async {
    try {
      final filePath = await _getTasksFilePath(date);
      print('Loading tasks for date: $date, file path: $filePath');

      if (kIsWeb) {
        // Web implementation using SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final tasksJson = prefs.getString('tasks_${_getDateString(date)}');
        print('Web: tasks JSON for $date: ${tasksJson != null ? 'found' : 'not found'}');

        if (tasksJson == null) return [];

        final tasksData = json.decode(tasksJson) as Map<String, dynamic>;
        final pendingTasks = (tasksData['pending'] as List<dynamic>? ?? [])
            .map((task) => Task.fromJson(task))
            .toList();
        final completedTasks = (tasksData['completed'] as List<dynamic>? ?? [])
            .map((task) => Task.fromJson(task))
            .toList();

        final allTasks = [...pendingTasks, ...completedTasks];
        print('Web: loaded ${allTasks.length} tasks for $date');
        return allTasks;
      } else {
        // Desktop implementation using files
        final file = File(filePath);
        final exists = await file.exists();
        print('Desktop: file exists for $date: $exists');

        if (!exists) {
          print('Desktop: no file found for $date, returning empty list');
          return [];
        }

        final content = await file.readAsString();
        print('Desktop: read content for $date, length: ${content.length}');

        final tasksData = json.decode(content) as Map<String, dynamic>;
        print('Desktop: decoded JSON for $date');

        final pendingTasks = (tasksData['pending'] as List<dynamic>? ?? [])
            .map((task) => Task.fromJson(task))
            .toList();
        final completedTasks = (tasksData['completed'] as List<dynamic>? ?? [])
            .map((task) => Task.fromJson(task))
            .toList();

        final allTasks = [...pendingTasks, ...completedTasks];
        print('Desktop: loaded ${allTasks.length} tasks for $date (${pendingTasks.length} pending, ${completedTasks.length} completed)');
        return allTasks;
      }
    } catch (e) {
      print('Error loading tasks for $date: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  static Future<void> saveTasksForDate(DateTime date, List<Task> tasks) async {
    try {
      final pendingTasks = tasks.where((task) => !task.isDone).toList();
      final completedTasks = tasks.where((task) => task.isDone).toList();

      final tasksData = {
        'date': _getDateString(date),
        'pending': pendingTasks.map((task) => task.toJson()).toList(),
        'completed': completedTasks.map((task) => task.toJson()).toList(),
        'lastModified': DateTime.now().toIso8601String(),
      };

      final jsonString = json.encode(tasksData);

      if (kIsWeb) {
        // Web implementation
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('tasks_${_getDateString(date)}', jsonString);
      } else {
        // Desktop implementation
        final filePath = await _getTasksFilePath(date);
        final file = File(filePath);
        await file.writeAsString(jsonString);
      }

      _emitTaskUpdate(date: date, tasks: tasks); // NEW: Emit after successful save
    } catch (e) {
      print('Error saving tasks for $date: $e');
      rethrow;
    }
  }

  static Future<void> addTask(Task task) async {
    final date = DateTime(task.createdAt.year, task.createdAt.month, task.createdAt.day);
    final existingTasks = await loadTasksForDate(date);
    existingTasks.add(task);
    await saveTasksForDate(date, existingTasks);
    _emitTaskUpdate(date: date, tasks: existingTasks); // NEW: Emit update for live reactivity
  }

  static Future<void> updateTask(Task updatedTask) async {
    final date = DateTime(updatedTask.createdAt.year, updatedTask.createdAt.month, updatedTask.createdAt.day);
    final existingTasks = await loadTasksForDate(date);

    final index = existingTasks.indexWhere((task) => task.id == updatedTask.id);
    if (index != -1) {
      existingTasks[index] = updatedTask;
      await saveTasksForDate(date, existingTasks);
      _emitTaskUpdate(date: date, tasks: existingTasks); // NEW: Emit update for live reactivity
    }
  }

  static Future<void> deleteTask(Task task) async {
    final date = DateTime(task.createdAt.year, task.createdAt.month, task.createdAt.day);
    final existingTasks = await loadTasksForDate(date);
    existingTasks.removeWhere((t) => t.id == task.id);
    await saveTasksForDate(date, existingTasks);
    _emitTaskUpdate(date: date, tasks: existingTasks); // NEW: Emit update for live reactivity
  }

  // Journal operations
  static Future<List<JournalEntry>> loadJournalsForDate(DateTime date) async {
    try {
      final filePath = await _getJournalFilePath(date);
      print('StorageService: Loading journals for date $date, file path: $filePath');

      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final journalsJson = prefs.getString('journals_${_getDateString(date)}');
        print('StorageService: Web journals JSON for $date: ${journalsJson != null ? 'found' : 'not found'}');

        if (journalsJson == null) return [];

        final journalsData = json.decode(journalsJson) as List<dynamic>;
        final journals = journalsData.map((entry) => JournalEntry.fromJson(entry)).toList();
        print('StorageService: Web loaded ${journals.length} journals for $date');
        return journals;
      } else {
        final file = File(filePath);
        final exists = await file.exists();
        print('StorageService: Desktop journals file exists for $date: $exists');

        if (!exists) {
          print('StorageService: Desktop no journals file found for $date, returning empty list');
          return [];
        }

        final content = await file.readAsString();
        print('StorageService: Desktop read journals content for $date, length: ${content.length}');

        final journalsData = json.decode(content) as List<dynamic>;
        final journals = journalsData.map((entry) => JournalEntry.fromJson(entry)).toList();
        print('StorageService: Desktop loaded ${journals.length} journals for $date');
        return journals;
      }
    } catch (e, stackTrace) {
      print('StorageService: Error loading journals for $date: $e');
      print('StorageService: Stack trace: $stackTrace');
      return [];
    }
  }

  static Future<void> saveJournalsForDate(DateTime date, List<JournalEntry> entries) async {
    try {
      final journalsData = entries.map((entry) => entry.toJson()).toList();
      final jsonString = json.encode(journalsData);

      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('journals_${_getDateString(date)}', jsonString);
      } else {
        final filePath = await _getJournalFilePath(date);
        final file = File(filePath);
        await file.writeAsString(jsonString);
      }
    } catch (e) {
      print('Error saving journals for $date: $e');
      rethrow;
    }
  }

  static Future<void> addJournalEntry(JournalEntry entry) async {
    final date = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);
    final existingEntries = await loadJournalsForDate(date);
    existingEntries.add(entry);
    await saveJournalsForDate(date, existingEntries);
  }



  // Close streams on app shutdown (call from main.dart if needed)
  static void dispose() {
    if (!_taskStreamController.isClosed) _taskStreamController.close();
  }

  // Utility methods
  static Future<List<DateTime>> getAvailableDates() async {
    final dates = <DateTime>[];
    print('StorageService: Getting available dates');

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      print('Web: Found ${keys.length} total keys in SharedPreferences');

      for (final key in keys) {
        if (key.startsWith('tasks_')) {
          final dateStr = key.substring(6); // Remove 'tasks_' prefix
          print('Web: Found task key: $key, dateStr: $dateStr');
          try {
            final parts = dateStr.split('-');
            final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
            dates.add(date);
            print('Web: Successfully parsed date: $date');
          } catch (e) {
            print('Web: Error parsing date from key $key: $e');
          }
        }
      }
    } else {
      final baseDir = await getBaseDirectory();
      print('Desktop: Base directory: $baseDir');
      final tasksDir = Directory('$baseDir/$_tasksFolder');
      print('Desktop: Tasks directory: ${tasksDir.path}');

      final dirExists = await tasksDir.exists();
      print('Desktop: Tasks directory exists: $dirExists');

      if (dirExists) {
        final files = await tasksDir.list().toList();
        print('Desktop: Found ${files.length} files in tasks directory');

        for (final file in files) {
          if (file is File && file.path.endsWith('.json')) {
            final fileName = file.path.split(Platform.pathSeparator).last;
            print('Desktop: Found task file: $fileName');

            // More robust date extraction from filename like "tasks_2024-01-15.json"
            if (fileName.startsWith('tasks_') && fileName.endsWith('.json')) {
              final datePart = fileName.substring(6, fileName.length - 5); // Remove "tasks_" and ".json"
              print('Desktop: Extracted date part: $datePart');

              try {
                final parts = datePart.split('-');
                if (parts.length == 3) {
                  final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                  dates.add(date);
                  print('Desktop: Successfully parsed date: $date');
                } else {
                  print('Desktop: Invalid date format in filename: $datePart');
                }
              } catch (e) {
                print('Desktop: Error parsing date from filename $fileName: $e');
              }
            } else {
              print('Desktop: Skipping file with unexpected format: $fileName');
            }
          }
        }
      } else {
        print('Desktop: Tasks directory does not exist, creating it...');
        try {
          await tasksDir.create(recursive: true);
          print('Desktop: Tasks directory created successfully');
        } catch (e) {
          print('Desktop: Error creating tasks directory: $e');
        }
      }
    }

    dates.sort((a, b) => b.compareTo(a)); // Most recent first
    print('StorageService: Returning ${dates.length} available dates');
    return dates;
  }
}

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
      'actualHours': actualHours,
    };
  }
}