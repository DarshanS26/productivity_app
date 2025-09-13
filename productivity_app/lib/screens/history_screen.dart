import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../task_provider.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';


class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> with WidgetsBindingObserver {
  final Set<DateTime> _expandedDays = {};
  bool _isLoading = true;
  List<DateTime> _availableDates = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh when app comes back to foreground
      refreshHistory();
    }
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh when widget updates (e.g., when switching tabs)
    refreshHistory();
  }

  Future<void> _initialize() async {
    print('HistoryScreen: Initializing history data');
    try {
      final dates = await StorageService.getAvailableDates();
      print('HistoryScreen: Loaded ${dates.length} available dates');
      if (mounted) {
        setState(() {
          _availableDates = dates;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('HistoryScreen: Failed to load history dates: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> refreshHistory() async {
    print('HistoryScreen: History refresh called');
    // Refresh today's tasks in provider and reload available dates
    final provider = Provider.of<TaskProvider>(context, listen: false);
    await provider.refreshTodayTasks();
    await _initialize();
    print('HistoryScreen: History refresh completed');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_availableDates.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('History'),
        ),
        body: Center(
          child: Text("No history yet. Complete some tasks!"),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('History'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _availableDates.length,
        itemBuilder: (context, index) {
          final date = _availableDates[index];
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final isToday = date.isAtSameMomentAs(today);

          return _HistoryCard(
            date: date,
            isToday: isToday,
            isExpanded: _expandedDays.contains(date),
            onToggleExpand: () {
              setState(() {
                if (_expandedDays.contains(date)) {
                  _expandedDays.remove(date);
                } else {
                  _expandedDays.clear(); // Collapse all others
                  _expandedDays.add(date);
                }
              });
            },
          );
        },
      ),
    );
  }
}


// A dedicated widget for the history card to manage its own state for editing hours
class _HistoryCard extends StatefulWidget {
  final DateTime date;
  final bool isToday;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const _HistoryCard({
    required this.date,
    required this.isToday,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  // No local state needed since FutureBuilder handles everything

  @override
  void initState() {
    super.initState();
    // No initialization needed for hours logging
  }

  @override
  void dispose() {
    super.dispose();
  }


  // NEW: Removed _loadTasks as provider handles reactive loading



  @override
  Widget build(BuildContext context) {
    if (widget.isToday) {
      // For today's card, use Consumer to get live updates from TaskProvider
      return Consumer<TaskProvider>(
        builder: (context, provider, child) {
          final tasks = provider.tasks;
          final completedTasks = tasks.where((t) => t.isDone).toList();
          final totalPlanned = completedTasks.fold(0.0, (sum, task) => sum + task.plannedHours.toDouble());
          // Use sum of planned hours for completed tasks
          final totalHours = totalPlanned;

          return AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCardHeader(
                    tasks: tasks,
                    totalPlanned: totalPlanned,
                    totalHours: totalHours,
                  ),
                  if (widget.isExpanded)
                    _buildTodayTaskList(tasks: tasks),
                ],
              ),
            ),
          );
        },
      );
    } else {
      // For previous days, load data from storage
      return FutureBuilder<List<Task>>(
        future: _loadDataForCard(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppCard(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          if (snapshot.hasError) {
            print('HistoryCard: Error in FutureBuilder: ${snapshot.error}');
            return AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'Error loading data: ${snapshot.error}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            );
          }

          final tasks = snapshot.data ?? [];
          final completedTasks = tasks.where((t) => t.isDone).toList();
          final totalPlanned = completedTasks.fold(0.0, (sum, task) => sum + task.plannedHours.toDouble());
          final totalHours = totalPlanned;

          return AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCardHeader(
                    tasks: tasks,
                    totalPlanned: totalPlanned,
                    totalHours: totalHours,
                  ),
                  if (widget.isExpanded)
                    _buildArchivedTaskList(tasks: tasks),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  // Helper method to load data for historical cards
  Future<List<Task>> _loadDataForCard() async {
    if (widget.isToday) return []; // Today's data comes from provider

    print('HistoryCard: Loading data for date ${widget.date}');

    try {
      final provider = Provider.of<TaskProvider>(context, listen: false);
      final tasks = await provider.loadTasksForDate(widget.date);
      print('HistoryCard: Loaded ${tasks.length} tasks for ${widget.date}');

      return tasks;
    } catch (e, stackTrace) {
      print('HistoryCard: Error loading data for card ${widget.date}: $e');
      print('HistoryCard: Stack trace: $stackTrace');
      return [];
    }
  }


  // Updated to accept parameters from reactive build
  Widget _buildCardHeader({
    required List<Task> tasks,
    required double totalPlanned,
    required double totalHours,
  }) {
    final tasksAdded = widget.isToday ? tasks.length : tasks.length;
    final tasksCompleted = widget.isToday
        ? tasks.where((t) => t.isDone).length
        : tasks.where((t) => t.isDone).length;

    return GestureDetector(
      onTap: widget.onToggleExpand, // Make the header area trigger expansion
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isToday ? 'Today' : DateFormat('EEEE, MMMM d, yyyy').format(widget.date),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '$tasksAdded tasks • $tasksCompleted completed',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                ),
              ],
            ),
          ),
          _buildActualHoursWidget(
            totalHours: totalHours,
          ),
        ],
      ),
    );
  }

  // NEW: Updated to accept tasks parameter for reactive updates
  Widget _buildTodayTaskList({required List<Task> tasks}) {
    if (tasks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 16.0),
        child: Text('No tasks for today yet.', style: TextStyle(color: Colors.grey)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        children: tasks.map((task) => _TaskItem(title: task.title, isDone: task.isDone, plannedHours: task.plannedHours)).toList(),
      ),
    );
  }

  // NEW: Updated to accept tasks parameter for reactive updates
  Widget _buildArchivedTaskList({required List<Task> tasks}) {
    if (tasks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 16.0),
        child: Text('No tasks were recorded for this day.', style: TextStyle(color: Colors.grey)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        children: tasks.map((task) => _TaskItem(title: task.title, isDone: task.isDone, plannedHours: task.plannedHours)).toList(),
      ),
    );
  }

  // Simple widget to display total hours worked
  Widget _buildActualHoursWidget({
    required double totalHours,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: totalHours > 0
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          totalHours > 0 ? '${totalHours.toStringAsFixed(1)}h' : '0.0h',
          style: TextStyle(
            color: totalHours > 0
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// A simple, type-safe widget to display a task row
class _TaskItem extends StatelessWidget {
  final String title;
  final bool isDone;
  final double plannedHours;

  const _TaskItem({required this.title, required this.isDone, required this.plannedHours});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_box : Icons.check_box_outline_blank,
            color: isDone ? Colors.green : Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
          if (plannedHours > 0)
            Text('${plannedHours % 1 == 0 ? plannedHours.toInt() : plannedHours.toStringAsFixed(1)} h', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}