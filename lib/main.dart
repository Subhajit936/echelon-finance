import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/notification_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise local notifications channel on app start
  await NotificationService().init();

  runApp(
    const ProviderScope(
      child: EchelonApp(),
    ),
  );
}
