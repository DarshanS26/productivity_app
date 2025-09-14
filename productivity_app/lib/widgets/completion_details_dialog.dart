import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import 'star_rating.dart';
import 'animated_widgets.dart';

class CompletionDetailsDialog extends StatefulWidget {
  final Task task;
  final Function(Task updatedTask) onSave;

  const CompletionDetailsDialog({
    super.key,
    required this.task,
    required this.onSave,
  });

  @override
  State<CompletionDetailsDialog> createState() => _CompletionDetailsDialogState();
}

class _CompletionDetailsDialogState extends State<CompletionDetailsDialog> {
  late TextEditingController _descriptionController;
  late TextEditingController _actualHoursController;
  int _rating = 0;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.task.completionDescription ?? '');
    // Use saved actualHours if available, otherwise use plannedHours as default
    final initialHours = widget.task.actualHours ?? widget.task.plannedHours;
    _actualHoursController = TextEditingController(text: initialHours.toString());
    _rating = widget.task.rating ?? 0;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _actualHoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
      child: AnimatedDialogWrapper(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.task_alt,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Completion Details',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Task title
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: colorScheme.primary.withOpacity(0.8),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.task.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.lineThrough,
                            color: colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Description section
                Text(
                  'How did it go?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Add a note about how the task went...',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.5),
                      fontFamily: 'Inter',
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  maxLines: 3,
                  maxLength: 200,
                  style: TextStyle(color: colorScheme.onSurface, fontFamily: 'Inter'),
                ),
                const SizedBox(height: 24),

                // Actual Hours section
                Text(
                  'Actual Hours Worked:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _actualHoursController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Enter actual hours worked...',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.5),
                      fontFamily: 'Inter',
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide.none,
                    ),
                    suffixText: 'hours',
                    suffixStyle: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontFamily: 'Inter',
                    ),
                  ),
                  style: TextStyle(color: colorScheme.onSurface, fontFamily: 'Inter'),
                  inputFormatters: [
                    // Allow only numbers and decimal point
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                  ],
                ),
                const SizedBox(height: 24),

                // Rating section
                Text(
                  'Rate your performance:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: StarRating(
                    rating: _rating,
                    onChanged: (rating) {
                      setState(() {
                        _rating = rating;
                      });
                    },
                    size: 36,
                    activeColor: colorScheme.primary,
                    inactiveColor: colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
                const SizedBox(height: 32),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Parse actual hours
                          double? actualHours;
                          if (_actualHoursController.text.trim().isNotEmpty) {
                            actualHours = double.tryParse(_actualHoursController.text.trim());
                            if (actualHours == null || actualHours < 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a valid number for actual hours'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                          }

                          final updatedTask = Task(
                            id: widget.task.id,
                            title: widget.task.title,
                            isDone: widget.task.isDone,
                            createdAt: widget.task.createdAt,
                            dueTime: widget.task.dueTime,
                            plannedHours: widget.task.plannedHours,
                            completionDescription: _descriptionController.text.trim().isEmpty
                                ? null
                                : _descriptionController.text.trim(),
                            rating: _rating == 0 ? null : _rating,
                            actualHours: actualHours,
                          );
                          widget.onSave(updatedTask);
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
