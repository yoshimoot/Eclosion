import 'package:egg_timer/lab/egg_organic_full_shell_draft.dart';
import 'package:egg_timer/lab/egg_organic_upper_front_band.dart';
import 'package:egg_timer/lab/egg_organic_upper_rear_band.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V11.51: upper rear reuses BOTH true front side seams', () {
    final graph = EggOrganicFullShellDraft.fixed();
    final front = EggOrganicUpperFrontBand.build(draft: graph);
    final rear = EggOrganicUpperRearBand.build(
      draft: graph, front: front,
    );
    final n = rear.rowLength;
    expect(rear.bandCount, front.rightSeam.length - 1);
    expect(n, 12 * 16 + 1);
    expect(rear.outer.length, n * (rear.bandCount + 1));
    expect(rear.outerFaces.length, 2 * (n - 1) * rear.bandCount);
    expect(rear.innerFaces.length, rear.outerFaces.length);
    expect(rear.cutWalls.length, 4 * (n - 1));
    for (var row = 0; row <= rear.bandCount; row++) {
      expect(rear.outer[row * n], same(front.rightSeam[row]));
      expect(rear.outer[row * n + n - 1],
          same(front.leftSeam[rear.bandCount - row]));
    }
    expect(rear.outer.first, same(front.topPerimeter.last));
    expect(rear.outer[n - 1], same(front.topPerimeter.first));
    expect(rear.outer[rear.bandCount * n],
        same(front.lowerFrontArc.last));
    expect(rear.outer.last, same(front.lowerFrontArc.first));
  });

  test('V11.51: rear material keeps F1 and lower shared graph vertices',
      () {
    final source = EggOrganicFullShellDraft.fixed();
    final front = EggOrganicUpperFrontBand.build(draft: source);
    final rear = EggOrganicUpperRearBand.build(draft: source, front: front);
    final upper = <Object>[];
    final lower = <Object>[];
    for (final id in <int>[
      for (var i = 18; i < 24; i++) i,
      for (var i = 0; i < 6; i++) i,
    ]) {
      final top = source.network.edges[id].samples;
      final bottom = source.network.edges[
          source.cradle.cutEdgeIds[id]].samples;
      upper.addAll(upper.isEmpty ? top : top.skip(1));
      lower.addAll(lower.isEmpty ? bottom : bottom.skip(1));
    }
    for (var i = 1; i + 1 < rear.rowLength; i++) {
      expect(rear.outer[i], same(upper[i]));
      expect(rear.outer[rear.bandCount * rear.rowLength + i],
          same(lower[i]));
    }
    expect(rear.outer.length, rear.inner.length);
    final topIndex = rear.outer.length * 2 - 1;
    for (var i = 0; i < rear.outer.length; i++) {
      expect((rear.outer[i] - rear.inner[i]).length,
          closeTo(2.5, 1e-7));
    }
    for (final group in [
      rear.outerFaces, rear.innerFaces, rear.cutWalls,
    ]) {
      for (final t in group) {
        if (t.a < 0 || t.b < 0 || t.c < 0 ||
            t.a > topIndex || t.b > topIndex || t.c > topIndex ||
            t.a == t.b || t.b == t.c || t.a == t.c) {
          fail('Invalid 3D rear-band triangle');
        }
      }
    }
    // Not yet painted: upper band must be divided into moving side pieces
    // before the low bowl replaces the old full-height fixed shell.
    expect(source.lowerSideRegionsAssigned, isFalse);
  });
}
