import 'package:egg_timer/lab/egg_geometry_preview.dart';
import 'package:egg_timer/lab/egg_shell_model.dart';
import 'package:egg_timer/lab/fragment_lab.dart';
import 'package:egg_timer/lab/fragment_scene.dart';
import 'package:egg_timer/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guard the active 3D workshop route. The historical 2D FragmentScene and
/// its separate regression tests remain in the repository; they must not be
/// silently mistaken for coverage of the current 3D prototype.
void main() {
  testWidgets('Atelier 3D actif : F1 sans ancien FragmentScene', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(FragmentLab), findsOneWidget);
    expect(find.byWidgetPredicate(
      (widget) => widget is CustomPaint &&
          widget.painter is EggShellF1PreviewPainter,
    ), findsOneWidget);
    expect(find.byWidgetPredicate(
      (widget) => widget is CustomPaint &&
          widget.painter is FragmentScene,
    ), findsNothing);
    expect(find.text('Voir les maillages V11.8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Atelier 3D actif : navigation vers les vrais maillages', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    final navigation = find.text('Voir les maillages V11.8');
    await tester.ensureVisible(navigation);
    await tester.pumpAndSettle();
    await tester.tap(navigation);
    await tester.pumpAndSettle();

    expect(find.byType(EggGeometryPreview), findsOneWidget);
    expect(find.text('Éclosion · maillages 3D'), findsOneWidget);
    expect(find.byType(SegmentedButton<int>), findsOneWidget);
    expect(find.text('Assemblé'), findsOneWidget);
    expect(find.text('Écarté'), findsOneWidget);
    expect(find.text('Pivot'), findsOneWidget);
    expect(find.text('Sortie'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Atelier 3D : sortie manuelle et remise à zéro', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    final nav = find.text('Voir les maillages V11.8');
    await tester.ensureVisible(nav);
    await tester.pumpAndSettle();
    await tester.tap(nav);
    await tester.pumpAndSettle();

    final exitTab = find.text('Sortie');
    await tester.ensureVisible(exitTab);
    await tester.tap(exitTab);
    await tester.pump();
    final seek = find.byKey(const Key('exit-sequence-progress'));
    expect(seek, findsOneWidget);
    await tester.ensureVisible(seek);
    tester.widget<Slider>(seek).onChanged!(.55);
    await tester.pump();
    expect(find.textContaining('Attaché ·'), findsOneWidget);
    tester.widget<Slider>(seek).onChanged!(.75);
    await tester.pump();
    expect(find.textContaining('Libéré ·'), findsOneWidget);
    await tester.ensureVisible(find.text('Rejouer'));
    await tester.tap(find.text('Rejouer'));
    await tester.pump();
    expect(tester.widget<Slider>(seek).value, 0);
    expect(tester.takeException(), isNull);
  });
}
