import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // NEW: For TaskProvider
import '../task_provider.dart'; // NEW: Import TaskProvider
import '../models/models.dart';
import '../widgets/app_card.dart';
import '../widgets/completion_details_dialog.dart';

class ToDoScreen extends StatefulWidget {
  final VoidCallback? onTasksUpdated;

  const ToDoScreen({super.key, this.onTasksUpdated});

  @override
  State<ToDoScreen> createState() => _ToDoScreenState();
}

class _ToDoScreenState extends State<ToDoScreen> {
  final _scrollController1 = ScrollController();
  final _scrollController2 = ScrollController();
  bool _isLoading = true;
  // ignore: unused_field
  final List<Task> _tasks = [];
  // ignore: unused_field
  final DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Load today's tasks into the provider
      final provider = Provider.of<TaskProvider>(context, listen: false);
      await provider.loadTodayTasks();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Failed to initialize todo screen: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  Future<void> _onTaskToggle(Task task, bool isDone) async {
    final provider = Provider.of<TaskProvider>(context, listen: false);
    await provider.completeTask(task.id, isDone);
    print('Task completion toggled, calling callback');
    widget.onTasksUpdated?.call();
  }

  Future<void> _onDeleteTask(Task task) async {
    final provider = Provider.of<TaskProvider>(context, listen: false);
    await provider.deleteTask(task.id);
    print('Task deleted, calling callback');
    widget.onTasksUpdated?.call();
  }

  @override
  void dispose() {
    _scrollController1.dispose();
    _scrollController2.dispose();
    super.dispose();
  }



  Widget _buildTaskList(List<Task> tasks, bool showCompleted, ScrollController controller) {
    return ListView.builder(
      key: ValueKey('${showCompleted ? 'completed' : 'active'}-list'),
      controller: controller,
      padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0, bottom: 80.0),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final colorScheme = Theme.of(context).colorScheme;

        return AppCard(
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: task.isDone,
                  onChanged: (bool? value) {
                    if (value != null) {
                      _onTaskToggle(task, value);
                    }
                  },
                  activeColor: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'League Spartan',
                                decoration: task.isDone ? TextDecoration.lineThrough : TextDecoration.none,
                                color: task.isDone
                                    ? Theme.of(context).textTheme.bodySmall?.color
                                    : Theme.of(context).textTheme.titleMedium?.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!showCompleted)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: colorScheme.error.withOpacity(0.7),
                              onPressed: () => _onDeleteTask(task),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          if (showCompleted)
                            IconButton(
                              icon: const Icon(Icons.edit_note, size: 20),
                              color: colorScheme.primary.withOpacity(0.8),
                              onPressed: () => _showCompletionDetailsDialog(context, task),
                              tooltip: 'Add completion details',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                        ],
                      ),
                      if (task.dueTime != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.alarm,
                                size: 16,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                task.dueTime!.format(context),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      if (task.plannedHours > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Planned: ${task.plannedHours % 1 == 0 ? task.plannedHours.toInt() : task.plannedHours.toStringAsFixed(1)}h',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      if (task.isDone && task.completionDescription?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            task.completionDescription!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      if (task.isDone && task.rating != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${task.rating}/5',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCompletionDetailsDialog(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (context) => CompletionDetailsDialog(
        task: task,
        onSave: (Task updatedTask) async {
          final provider = Provider.of<TaskProvider>(context, listen: false);
          await provider.editTask(updatedTask);
          print('Task updated, calling callback');
          widget.onTasksUpdated?.call();
        },
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final TextEditingController taskController = TextEditingController();
    final TextEditingController hoursController = TextEditingController();
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.0),
                ),
                title: const Text('Add Task'),
                content: SizedBox(
                  width: 500, // Make dialog wider
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: taskController,
                        decoration: InputDecoration(
                          hintText: "Enter task title",
                          hintStyle: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                            fontSize: 14,
                            fontFamily: 'Inter',
                          ),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        ),
                        autofocus: true,
                        style: const TextStyle(fontFamily: 'Inter'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: hoursController,
                        decoration: InputDecoration(
                          hintText: "Planned Hours",
                          hintStyle: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                            fontSize: 14,
                            fontFamily: 'Inter',
                          ),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        style: const TextStyle(fontFamily: 'Inter'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.alarm_add),
                            label: Text(selectedTime?.format(context) ?? 'Add due time'),
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null) {
                                setState(() {
                                  selectedTime = time;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final String title = taskController.text.trim();
                      final String hoursText = hoursController.text.trim();

                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a task title')),
                        );
                        return;
                      }

                      double plannedHours = 0.0;
                      if (hoursText.isNotEmpty) {
                        plannedHours = double.tryParse(hoursText) ?? -1.0;
                        if (plannedHours < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid positive number for hours')),
                          );
                          return;
                        }
                      }

                      final newTask = Task(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: title,
                        createdAt: DateTime.now(),
                        dueTime: selectedTime,
                        plannedHours: plannedHours,
                      );
                      final provider = Provider.of<TaskProvider>(context, listen: false);
                      await provider.addTask(newTask);
                      print('Task added, calling callback');
                      widget.onTasksUpdated?.call();
                      Navigator.pop(context);
                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Consumer<TaskProvider>(
      builder: (context, provider, child) {
        // Get live tasks from provider
        final tasks = provider.tasks;
        final activeTasks = tasks.where((task) => !task.isDone).toList();
        final completedTasks = tasks.where((task) => task.isDone).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('To-Do'),
          ),
          body: tasks.isEmpty
              ? const Center(
                  child: Text("No tasks yet."),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side - Completed tasks
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              'Completed (${completedTasks.length})',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                            ),
                          ),
                          Expanded(
                            child: completedTasks.isEmpty
                                ? Center(
                                    child: Text(
                                      'No completed tasks',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Theme.of(context).textTheme.bodySmall?.color,
                                          ),
                                    ),
                                  )
                                : _buildTaskList(completedTasks, true, _scrollController1),
                          ),
                        ],
                      ),
                    ),
                    // Vertical divider
                    Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 8.0),
                      color: Theme.of(context).dividerColor.withOpacity(0.5),
                    ),
                    // Right side - Active tasks
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              'Active (${activeTasks.length})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Expanded(
                            child: activeTasks.isEmpty
                                ? Center(
                                    child: Text(
                                      'No active tasks',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  )
                                : _buildTaskList(activeTasks, false, _scrollController2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddTaskDialog(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
