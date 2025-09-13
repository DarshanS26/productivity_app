import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // NEW: For state management
import 'task_provider.dart'; // NEW: Import TaskProvider
import 'services/storage_service.dart';
import 'screens/todo_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/history_screen.dart';

void main() async {
  print('Starting Productivity App...');
  WidgetsFlutterBinding.ensureInitialized();
  print('WidgetsFlutterBinding initialized');

  // Initialize new storage service
  try {
    print('Main: Initializing storage service...');
    await StorageService.initialize();
    print('Main: Storage service initialized successfully');

    // Test if we can get available dates
    final dates = await StorageService.getAvailableDates();
    print('Main: Found ${dates.length} available dates: ${dates.map((d) => d.toString()).toList()}');
  } catch (e, stackTrace) {
    print('Main: Failed to initialize storage service: $e');
    print('Main: Stack trace: $stackTrace');
    // Continue anyway - the service will handle errors gracefully
  }

  print('Running app...');
  runApp(
    // NEW: Wrap app with Providers for reactive state management
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => TaskProvider(), // TaskProvider will load today's tasks when needed
        ),
      ],
      child: const ProductivityApp(),
    ),
  );
}

class ProductivityApp extends StatelessWidget {
  const ProductivityApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF569CD6);
    const Color scaffoldBackgroundColor = Color(0xFF1E1E1E);
    const Color cardColor = Color(0xFF252526);
    const Color mutedTextColor = Color(0xFF858585);
    final TextTheme originalTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return MaterialApp(
      title: 'Productivity App',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: scaffoldBackgroundColor,
        cardColor: cardColor,
        colorScheme: ColorScheme.dark(
          primary: primaryColor,
          secondary: primaryColor,
          surface: cardColor,
          surfaceTint: cardColor,
          onSurface: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: scaffoldBackgroundColor,
          elevation: 0,
          titleTextStyle: GoogleFonts.inter(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        textTheme: originalTextTheme.copyWith(
          headlineLarge: originalTextTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
          headlineMedium: originalTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          headlineSmall: originalTextTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          titleLarge: originalTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          titleMedium: originalTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          titleSmall: originalTextTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          bodyLarge: originalTextTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          bodyMedium: originalTextTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          bodySmall: originalTextTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500, color: mutedTextColor),
          labelLarge: originalTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
          labelMedium: originalTextTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
          labelSmall: originalTextTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500, color: mutedTextColor),
        ),
        cardTheme: CardThemeData(
          elevation: 4.0,
          shadowColor: Colors.black.withAlpha(153),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
        ),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
          hoverColor: primaryColor.withAlpha(204),
          shape: const CircleBorder(),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryColor,
          ),
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  Timer? _timer;
  DateTime? _lastReminderTime;

  final GlobalKey<HistoryScreenState> _historyKey = GlobalKey<HistoryScreenState>();

  late final List<Widget> _widgetOptions = <Widget>[
    ToDoScreen(
      onTasksUpdated: () {
        // Refresh history screen when tasks are updated
        print('Tasks updated callback triggered');
        _historyKey.currentState?.refreshHistory();
      },
    ),
    const JournalScreen(),
    HistoryScreen(key: _historyKey),
  ];

  @override
  void initState() {
    super.initState();
    _setupReminderTimer();
  }

  void _setupReminderTimer() {
    // Check every 15 minutes, but only show reminder if conditions are met
    _timer = Timer.periodic(const Duration(minutes: 15), (Timer t) {
      if (!mounted) return;
      
      final now = DateTime.now();
      // Only show reminder during active hours (8 AM to 10 PM)
      if (now.hour < 8 || now.hour >= 22) return;

      // Only show reminder if an hour has passed since the last one
      if (_lastReminderTime != null && 
          now.difference(_lastReminderTime!) < const Duration(hours: 1)) {
        return;
      }

      _lastReminderTime = now;
      if (!mounted) return;
      
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Remember to stay focused and take breaks when needed!'),
            duration: Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    // Always refresh history when switching to it
    if (index == 2) { // History tab index (now at position 2)
      _historyKey.currentState?.refreshHistory();
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle_outline),
              label: 'To-Do',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.book_outlined),
              label: 'Journal',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'History',
            ),
          ],
          backgroundColor: Theme.of(context).colorScheme.surface,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          enableFeedback: false,
        ),
      ),
    );
  }
}
