import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One bottom-navigation destination and the shell branch it opens.
class ShellDestination {
  const ShellDestination({
    required this.branchIndex,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final int branchIndex;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Branch order in the router's `StatefulShellRoute`.
abstract final class ShellBranch {
  static const feed = 0;
  static const report = 1;
  static const staff = 2;
  static const profile = 3;
}

const _feed = ShellDestination(
  branchIndex: ShellBranch.feed,
  label: 'Feed',
  icon: Icons.view_agenda_outlined,
  selectedIcon: Icons.view_agenda,
);
const _report = ShellDestination(
  branchIndex: ShellBranch.report,
  label: 'Report',
  icon: Icons.add_circle_outline,
  selectedIcon: Icons.add_circle,
);
const _staff = ShellDestination(
  branchIndex: ShellBranch.staff,
  label: 'Dashboard',
  icon: Icons.space_dashboard_outlined,
  selectedIcon: Icons.space_dashboard,
);
const _profile = ShellDestination(
  branchIndex: ShellBranch.profile,
  label: 'Profile',
  icon: Icons.person_outline,
  selectedIcon: Icons.person,
);

/// Scaffold with the bottom navigation bar shared by the signed-in screens.
///
/// Tabs depend on the role:
/// - students: Feed, Report, Profile;
/// - staff ([isStaff]): Dashboard, Feed, Profile.
///
/// Hiding tabs is a usability measure; the router guard and Security Rules
/// do the real enforcement.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.isStaff,
  });

  final StatefulNavigationShell navigationShell;
  final bool isStaff;

  List<ShellDestination> get _destinations => isStaff
      ? const [_staff, _feed, _profile]
      : const [_feed, _report, _profile];

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations;
    final selected = destinations.indexWhere(
      (d) => d.branchIndex == navigationShell.currentIndex,
    );

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected < 0 ? 0 : selected,
        onDestinationSelected: (index) {
          final branch = destinations[index].branchIndex;
          navigationShell.goBranch(
            branch,
            // Tapping the active tab returns to that tab's first screen.
            initialLocation: branch == navigationShell.currentIndex,
          );
        },
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
