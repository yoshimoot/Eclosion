import 'package:egg_timer/lab/egg_geometry_preview.dart';
import 'package:egg_timer/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('V11.49: organic appears immediately in compact Chrome UI',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // This is the app's ACTUAL entry point, not a hand-selected route.
    await tester.pumpWidget(const MyApp());
    expect(find.byType(EggGeometryPreview), findsOneWidget);
    expect(find.text('Atelier Éclosion'), findsNothing);

    final selectorFinder = find.byKey(const Key('egg-preview-mode'));
    expect(selectorFinder, findsOneWidget);
    var selector = tester.widget<SegmentedButton<int>>(selectorFinder);
    expect(selector.selected, {4});
    expect(selector.segments.map((segment) => segment.value), [4, 3]);
    expect(find.text('Organique'), findsOneWidget);
    expect(find.text('V11.32'), findsOneWidget);
    expect(find.text('Organique · V11.49'),
        findsOneWidget);
    expect(find.text('Fragments encore attachés : 3 / 3'), findsOneWidget);
    expect(find.byKey(const Key('exit-sequence-progress')), findsOneWidget);
    expect(find.text('Lire'), findsOneWidget);
    expect(find.text('Rejouer'), findsOneWidget);
    expect(find.text('Contours des fragments'), findsNothing);

    // These old laboratory controls must not clutter or overflow Chrome.
    for (final name in [
      'Assemblé',
      'Écarté',
      'Pivot',
      'Inclinaison 3D des panneaux',
      'Panneau gauche',
      'Panneau droit',
      'Face intérieure arrière',
    ]) {
      expect(find.textContaining(name), findsNothing);
    }
    expect(tester.takeException(), isNull);

    // A single touch restores V11.32 for comparison; the original
    // geometry/motion implementation is not modified or re-authored.
    selector.onSelectionChanged!({3});
    await tester.pump();
    expect(find.text('Référence V11.32'),
        findsOneWidget);
    expect(find.text('Panneaux attachés'), findsOneWidget);
    expect(tester.takeException(), isNull);

    selector = tester.widget<SegmentedButton<int>>(selectorFinder);
    selector.onSelectionChanged!({4});
    await tester.pump();
    expect(find.text('Organique · V11.49'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
