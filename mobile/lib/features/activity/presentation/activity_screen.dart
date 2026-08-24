import 'package:flutter/material.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(PlanItSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Activity',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: PlanItSpacing.md),
          const SearchBar(
            leading: Icon(Icons.search),
            hintText: 'Search transactions',
          ),
          const Spacer(),
          const Center(child: Text('Transactions will appear here.')),
          const Spacer(),
        ],
      ),
    );
  }
}
