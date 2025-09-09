import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/journal_entry.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final Set<String> _expandedEntries = {};
  bool _isLoading = true;
  List<JournalEntry> _entries = [];
  // ignore: unused_field
  List<DateTime> _availableDates = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _loadEntries();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Failed to initialize journal screen: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadEntries() async {
    print('JournalScreen: Loading all journal entries');
    try {
      // Get all available dates that have journal entries
      final availableDates = await _getAvailableJournalDates();
      print('JournalScreen: Found ${availableDates.length} dates with journals');

      // Load journals from all dates
      List<JournalEntry> allEntries = [];
      for (final date in availableDates) {
        final entries = await StorageService.loadJournalsForDate(date);
        allEntries.addAll(entries);
        print('JournalScreen: Loaded ${entries.length} entries for ${date}');
      }

      // Sort entries by creation date (newest first)
      allEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _entries = allEntries;
          _availableDates = availableDates;
        });
      }
      print('JournalScreen: Total loaded ${allEntries.length} journal entries');
    } catch (e) {
      print('JournalScreen: Error loading journal entries: $e');
      if (mounted) {
        setState(() {
          _entries = [];
          _availableDates = [];
        });
      }
    }
  }

  Future<List<DateTime>> _getAvailableJournalDates() async {
    print('JournalScreen: Getting available journal dates');
    // For now, we'll check a range of recent dates
    // In a production app, you might want to store this metadata
    List<DateTime> datesWithJournals = [];
    final now = DateTime.now();

    // Check the last 30 days for journal entries
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      try {
        final entries = await StorageService.loadJournalsForDate(date);
        print('JournalScreen: Checked date ${date}: ${entries.length} entries');
        if (entries.isNotEmpty) {
          datesWithJournals.add(date);
          print('JournalScreen: Found journal entries for ${date}');
        }
      } catch (e) {
        // Skip dates with errors
        print('JournalScreen: Error checking date ${date}: $e');
      }
    }

    print('JournalScreen: Found ${datesWithJournals.length} dates with journal entries');
    return datesWithJournals;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
      ),
      body: _entries.isEmpty
          ? Center(
              child: Text(
                "No journal entries yet.",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
              ),
            )
          : ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entry = _entries.reversed.toList()[index];
              final isExpanded = _expandedEntries.contains(entry.id);
              final contentPreview = entry.content.length > 150
                  ? '${entry.content.substring(0, 150)}...'
                  : entry.content;

              return Dismissible(
                key: Key(entry.id),
                background: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20.0),
                  child: const Icon(Icons.edit, color: Colors.white),
                ),
                secondaryBackground: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20.0),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    // Delete
                    return await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Entry?'),
                        content: const Text(
                          'Are you sure you want to delete this journal entry?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: colorScheme.primary),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              'Delete',
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ),
                        ],
                      ),
                    ) ?? false;
                  } else {
                    // Edit
                    _showEditEntryDialog(context, entry);
                    return false; // Do not dismiss
                  }
                },
                onDismissed: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    // Delete the entry - we need to save it to the correct date
                    final entryDate = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);
                    final entriesForDate = await StorageService.loadJournalsForDate(entryDate);
                    final updatedEntries = entriesForDate.where((e) => e.id != entry.id).toList();
                    await StorageService.saveJournalsForDate(entryDate, updatedEntries);
                    await _loadEntries();
                  }
                },
                child: AppCard(
                  child: InkWell(
                    onTap: () => setState(() {
                      if (isExpanded) {
                        _expandedEntries.remove(entry.id);
                      } else {
                        _expandedEntries.add(entry.id);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isExpanded ? entry.content : contentPreview,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat.yMMMd().add_jm().format(entry.createdAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (!isExpanded && entry.content.length > 150) ...[
                                const Spacer(),
                                Text(
                                  'Tap to read more',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: colorScheme.primary,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEntryDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddEntryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _JournalEntryDialog(
        title: 'New Journal Entry',
        initialContent: '',
        onSave: (content) async {
          if (content.isNotEmpty) {
            final now = DateTime.now();
            final newEntry = JournalEntry(
              id: now.millisecondsSinceEpoch.toString(),
              content: content,
              createdAt: now,
            );
            await StorageService.addJournalEntry(newEntry);
            await _loadEntries();
          }
        },
      ),
    );
  }

  void _showEditEntryDialog(BuildContext context, JournalEntry entry) {
    showDialog(
      context: context,
      builder: (context) => _JournalEntryDialog(
        title: 'Edit Journal Entry',
        initialContent: entry.content,
        onSave: (content) async {
          if (content.isNotEmpty) {
            final updatedEntry = JournalEntry(
              id: entry.id,
              content: content,
              createdAt: entry.createdAt,
            );
            // Remove old entry and add updated one
            final entryDate = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);
            final entriesForDate = await StorageService.loadJournalsForDate(entryDate);
            final updatedEntries = entriesForDate.where((e) => e.id != entry.id).toList();
            updatedEntries.add(updatedEntry);
            await StorageService.saveJournalsForDate(entryDate, updatedEntries);
            await _loadEntries();
          }
        },
      ),
    );
  }
}

class _JournalEntryDialog extends StatefulWidget {
  final String title;
  final String initialContent;
  final Function(String) onSave;

  const _JournalEntryDialog({
    required this.title,
    required this.initialContent,
    required this.onSave,
  });

  @override
  State<_JournalEntryDialog> createState() => _JournalEntryDialogState();
}

class _JournalEntryDialogState extends State<_JournalEntryDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
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
                    Icons.edit_note,
                    color: colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
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
              const SizedBox(height: 24),
              
              // Text input
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  hintStyle: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: colorScheme.surface.withOpacity(0.3),
                ),
                autofocus: true,
                maxLines: 12,
                keyboardType: TextInputType.multiline,
                style: TextStyle(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 24),
              
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
                        final content = _controller.text.trim();
                        if (content.isNotEmpty) {
                          widget.onSave(content);
                          Navigator.of(context).pop();
                        }
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
    );
  }
}
