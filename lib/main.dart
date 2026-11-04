import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'firebase_options.dart';
import 'providers/retry_policy.dart';

/// App bootstrap: initialise Firebase, then run the app inside a
/// [ProviderScope] so every Riverpod provider is available.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(retry: noAutomaticRetry, child: CampusApp()));
}
