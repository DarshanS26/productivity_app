import 'dart:async';
//import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Manages window state persistence for desktop applications
class WindowStateManager {
  static const String _widthKey = 'window_width';
  static const String _heightKey = 'window_height';
  static const String _offsetXKey = 'window_offsetX';
  static const String _offsetYKey = 'window_offsetY';
  static const String _isMaximizedKey = 'window_isMaximized';
  static const String _isMinimizedKey = 'window_isMinimized';
  static const String _lastSavedKey = 'window_last_saved';

  // Default window dimensions
  static const double _defaultWidth = 1200;
  static const double _defaultHeight = 800;
  static const double _minWidth = 800;
  static const double _minHeight = 600;

  Timer? _saveTimer;
  static const Duration _saveDelay = Duration(milliseconds: 500);

  /// Initialize window state management
  static Future<void> initialize() async {
    try {
      await windowManager.ensureInitialized();

      // Set up window options with defaults
      final windowOptions = WindowOptions(
        size: const Size(_defaultWidth, _defaultHeight),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        minimumSize: const Size(_minWidth, _minHeight),
      );

      // Wait for window to be ready and restore state
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await _restoreWindowState();
        await windowManager.show();
        await windowManager.focus();
      });

      print('WindowStateManager: Initialized successfully');
    } catch (e) {
      print('WindowStateManager: Failed to initialize: $e');
      // Fallback to basic window setup
      await windowManager.ensureInitialized();
      final windowOptions = WindowOptions(
        size: const Size(_defaultWidth, _defaultHeight),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        minimumSize: const Size(_minWidth, _minHeight),
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }
  }

  /// Restore the saved window state
  static Future<void> _restoreWindowState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if we have saved state
      final lastSaved = prefs.getInt(_lastSavedKey);
      if (lastSaved == null) {
        print('WindowStateManager: No saved state found, using defaults');
        return;
      }

      // Check if saved state is recent (within last 24 hours)
      final savedTime = DateTime.fromMillisecondsSinceEpoch(lastSaved);
      final now = DateTime.now();
      if (now.difference(savedTime).inHours > 24) {
        print('WindowStateManager: Saved state is too old, using defaults');
        return;
      }

      // Restore window state
      final isMaximized = prefs.getBool(_isMaximizedKey) ?? false;
      final isMinimized = prefs.getBool(_isMinimizedKey) ?? false;

      if (isMaximized) {
        await windowManager.maximize();
        print('WindowStateManager: Restored maximized window');
      } else if (isMinimized) {
        await windowManager.minimize();
        print('WindowStateManager: Restored minimized window');
      } else {
        // Restore size and position
        final width = prefs.getDouble(_widthKey) ?? _defaultWidth;
        final height = prefs.getDouble(_heightKey) ?? _defaultHeight;
        final offsetX = prefs.getDouble(_offsetXKey);
        final offsetY = prefs.getDouble(_offsetYKey);

        // Validate and adjust size
        final validatedSize = _validateWindowSize(Size(width, height));
        await windowManager.setSize(validatedSize);

        // Validate and adjust position if available
        if (offsetX != null && offsetY != null) {
          final validatedPosition = await _validateWindowPosition(Offset(offsetX, offsetY), validatedSize);
          if (validatedPosition != null) {
            await windowManager.setPosition(validatedPosition);
          }
        }

        print('WindowStateManager: Restored window size: ${validatedSize.width}x${validatedSize.height}');
      }
    } catch (e) {
      print('WindowStateManager: Failed to restore window state: $e');
      // Continue with default state
    }
  }

  /// Save the current window state
  static Future<void> saveWindowState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get current window state
      final isMaximized = await windowManager.isMaximized();
      final isMinimized = await windowManager.isMinimized();

      // Save window state
      await prefs.setBool(_isMaximizedKey, isMaximized);
      await prefs.setBool(_isMinimizedKey, isMinimized);
      await prefs.setInt(_lastSavedKey, DateTime.now().millisecondsSinceEpoch);

      if (!isMaximized && !isMinimized) {
        // Save size and position only if not maximized or minimized
        final size = await windowManager.getSize();
        final position = await windowManager.getPosition();

        await prefs.setDouble(_widthKey, size.width);
        await prefs.setDouble(_heightKey, size.height);
        await prefs.setDouble(_offsetXKey, position.dx);
        await prefs.setDouble(_offsetYKey, position.dy);

        print('WindowStateManager: Saved window state - Size: ${size.width}x${size.height}, Position: (${position.dx}, ${position.dy})');
      } else {
        print('WindowStateManager: Saved window state - ${isMaximized ? 'Maximized' : 'Minimized'}');
      }
    } catch (e) {
      print('WindowStateManager: Failed to save window state: $e');
    }
  }

  /// Validate window size to ensure it's within acceptable bounds
  static Size _validateWindowSize(Size size) {
    double width = size.width.clamp(_minWidth, double.infinity);
    double height = size.height.clamp(_minHeight, double.infinity);

    // Get screen size for additional validation
    // For now, we'll use reasonable maximums
    const double maxWidth = 3840; // 4K width
    const double maxHeight = 2160; // 4K height

    width = width.clamp(_minWidth, maxWidth);
    height = height.clamp(_minHeight, maxHeight);

    return Size(width, height);
  }

  /// Validate window position to ensure it's visible on screen
  static Future<Offset?> _validateWindowPosition(Offset position, Size size) async {
    try {
      // Get screen information
      final screenSize = await _getScreenSize();

      // Check if window would be visible on screen
      final windowRight = position.dx + size.width;
      final windowBottom = position.dy + size.height;

      // Allow some tolerance (window can be partially off-screen)
      const double tolerance = 100;

      if (windowRight < -tolerance || position.dx > screenSize.width + tolerance ||
          windowBottom < -tolerance || position.dy > screenSize.height + tolerance) {
        print('WindowStateManager: Saved position is off-screen, centering window');
        return null; // Return null to center the window
      }

      return position;
    } catch (e) {
      print('WindowStateManager: Failed to validate window position: $e');
      return null;
    }
  }

  /// Get the primary screen size
  static Future<Size> _getScreenSize() async {
    try {
      // For now, we'll use a reasonable default screen size
      // In a production app, you might want to use a package like screen_retriever
      // to get actual screen information
      return const Size(1920, 1080); // Full HD as default
    } catch (e) {
      print('WindowStateManager: Failed to get screen size: $e');
      return const Size(1920, 1080);
    }
  }

  /// Start listening for window state changes
  static void startListening() {
    // Listen for window events
    windowManager.addListener(_WindowEventListener());
    print('WindowStateManager: Started listening for window events');
  }

  /// Stop listening for window state changes
  static void stopListening() {
    windowManager.removeListener(_WindowEventListener());
    print('WindowStateManager: Stopped listening for window events');
  }
}

/// Window event listener for automatic state saving
class _WindowEventListener extends WindowListener {
  Timer? _saveTimer;
  static const Duration _saveDelay = Duration(milliseconds: 500);

  @override
  void onWindowMoved() {
    _scheduleSave();
  }

  @override
  void onWindowResized() {
    _scheduleSave();
  }

  @override
  void onWindowMaximize() {
    WindowStateManager.saveWindowState();
  }

  @override
  void onWindowUnmaximize() {
    WindowStateManager.saveWindowState();
  }

  @override
  void onWindowMinimize() {
    WindowStateManager.saveWindowState();
  }

  @override
  void onWindowRestore() {
    WindowStateManager.saveWindowState();
  }

  @override
  Future<void> onWindowClose() async {
    // Save state before closing
    await WindowStateManager.saveWindowState();
    await windowManager.destroy();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, () {
      WindowStateManager.saveWindowState();
    });
  }
}