import 'package:egg_timer/lab/egg_geometry_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('V11.48: organic preview is opt-in and V11.32 stays intact',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: EggGeometryPreview(),
    ));
    expect(find.text('Géométrie V11.32'), findsOneWidget);
    expect(tester.takeException(), isNull);
    var selector = tester.widget<SegmentedButton<int>>(
        find.byType(SegmentedButton<int>));
    expect(selector.selected, {0});
    expect(selector.segments.map((s) => s.value), [0, 1, 2, 3, 4]);

    // Selecting the experimental mode requires explicit action. The
    // preserved historical V11.32 default does not build organic meshes.
    selector.onSelectionChanged!({4});
    await tester.pump();
    expect(find.text('Géométrie V11.48 · organique expérimental'),
        findsOneWidget);
    expect(find.textContaining('Petits fragments encore attachés :'),
        findsOneWidget);
    expect(tester.takeException(), isNull);

    // The same diagnostic can return to the unchanged historic exit mode.
    selector = tester.widget<SegmentedButton<int>>(
        find.byType(SegmentedButton<int>));
    selector.onSelectionChanged!({3});
    await tester.pump();
    expect(find.text('Géométrie V11.32'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
