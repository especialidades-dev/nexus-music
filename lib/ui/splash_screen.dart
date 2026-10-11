import 'package:flutter/material.dart';

import '/ui/home.dart';

/// Launch screen shown while the app boots.
///
/// Displays the Nexus Music (pak-choi) logo so the correct branding appears at
/// startup instead of the old Harmony Music logo. It mirrors the launch/splash
/// behaviour of the mobile builds and then hands control over to [Home].
class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({super.key});

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Keep it short so the desktop launch stays snappy: enough to paint the
    // brand on the very first frame, then swap to the real UI.
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const Home();

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icons/icon.png',
              width: 160,
              height: 160,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(height: 20),
            Text(
              'Nexus Music',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}