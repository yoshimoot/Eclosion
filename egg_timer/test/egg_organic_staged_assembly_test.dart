import 'package:egg_timer/lab/egg_organic_staged_assembly.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V11.36: one graph instance owns solids, bonds and hinge anchors',
      () {
    final staged = EggOrganicStagedAssembly.fixed();
    expect(staged.meshes.parents.length, 2);
    expect(staged.meshes.children.length, 3);
    expect(staged.hinges.length, 3);
    expect(identical(staged.meshes.partition, staged.attachments.partition),
        isTrue);
    final graph = staged.meshes.partition.organic.draft;

    for (var i = 0; i < staged.hinges.length; i++) {
      final mesh = staged.meshes.children[i];
      final hinge = staged.hinges[i];
      final attached = staged.attachments.children[i];
      expect(hinge.child, same(attached));
      expect(hinge.mesh, same(mesh));
      expect(hinge.hingeEdge, same(graph.edges[attached.hinge.edgeId]));
      expect(mesh.outer.any((p) => identical(p, hinge.anchorA)), isTrue);
      expect(mesh.outer.any((p) => identical(p, hinge.anchorB)), isTrue);
    }
  });

  test('V11.36: held poses are geometric data, never fake free flight',
      () {
    final staged = EggOrganicStagedAssembly.fixed();
    for (var i = 0; i < staged.hinges.length; i++) {
      final hinge = staged.hinges[i];
      final mesh = staged.meshes.children[i];
      final child = staged.attachments.children[i];
      final before = staged.heldPoseAt(i, 0)!;
      expect(before.state.intactCount, 4);
      expect(before.outer.length, mesh.outer.length);
      expect(before.inner.length, mesh.inner.length);
      for (var j = 0; j < mesh.outer.length; j += 31) {
        expect((before.outer[j] - mesh.outer[j]).length, lessThan(1e-8));
      }
      final middle = (hinge.openingStartProgress +
          hinge.releaseProgress) / 2;
      final bent = staged.heldPoseAt(i, middle)!;
      expect(bent.state.intactCount, 1);
      expect(bent.state.hingeIntact, isTrue);
      for (var j = 0; j < mesh.outer.length; j += 31) {
        final distance = (bent.outer[j] - bent.inner[j]).length;
        expect(distance, closeTo(2.5, 1e-8));
      }
      // At the material break the last attached pose still exists as
      // the exact initial condition for the FUTURE free-flight solver,
      // but it is never misrepresented as an attached fragment.
      final lastPoint = hinge.releasePositionOf(mesh.outer[0]);
      expect(lastPoint.x.isFinite && lastPoint.y.isFinite &&
          lastPoint.z.isFinite, isTrue);
      expect(staged.heldPoseAt(i, hinge.releaseProgress), isNull);
      expect(staged.heldPoseAt(i, 1.0), isNull);
      expect(child.stateAt(1).fullyReleased, isTrue);
      // Frame-order independence is important for scrub/pause/reset.
      expect(staged.heldPoseAt(i, 0)!.state.intactCount, 4);
      expect(staged.heldPoseAt(i, middle)!.state.intactCount, 1);
      expect(staged.heldPoseAt(i, 0)!.state.intactCount, 4);
    }
    expect(() => staged.heldPoseAt(-1, 0), throwsRangeError);
    expect(() => staged.heldPoseAt(3, .5), throwsRangeError);
  });
}
