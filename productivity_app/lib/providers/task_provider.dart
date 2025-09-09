import 'package:flutter/widgets.dart';
import '../models/task.dart';
import '../services/storage_service.dart';

class TaskProvider extends ChangeNotifier {
  // Today's tasks in memory (single source of truth for today)
  List<Task> _todayTasks = [];
  bool _isLoaded = false;

  TaskProvider() {
    print('TaskProvider: Constructor called');
    // Don't auto-load tasks here - let screens control when to load
  }
  
  // Getter for today's tasks
  List<Task> get tasks => List.unmodifiable(_todayTasks);
  bool get isLoaded => _isLoaded;
  
  // Get today's date normalized
  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // Initialize and load today's tasks from storage
  Future<void> loadTodayTasks() async {
    if (_isLoaded) return; // Already loaded

    print('TaskProvider: Loading today\'s tasks for $_today');
    try {
      _todayTasks = await StorageService.loadTasksForDate(_today);
      _isLoaded = true;
      print('TaskProvider: Successfully loaded ${_todayTasks.length} tasks for today');
      notifyListeners();
    } catch (e) {
      print('TaskProvider: Error loading today\'s tasks: $e');
      _todayTasks = [];
      _isLoaded = true;
      notifyListeners();
    }
  }

  // Force reload today's tasks (for navigation refresh)
  Future<void> refreshTodayTasks() async {
    print('TaskProvider: Refreshing today\'s tasks');
    try {
      _todayTasks = await StorageService.loadTasksForDate(_today);
      print('TaskProvider: Refreshed ${_todayTasks.length} tasks for today');
      notifyListeners();
    } catch (e) {
      print('TaskProvider: Error refreshing today\'s tasks: $e');
    }
  }

  // Add a new task
  Future<void> addTask(Task task) async {
    try {
      // Update in-memory list immediately
      _todayTasks.add(task);
      notifyListeners();
      
      // Persist to disk
      await StorageService.addTask(task);
    } catch (e) {
      print('Error adding task: $e');
      // Rollback on error
      _todayTasks.removeWhere((t) => t.id == task.id);
      notifyListeners();
      rethrow;
    }
  }

  // Edit/update a task
  Future<void> editTask(Task updatedTask) async {
    try {
      // Update in-memory list immediately
      final index = _todayTasks.indexWhere((t) => t.id == updatedTask.id);
      if (index != -1) {
        _todayTasks[index] = updatedTask;
        notifyListeners();
        
        // Persist to disk
        await StorageService.updateTask(updatedTask);
      }
    } catch (e) {
      print('Error editing task: $e');
      // Rollback on error
      await refreshTodayTasks();
      rethrow;
    }
  }

  // Complete/uncomplete a task
  Future<void> completeTask(String taskId, bool isCompleted) async {
    try {
      final index = _todayTasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        final task = _todayTasks[index];
        final updatedTask = Task(
          id: task.id,
          title: task.title,
          isDone: isCompleted,
          createdAt: task.createdAt,
          dueTime: task.dueTime,
          plannedHours: task.plannedHours,
          completionDescription: task.completionDescription,
          rating: task.rating,
          actualHours: task.actualHours,
        );
        
        // Update in-memory list immediately
        _todayTasks[index] = updatedTask;
        notifyListeners();
        
        // Persist to disk
        await StorageService.updateTask(updatedTask);
      }
    } catch (e) {
      print('Error completing task: $e');
      // Rollback on error
      await refreshTodayTasks();
      rethrow;
    }
  }

  // Delete a task
  Future<void> deleteTask(String taskId) async {
    try {
      final taskToDelete = _todayTasks.firstWhere((t) => t.id == taskId);
      
      // Update in-memory list immediately
      _todayTasks.removeWhere((t) => t.id == taskId);
      notifyListeners();
      
      // Persist to disk
      await StorageService.deleteTask(taskToDelete);
    } catch (e) {
      print('Error deleting task: $e');
      // Rollback on error
      await refreshTodayTasks();
      rethrow;
    }
  }

  // Load tasks for a specific date (for history screen)
  Future<List<Task>> loadTasksForDate(DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    print('TaskProvider: Loading tasks for date $normalizedDate (original: $date)');
    print('TaskProvider: Today is $_today');

    // If it's today, return in-memory tasks
    if (normalizedDate.isAtSameMomentAs(_today)) {
      print('TaskProvider: Returning in-memory tasks for today (${tasks.length} tasks)');
      return tasks;
    }

    // For other dates, load from storage
    try {
      print('TaskProvider: Loading historical tasks from storage for $normalizedDate');
      final loadedTasks = await StorageService.loadTasksForDate(normalizedDate);
      print('TaskProvider: Successfully loaded ${loadedTasks.length} tasks from storage for $normalizedDate');
      return loadedTasks;
    } catch (e, stackTrace) {
      print('TaskProvider: Error loading tasks for $normalizedDate: $e');
      print('TaskProvider: Stack trace: $stackTrace');
      return [];
    }
  }

}