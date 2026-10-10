import 'dart:io';
import 'dart:ui' as ui;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:planit_mobile/app/planit_app.dart';
import 'package:planit_mobile/core/auth/application/providers.dart';
import 'package:planit_mobile/core/auth/data/auth_repository.dart';
import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/core/database/providers.dart';
import 'package:planit_mobile/core/design_system/app_theme.dart';
import 'package:planit_mobile/features/local_wallet/data/wallet_store.dart';
import 'package:planit_mobile/features/local_wallet/presentation/wallet_screen.dart';
import 'package:planit_mobile/features/offline_finance/application/providers.dart';
import 'package:planit_mobile/features/offline_finance/domain/report_period.dart';
import 'wallet_store_test.dart' show cash, expense;

class _Auth extends Mock implements AuthRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('PLANIT_CAPTURE_QA')) {
      final fonts = '../.qa-docs/flutter/bin/cache/artifacts/material_fonts/';
      for (final font in {
        'Roboto': 'roboto-regular.ttf',
        'MaterialIcons': 'materialicons-regular.otf',
      }.entries) {
        final loader = FontLoader(font.key)
          ..addFont(
            File(
              fonts + font.value,
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        await loader.load();
      }
    }
  });
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.abrghaze.planit/privacy_lock'),
          (_) async => false,
        );
  });
  testWidgets(
    'fresh install creates account and expense without registration or network and reopens saved data',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final auth = _Auth();
      when(auth.restore).thenAnswer(
        (_) async => const AuthRestoreResult(session: null, offline: true),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authRepositoryProvider.overrideWithValue(auth),
          ],
          child: const PlanItApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Create your first account'), findsOneWidget);
      expect(find.text('Email'), findsNothing);
      await tester.tap(find.text('Create your first account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Cash',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Opening balance'),
        '1000',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('1,000.00 MAD'), findsWidgets);
      await tester.tap(find.text('Add money record'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount (MAD)'),
        '25.1234',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Note'),
        'Lunch',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Save'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      final stored = await WalletStore(db).read();
      expect(stored.entries.single.amount.toApiString(), '25.1234');
      expect(stored.balance(stored.accounts.single).toApiString(), '974.8766');
      expect(find.text('25.1234 MAD'), findsWidgets);
      verifyNever(
        () => auth.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authRepositoryProvider.overrideWithValue(auth),
          ],
          child: const PlanItApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('974.8766 MAD'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'small phone large text supports all report choices and management pages without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = WalletStore(db);
      await store.saveAccount(cash());
      await store.saveEntry(expense('food', '20'));
      final auth = _Auth();
      when(auth.restore).thenAnswer(
        (_) async => const AuthRestoreResult(session: null, offline: true),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authRepositoryProvider.overrideWithValue(auth),
            localClockProvider.overrideWithValue(DateTime(2026, 10, 10, 12)),
          ],
          child: MaterialApp(
            theme: PlanItTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const WalletScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byType(DropdownButtonFormField<ReportSpan>),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      for (final label in ['Day', 'Week', 'Year', 'Month']) {
        await tester.ensureVisible(
          find.byType(DropdownButtonFormField<ReportSpan>),
        );
        await tester.tap(find.byType(DropdownButtonFormField<ReportSpan>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      for (final label in ['Records', 'Plans', 'Settings']) {
        await tester.tap(find.widgetWithText(NavigationDestination, label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('render offline dashboard for visual review', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = WalletStore(db);
    await store.saveAccount(cash());
    await store.saveEntry(expense('food', '20'));
    final auth = _Auth();
    when(auth.restore).thenAnswer(
      (_) async => const AuthRestoreResult(session: null, offline: true),
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          authRepositoryProvider.overrideWithValue(auth),
          localClockProvider.overrideWithValue(DateTime(2026, 10, 10, 12)),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: PlanItTheme.light,
            home: const WalletScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('PLANIT_CAPTURE_QA')) {
      Future<void> capture(String name) async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File('../artifacts/offline-qa/$name.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      }

      await tester.runAsync(() => capture('dashboard'));
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      await tester.runAsync(() => capture('report'));
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      await tester.runAsync(() => capture('breakdown'));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
