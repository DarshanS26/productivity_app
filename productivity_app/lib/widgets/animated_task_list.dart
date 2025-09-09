import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/task.dart';
import '../widgets/app_card.dart';

class AnimatedTaskList extends StatefulWidget {
  final List<Task> tasks;
  final bool showCompleted;
  final ScrollController controller;
  final Function(Task task, bool isDone) onTaskToggle;
  final Function(Task task)? onDeleteTask;
  final Function(Task task)? onShowDetails;

  const AnimatedTaskList({
    super.key,
    required this.tasks,
    required this.showCompleted,
    required this.controller,
    required this.onTaskToggle,
    this.onDeleteTask,
    this.onShowDetails,
  });

  @override
  State<AnimatedTaskList> createState() => _AnimatedTaskListState();
}

class _AnimatedTaskListState extends State<AnimatedTaskList> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    return AnimationLimiter(
      child: ListView.builder(
        controller: widget.controller,
        padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0, bottom: 80.0),
        itemCount: widget.tasks.length,
        itemBuilder: (context, index) {
          final task = widget.tasks[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Hero(
                  tag: 'task-${task.id}',
                  child: Material(
                    type: MaterialType.transparency,
                    child: AppCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: task.isDone,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    widget.onTaskToggle(task, value);
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
                                          child: AnimatedDefaultTextStyle(
                                            duration: const Duration(milliseconds: 300),
                                            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  decoration: task.isDone ? TextDecoration.lineThrough : TextDecoration.none,
                                                  color: task.isDone
                                                      ? Theme.of(context).textTheme.bodySmall?.color
                                                      : Theme.of(context).textTheme.titleMedium?.color,
                                                ),
                                            child: Text(task.title),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (!widget.showCompleted && widget.onDeleteTask != null)
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20),
                                            color: colorScheme.error.withOpacity(0.7),
                                            onPressed: () => widget.onDeleteTask!(task),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 32,
                                              minHeight: 32,
                                            ),
                                          ),
                                        if (widget.showCompleted && widget.onShowDetails != null)
                                          IconButton(
                                            icon: const Icon(Icons.edit_note, size: 20),
                                            color: colorScheme.primary.withOpacity(0.8),
                                            onPressed: () => widget.onShowDetails!(task),
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
                                          'Planned: ${task.plannedHours}h',
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
                      ),
                    ),
                  ),
              ),
            ),
          );
        },
      ),
    );
  }
}
