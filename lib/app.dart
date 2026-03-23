import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/live_sms/live_sms_overlay.dart';
import 'providers/live_sms_provider.dart';

class EchelonApp extends ConsumerWidget {
  const EchelonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Bootstrap the live SMS listener (subscribes on first read).
    ref.watch(liveSmsProvider);

    return MaterialApp.router(
      title: 'The Ledger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      // Wraps the entire navigator so banners appear above every screen.
      builder: (context, child) => LiveSmsOverlay(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
