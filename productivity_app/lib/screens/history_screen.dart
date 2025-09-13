import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../task_provider.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';
import '../widgets/star_rating.dart';


class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> with WidgetsBindingObserver {
  final Set<DateTime> _expandedDays = {};
  final Set<String> _expandedWeeks = {}; // Track expanded weeks by weekKey
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

  // Load custom week name from storage
  Future<String?> _loadWeekName(String weekKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('week_name_$weekKey');
    } catch (e) {
      print('Error loading week name for $weekKey: $e');
      return null;
    }
  }

  // Save custom week name to storage
  Future<void> _saveWeekName(String weekKey, String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('week_name_$weekKey', name);
    } catch (e) {
      print('Error saving week name for $weekKey: $e');
    }
  }

  // Group dates by weeks (Monday-Sunday)
  List<Map<String, dynamic>> _groupDatesByWeeks(List<DateTime> dates) {
    if (dates.isEmpty) return [];

    // Sort dates in descending order (most recent first)
    final sortedDates = List<DateTime>.from(dates)..sort((a, b) => b.compareTo(a));

    final weeks = <Map<String, dynamic>>[];

    for (final date in sortedDates) {
      // Find the Monday of the week containing this date
      final monday = date.subtract(Duration(days: date.weekday - 1));
      final weekKey = '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';

      // Check if we already have this week
      var existingWeek = weeks.where((week) => week['weekKey'] == weekKey).firstOrNull;

      if (existingWeek == null) {
        // Create new week entry
        existingWeek = {
          'weekKey': weekKey,
          'monday': monday,
          'dates': <DateTime>[],
        };
        weeks.add(existingWeek);
      }

      // Add date to the week (only if it's not already there)
      if (!existingWeek['dates'].contains(date)) {
        existingWeek['dates'].add(date);
      }
    }

    // Sort weeks by Monday date (most recent first)
    weeks.sort((a, b) => (b['monday'] as DateTime).compareTo(a['monday'] as DateTime));

    return weeks;
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

    // Group dates by weeks
    final weeks = _groupDatesByWeeks(_availableDates);

    return Scaffold(
      appBar: AppBar(
        title: Text('History'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: weeks.length,
        itemBuilder: (context, index) {
          final week = weeks[index];
          final monday = week['monday'] as DateTime;
          final weekDates = week['dates'] as List<DateTime>;
          final weekKey = week['weekKey'] as String;
          final weekNumber = index + 1; // Week 1, Week 2, etc.

          return _WeekCard(
            weekKey: weekKey,
            weekNumber: weekNumber,
            monday: monday,
            weekDates: weekDates,
            isExpanded: _expandedWeeks.contains(weekKey),
            expandedDays: _expandedDays,
            loadWeekName: _loadWeekName,
            saveWeekName: _saveWeekName,
            onToggleWeekExpansion: () {
              setState(() {
                if (_expandedWeeks.contains(weekKey)) {
                  _expandedWeeks.remove(weekKey);
                } else {
                  _expandedWeeks.clear(); // Collapse all other weeks
                  _expandedWeeks.add(weekKey);
                }
              });
            },
            onToggleDayExpansion: (date) {
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

// A dedicated widget for the weekly card containing multiple daily cards
class _WeekCard extends StatefulWidget {
  final String weekKey;
  final int weekNumber;
  final DateTime monday;
  final List<DateTime> weekDates;
  final bool isExpanded;
  final Set<DateTime> expandedDays;
  final VoidCallback onToggleWeekExpansion;
  final Function(DateTime) onToggleDayExpansion;
  final Future<String?> Function(String) loadWeekName;
  final Future<void> Function(String, String) saveWeekName;

  const _WeekCard({
    required this.weekKey,
    required this.weekNumber,
    required this.monday,
    required this.weekDates,
    required this.isExpanded,
    required this.expandedDays,
    required this.onToggleWeekExpansion,
    required this.onToggleDayExpansion,
    required this.loadWeekName,
    required this.saveWeekName,
  });

  @override
  State<_WeekCard> createState() => _WeekCardState();
}

class _WeekCardState extends State<_WeekCard> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  bool _isEditing = false;
  String? _customName;
  String? _weekNotes;
  bool _showDetailedStats = false;
  Map<String, dynamic>? _weekStats;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _notesController = TextEditingController();
    _loadWeekName();
    _loadWeekNotes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadWeekName() async {
    final name = await widget.loadWeekName(widget.weekKey);
    if (mounted) {
      setState(() {
        _customName = name;
        _nameController.text = name ?? 'Week ${widget.weekNumber}';
      });
    }
  }

  Future<void> _loadWeekNotes() async {
    final notes = await _loadWeekNotesFromPrefs(widget.weekKey);
    if (mounted) {
      setState(() {
        _weekNotes = notes;
        _notesController.text = notes ?? '';
      });
    }
  }

  Future<String?> _loadWeekNotesFromPrefs(String weekKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('week_notes_$weekKey');
    } catch (e) {
      print('Error loading week notes for $weekKey: $e');
      return null;
    }
  }

  Future<void> _saveWeekName() async {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != 'Week ${widget.weekNumber}') {
      await widget.saveWeekName(widget.weekKey, newName);
      setState(() {
        _customName = newName;
        _isEditing = false;
      });
    } else {
      // Reset to default if empty or same as default
      await widget.saveWeekName(widget.weekKey, 'Week ${widget.weekNumber}');
      setState(() {
        _customName = null;
        _nameController.text = 'Week ${widget.weekNumber}';
        _isEditing = false;
      });
    }
  }

  Future<void> _saveWeekNotes() async {
    final notes = _notesController.text.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (notes.isEmpty) {
        await prefs.remove('week_notes_${widget.weekKey}');
      } else {
        await prefs.setString('week_notes_${widget.weekKey}', notes);
      }
      setState(() {
        _weekNotes = notes.isEmpty ? null : notes;
      });
    } catch (e) {
      print('Error saving week notes for ${widget.weekKey}: $e');
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  String _getDisplayName() {
    return _customName ?? 'Week ${widget.weekNumber}';
  }

  // Calculate week statistics
  Future<Map<String, dynamic>> _calculateWeekStats() async {
    double totalHours = 0.0; // Sum of all planned hours (completed + incomplete)
    double completedHours = 0.0; // Sum of planned hours for completed tasks
    int currentStreak = 0;
    int maxStreak = 0;
    double bestDayHours = 0.0;
    DateTime? bestDay;

    // Get all 7 days of the week
    final weekDays = List.generate(7, (index) => widget.monday.add(Duration(days: index)));

    for (final day in weekDays) {
      try {
        // Load tasks for this day
        final provider = Provider.of<TaskProvider>(context, listen: false);
        final dayTasks = await provider.loadTasksForDate(day);

        // Calculate all planned hours and completed hours
        final allPlanned = dayTasks.fold(0.0, (sum, task) => sum + task.plannedHours.toDouble());
        final completedTasks = dayTasks.where((t) => t.isDone).toList();
        final completedPlanned = completedTasks.fold(0.0, (sum, task) => sum + task.plannedHours.toDouble());

        totalHours += allPlanned;
        completedHours += completedPlanned;

        // Update best day (based on completed hours)
        if (completedPlanned > bestDayHours) {
          bestDayHours = completedPlanned;
          bestDay = day;
        }

        // Update streak (consecutive days with completed tasks)
        if (completedPlanned > 0) {
          currentStreak++;
          if (currentStreak > maxStreak) {
            maxStreak = currentStreak;
          }
        } else {
          currentStreak = 0;
        }
      } catch (e) {
        print('Error loading tasks for ${day}: $e');
        // Continue with other days
      }
    }

    return {
      'totalHours': totalHours,
      'completedHours': completedHours,
      'streak': maxStreak,
      'bestDay': bestDay,
      'bestDayHours': bestDayHours,
    };
  }

  // Build all 7 days of the week
  List<Widget> _buildAllWeekDays() {
    final weekDays = List.generate(7, (index) => widget.monday.add(Duration(days: index)));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return weekDays.map((date) {
      final isToday = date.isAtSameMomentAs(today);

      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: _HistoryCard(
          date: date,
          isToday: isToday,
          isExpanded: widget.expandedDays.contains(date),
          onToggleExpand: () => widget.onToggleDayExpansion(date),
        ),
      );
    }).toList();
  }

  // Build week stats section
  Widget _buildWeekStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats toggle
        GestureDetector(
          onTap: () {
            setState(() {
              _showDetailedStats = !_showDetailedStats;
            });
          },
          child: Row(
            children: [
              Text(
                _showDetailedStats ? 'Hide Detailed Stats' : 'Show Detailed Stats',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _showDetailedStats ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),

        // Detailed stats
        if (_showDetailedStats) ...[
          const SizedBox(height: 8),
          FutureBuilder<Map<String, dynamic>>(
            future: _calculateWeekStats(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Text('Error loading stats: ${snapshot.error}');
              }

              final stats = snapshot.data ?? {};

              return Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total hours
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total Hours: ${(stats['totalHours'] as double?)?.toStringAsFixed(1) ?? '0.0'}h',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Completed hours
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 20,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Completed Hours: ${(stats['completedHours'] as double?)?.toStringAsFixed(1) ?? '0.0'}h',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Streak
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          size: 20,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Streak: ${(stats['streak'] as int?) ?? 0} days',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Best day
                    if (stats['bestDay'] != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 20,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Best Day: ${DateFormat('EEEE').format(stats['bestDay'] as DateTime)} (${(stats['bestDayHours'] as double?)?.toStringAsFixed(1) ?? '0.0'}h)',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Week Notes
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Week Notes',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Add notes about this week...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            contentPadding: const EdgeInsets.all(8.0),
                          ),
                          onChanged: (_) => _saveWeekNotes(),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Week header - tappable to expand/collapse or edit
            if (widget.isExpanded) ...[
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _startEditing,
                      behavior: HitTestBehavior.opaque,
                      child: widget.isExpanded && _isEditing
                          ? TextField(
                              controller: _nameController,
                              autofocus: true,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onSubmitted: (_) => _saveWeekName(),
                              onEditingComplete: _saveWeekName,
                            )
                          : Text(
                              '${_getDisplayName()} - ${DateFormat('MMM d').format(widget.monday)} to ${DateFormat('MMM d, yyyy').format(widget.monday.add(const Duration(days: 6)))}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onToggleWeekExpansion,
                    child: Icon(
                      Icons.expand_less,
                      size: 24,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ] else ...[
              GestureDetector(
                onTap: widget.onToggleWeekExpansion,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _getDisplayName(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.expand_more,
                      size: 24,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ],
                ),
              ),
            ],

            // Show daily cards and stats when expanded
            if (widget.isExpanded) ...[
              const SizedBox(height: 12),

              // Daily cards for all 7 days of the week
              ..._buildAllWeekDays(),

              const SizedBox(height: 12),

              // Stats toggle and display
              _buildWeekStatsSection(),
            ],
          ],
        ),
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
  final Set<String> _expandedTasks = {}; // Track expanded tasks by ID

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _toggleTaskExpansion(String taskId) {
    setState(() {
      if (_expandedTasks.contains(taskId)) {
        _expandedTasks.remove(taskId);
      } else {
        _expandedTasks.add(taskId);
      }
    });
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
            padding: const EdgeInsets.all(8.0),
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
            padding: const EdgeInsets.all(8.0),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.normal),
                ),
                const SizedBox(height: 4),
                Text(
                  '$tasksAdded tasks • $tasksCompleted completed',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
        padding: EdgeInsets.only(top: 8.0),
        child: Text('No tasks for today yet.', style: TextStyle(color: Colors.grey)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        children: tasks.map((task) => _TaskItem(
          key: ValueKey('task-${task.id}'),
          task: task,
          isExpanded: _expandedTasks.contains(task.id),
          onToggleExpansion: () => _toggleTaskExpansion(task.id),
        )).toList(),
      ),
    );
  }

  // NEW: Updated to accept tasks parameter for reactive updates
  Widget _buildArchivedTaskList({required List<Task> tasks}) {
    if (tasks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: Text('No tasks were recorded for this day.', style: TextStyle(color: Colors.grey)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        children: tasks.map((task) => _TaskItem(
          key: ValueKey('task-${task.id}'),
          task: task,
          isExpanded: _expandedTasks.contains(task.id),
          onToggleExpansion: () => _toggleTaskExpansion(task.id),
        )).toList(),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
            fontWeight: FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// A simple, type-safe widget to display a task row with completion details
class _TaskItem extends StatelessWidget {
  final Task task;
  final bool isExpanded;
  final VoidCallback onToggleExpansion;

  const _TaskItem({
    super.key,
    required this.task,
    required this.isExpanded,
    required this.onToggleExpansion,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main task row
        GestureDetector(
          onTap: onToggleExpansion,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Icon(
                  task.isDone ? Icons.check_box : Icons.check_box_outline_blank,
                  color: task.isDone ? Colors.green : Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                // Blue dot indicator for tasks with notes
                if (task.completionDescription?.isNotEmpty == true)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),

                if (task.plannedHours > 0)
                  Text(
                    '${task.plannedHours % 1 == 0 ? task.plannedHours.toInt() : task.plannedHours.toStringAsFixed(1)} h',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(width: 8),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),

        // Expanded completion details
        if (isExpanded && (task.completionDescription?.isNotEmpty == true || task.rating != null))
          Container(
            margin: const EdgeInsets.only(top: 4.0, left: 32.0, right: 8.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Completion note
                if (task.completionDescription?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      task.completionDescription!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                // Performance rating
                if (task.rating != null)
                  Row(
                    children: [
                      Text(
                        'Performance: ',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      StarRatingDisplay(
                        rating: task.rating!,
                        size: 14,
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
