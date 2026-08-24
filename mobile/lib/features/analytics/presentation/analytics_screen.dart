import 'package:flutter/material.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(PlanItSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Analytics',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: PlanItSpacing.sm),
          Text(
            'Every chart will drill down to its source transactions.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          const Center(child: Text('Add account activity to unlock insights.')),
          const Spacer(),
        ],
      ),
    );
  }
}
