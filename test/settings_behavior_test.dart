import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simon_says/main.dart';

Future<void> _setPhoneSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_rounded).first);
  await tester.pumpAndSettle();
}

Future<void> _returnToMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
  await tester.pumpAndSettle();
}

Future<void> _openFocusMode(WidgetTester tester) async {
  await tester.tap(find.text('Calm Memory Run'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _disposeGameScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _toggleSetting(WidgetTester tester, String label) async {
  final Finder scrollable = find.byType(Scrollable).first;
  final Finder labelFinder = find.text(label);
  await tester.scrollUntilVisible(labelFinder, 300, scrollable: scrollable);
  await tester.pumpAndSettle();

  final Offset labelPosition = tester.getCenter(labelFinder);
  final Finder switchFinder = find.byType(Switch);
  for (
    int index = 0;
    index < tester.widgetList<Switch>(switchFinder).length;
    index++
  ) {
    final Finder candidate = switchFinder.at(index);
    final Offset switchPosition = tester.getCenter(candidate);
    if ((switchPosition.dy - labelPosition.dy).abs() < 80) {
      await tester.tap(candidate);
      await tester.pumpAndSettle();
      return;
    }
  }

  fail('Could not find switch for "$label".');
}

void main() {
  testWidgets('home screen renders mode cards', (WidgetTester tester) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(const NeuralRecallApp());

    expect(find.text('Calm Memory Run'), findsOneWidget);
    expect(find.text('Rapid Reflex Run'), findsOneWidget);
    expect(find.text('V2.0.4'), findsOneWidget);
  });

  testWidgets('changing theme updates app colors', (WidgetTester tester) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(const NeuralRecallApp());
    await _openSettings(tester);

    await tester.scrollUntilVisible(
      find.text('Ember Glow'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ember Glow'));
    await tester.pumpAndSettle();

    final Icon headerIcon = tester.widget<Icon>(
      find.byIcon(Icons.memory_rounded).first,
    );
    expect(
      headerIcon.color,
      NeuralTheme.paletteFor(AppThemeProfile.emberGlow).primary,
    );

    await _returnToMenu(tester);

    final Icon menuIcon = tester.widget<Icon>(
      find.byIcon(Icons.memory_rounded).first,
    );
    expect(
      menuIcon.color,
      NeuralTheme.paletteFor(AppThemeProfile.emberGlow).primary,
    );
  });

  testWidgets('training hints setting hides the gameplay hint card', (
    WidgetTester tester,
  ) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(const NeuralRecallApp());
    await _openSettings(tester);

    await _toggleSetting(tester, 'Training Hints');
    await _returnToMenu(tester);
    await _openFocusMode(tester);

    expect(find.text('PATTERN BRIEF'), findsNothing);
    expect(find.text('FOCUS LOOP'), findsNothing);
    await _disposeGameScreen(tester);
  });

  testWidgets('confirm reset setting controls the reset dialog', (
    WidgetTester tester,
  ) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(const NeuralRecallApp());
    await _openSettings(tester);

    await _toggleSetting(tester, 'Confirm Reset');
    await _returnToMenu(tester);
    await _openFocusMode(tester);

    await tester.tap(find.byIcon(Icons.restart_alt_rounded).first);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('RESET CURRENT RUN?'), findsNothing);
    await _disposeGameScreen(tester);
  });

  test('settings backend math changes real timing and sound values', () {
    const NeuralSettings muted = NeuralSettings(
      soundEnabled: false,
      soundLevel: 0.92,
    );
    expect(muted.effectiveSoundLevel, 0.0);

    const NeuralSettings faster = NeuralSettings(sequenceSpeed: 1.2);
    expect(
      faster.tuneDuration(const Duration(milliseconds: 1000)),
      const Duration(milliseconds: 833),
    );

    const NeuralSettings reduced = NeuralSettings(
      reducedMotion: true,
      sequenceSpeed: 0.9,
    );
    expect(
      reduced.tuneDuration(const Duration(milliseconds: 1000)),
      const Duration(milliseconds: 800),
    );

    const NeuralSettings forgiving = NeuralSettings(overdriveWindowScale: 1.2);
    expect(
      forgiving.tuneOverdriveWindow(
        const Duration(milliseconds: 1800),
        round: 3,
      ),
      const Duration(milliseconds: 2004),
    );
  });
}
