import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:productivity_app/main.dart';
import 'package:productivity_app/models/journal_entry.dart';
import 'package:productivity_app/models/task.dart';

void main() {
  // A mock Hive setup for testing is required.
  // This setup initializes Hive in a temporary directory for the tests.
  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(JournalEntryAdapter());
    await Hive.openBox<Task>('tasks');
    await Hive.openBox<JournalEntry>('journal_entries');
  });

  // Clean up the Hive boxes after tests.
  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('App navigation smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProductivityApp());

    // Verify that our app starts on the To-Do screen.
    expect(find.text('To-Do'), findsOneWidget);
    expect(find.text('No tasks yet.'), findsOneWidget);

    // Tap the 'Journal' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.book_outlined));
    await tester.pump();

    // Verify that we have navigated to the Journal screen.
    expect(find.text('No journal entries yet.'), findsOneWidget);

    // Tap the 'Stats' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.show_chart));
    await tester.pump();

    // Verify that we have navigated to the Stats screen.
    expect(find.text('No tasks created this week.'), findsOneWidget);
  });
}
