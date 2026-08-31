import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/design_system/app_theme.dart';

void main() {
  test('text fields retain visible borders in every interactive state', () {
    final decoration = PlanItTheme.light.inputDecorationTheme;

    final enabled = decoration.enabledBorder! as OutlineInputBorder;
    final focused = decoration.focusedBorder! as OutlineInputBorder;
    final error = decoration.errorBorder! as OutlineInputBorder;
    final focusedError = decoration.focusedErrorBorder! as OutlineInputBorder;

    expect(enabled.borderSide.style, BorderStyle.solid);
    expect(focused.borderSide.style, BorderStyle.solid);
    expect(focused.borderSide.width, 2);
    expect(focused.borderSide.color, PlanItTheme.light.colorScheme.primary);
    expect(error.borderSide.style, BorderStyle.solid);
    expect(focusedError.borderSide.width, 2);
  });
}
