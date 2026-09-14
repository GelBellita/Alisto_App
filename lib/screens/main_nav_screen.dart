import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';

class MainNavScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  late int _index = widget.initialIndex;
  DateTime? _lastBackPress;

  static const _pages = [
    HomeScreen(),
    HistoryScreen(),
    ContactsScreen(),
    ProfileScreen(),
  ];

  /// Handles the system back button/gesture.
  ///
  /// CLAUDE'S FIX: MainNavScreen is always reached via
  /// Navigator.pushAndRemoveUntil(..., (route) => false) — after login,
  /// after role selection (contact path), and after registration completes.
  /// That clears the ENTIRE navigation stack, so MainNavScreen ends up
  /// with nothing beneath it. Pressing back with nothing left to pop to
  /// isn't "no previous screen" in the app's own history — Android just
  /// starts closing the Activity, and the black frame you saw was that
  /// exit, not a broken back navigation.
  ///
  /// On top of that, the four tabs here (Home/History/Contacts/Profile)
  /// are local state, not separate routes, so the system back button had
  /// no idea a "tab" even changed — it always tried to close the whole app
  /// regardless of which tab you were on.
  ///
  /// Fix: back now (1) jumps to the Home tab first if you're on another
  /// tab, and (2) only actually exits the app after a second back press
  /// within 2 seconds — the standard "press back again to exit" pattern,
  /// instead of silently falling through to the OS exit animation.
  Future<bool> _handleBackButton() async {
    if (_index != 0) {
      setState(() => _index = 0);
      return false;
    }

    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _handleBackButton();
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _index, children: _pages),
        ),
        bottomNavigationBar: _AppBottomNav(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

class _AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _AppBottomNav({required this.currentIndex, required this.onTap});

  static const _items = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.history_rounded, label: 'History'),
    (icon: Icons.contacts_rounded, label: 'Contacts'),
    (icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 58,
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Row(
          children: List.generate(_items.length, (i) {
            final selected = i == currentIndex;
            final item = _items[i];
            final color = selected
                ? AppColors.primary
                : AppColors.textSecondary;
            return Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, size: 22, color: color),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}