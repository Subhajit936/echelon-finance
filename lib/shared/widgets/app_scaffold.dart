import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  int _locationToIndex(String location) {
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/transactions')) return 1;
    if (location.startsWith('/ai-buddy')) return 2;
    if (location.startsWith('/goals')) return 3;
    if (location.startsWith('/insights')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _locationToIndex(location);

    return Scaffold(
      body: Stack(
        children: [
          child,
          // Persistent settings button — top-right corner, above all content.
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: _SettingsButton(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0: context.go('/dashboard');
            case 1: context.go('/transactions');
            case 2: context.go('/ai-buddy');
            case 3: context.go('/goals');
            case 4: context.go('/insights');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Logs',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: 'AI Buddy',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'Goals',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Insights',
          ),
        ],
        backgroundColor: AppColors.surfaceContainerLowest,
        indicatorColor: AppColors.primary.withOpacity(0.12),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/settings'),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
          ),
          child: const Icon(Icons.settings_outlined, size: 20),
        ),
      ),
    );
  }
}
