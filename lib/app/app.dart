import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_providers.dart';
import 'router.dart';
import 'theme.dart';

/// Root widget: Material 3 theme (light + dark) and the go_router config.
class CampusApp extends ConsumerWidget {
  const CampusApp({super.key, this.useGoogleFont = true});

  /// Disabled in tests so no font is fetched from the network.
  final bool useGoogleFont;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Campus Reports',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(useGoogleFont: useGoogleFont),
      darkTheme: AppTheme.dark(useGoogleFont: useGoogleFont),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
