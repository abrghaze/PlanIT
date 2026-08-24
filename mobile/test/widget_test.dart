import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/app/planit_app.dart';

void main() {
  testWidgets('application shell starts and navigates', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: PlanItApp()));
    await tester.pumpAndSettle();

    expect(find.text('PlanIT'), findsOneWidget);
    expect(find.text('Add your first account'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Activity'));
    await tester.pumpAndSettle();

    expect(find.text('Search transactions'), findsOneWidget);
  });
}
