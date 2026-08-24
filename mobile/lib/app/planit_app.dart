import 'package:flutter/material.dart';
import 'package:planit_mobile/app/router.dart';
import 'package:planit_mobile/core/design_system/app_theme.dart';

class PlanItApp extends StatelessWidget {
  const PlanItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PlanIT',
      debugShowCheckedModeBanner: false,
      theme: PlanItTheme.light,
      darkTheme: PlanItTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: planItRouter,
    );
  }
}
