import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_organic_lower_cradle_material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V11.50: low cradle cut extends the unchanged organic graph', () {
    final original = EggFractureNetwork.organicStaticDraft();
    final extended = EggFractureNetwork.lowerCradleStaticDraft();
    expect(extended.seed, original.seed);
    expect(extended.nodes.length, original.nodes.length + 24);
    expect(extended.edges.length, original.edges.length + 24);
    // Both graph factories are deterministic but each creates its own
    // immutable value objects. Compare the ACTUAL material coordinates,
    // not object identity across two separate factory invocations.
    for (var i = 0; i < original.edges.length; i++) {
      final before = original.edges[i], after = extended.edges[i];
      expect(after.kind, before.kind);
      expect(after.startNode, before.startNode);
      expect(after.endNode, before.endNode);
      expect(after.samples.length, before.samples.length);
      for (var j = 0; j < before.samples.length; j++) {
        expect((before.samples[j] - after.samples[j]).length,
            lessThan(1e-10),
            reason: 'F1/V10.4 material moved on edge $i sample $j');
      }
    }
    var maximumOldY = double.negativeInfinity;
    for (final edge in original.edges) {
      for (final point in edge.samples) {
        if (point.y > maximumOldY) maximumOldY = point.y;
      }
    }
    expect(maximumOldY, lessThan(84));
    for (var i = 0; i < 24; i++) {
      final edge = extended.edges[original.edges.length + i];
      final next = extended.edges[original.edges.length + (i + 1) % 24];
      expect(edge.endNode, next.startNode);
      expect(edge.samples.length, 17);
      expect((edge.samples.last - next.samples.first).length,
          lessThan(1e-7));
      for (final point in edge.samples) {
        expect(point.y, inInclusiveRange(84, 100));
        final radius = extended.model.radiusAt(point.y);
        final depth = extended.model.depthRadiusAt(point.y);
        final equation = (point.x / radius) * (point.x / radius) +
            (point.z / depth) * (point.z / depth);
        expect(equation, closeTo(1, 1e-9));
      }
    }
  });

  test('V11.50: bottom bowl is a real 3D solid, not a crop mask', () {
    final shell = EggOrganicLowerCradleMaterial.build();
    expect(shell.cutEdgeIds.length, 24);
    expect(shell.rimCount, 24 * 16);
    expect(shell.retainedHeightFraction, inInclusiveRange(.27, .32));
    expect(shell.outer.length, shell.inner.length);
    expect(shell.outerFaces.length, shell.innerFaces.length);
    expect(shell.cutWalls.length, shell.rimCount * 2);
    expect(shell.outerFaces.length,
        shell.rimCount * (2 * (shell.ringCount - 1) + 1));
    expect(shell.outer.last.y, shell.draft.model.halfHeight);
    expect(shell.outer.last.x.abs() + shell.outer.last.z.abs(),
        lessThan(1e-10));
    for (var i = 0; i < shell.outer.length; i++) {
      expect((shell.outer[i] - shell.inner[i]).length,
          closeTo(2.5, 1e-7));
    }
    final maxIndex = shell.outer.length * 2 - 1;
    for (final faces in [
      shell.outerFaces, shell.innerFaces, shell.cutWalls,
    ]) {
      for (final t in faces) {
        if (t.a < 0 || t.b < 0 || t.c < 0 ||
            t.a > maxIndex || t.b > maxIndex || t.c > maxIndex ||
            t.a == t.b || t.b == t.c || t.a == t.c) {
          fail('Invalid lower-cradle rigid shell face');
        }
      }
    }
    expect(() => EggOrganicLowerCradleMaterial.build(
      ringCount: 1,
    ), throwsArgumentError);
    expect(() => EggOrganicLowerCradleMaterial.build(
      thickness: 0,
    ), throwsArgumentError);
  });
}
