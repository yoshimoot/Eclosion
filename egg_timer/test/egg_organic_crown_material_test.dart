import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_organic_crown_material.dart';
import 'package:egg_timer/lab/egg_organic_partitioned_meshes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V11.50: F1 crown edges belong to cap and exactly one neighbor', () {
    final body = EggOrganicPartitionedStaticMeshes.build();
    final cap = EggOrganicCrownMaterial.build(partition: body.partition);
    expect(cap.edgeOwners.length, 24);
    final graph = body.partition.organic.draft;
    for (var id = 0; id < 24; id++) {
      final owner = cap.edgeOwners[id]!;
      expect(owner.length, 2, reason: 'F1 seam edge $id');
      expect(owner.contains('crown-cap'), isTrue);
      final neighbor = owner.singleWhere((v) => v != 'crown-cap');
      expect(neighbor, anyOf(
        'left', 'right', 'remaining-front-bowl', 'remaining-rear-bowl',
      ));
      expect(graph.edges[id].kind, EggCrackKind.crown);
    }
    expect(cap.edgeOwners.values.where(
      (s) => s.contains('remaining-rear-bowl'),
    ).length, 12);
    expect(cap.edgeOwners.values.where(
      (s) => s.contains('left') || s.contains('right') ||
          s.contains('remaining-front-bowl'),
    ).length, 12);
    // The old graph/motion still owns its exact historical panels.
    expect(body.parents.length, 2);
    expect(body.children.length, 3);
    expect(graph.edges.length, 55);
  });

  test('V11.50: a true two-sided F1 solid reuses exact crown samples', () {
    final cap = EggOrganicCrownMaterial.build();
    final graph = cap.partition.organic.draft;
    var index = 0;
    for (var edge = 0; edge < 24; edge++) {
      final samples = graph.edges[edge].samples;
      for (var j = 0; j + 1 < samples.length; j++) {
        expect((cap.crownRim[index + j] - samples[j]).length,
            lessThan(1e-7),
            reason: 'F1 crown sample moved at $edge:$j');
        if (j > 0 || edge == 0) {
          expect(identical(cap.crownRim[index + j], samples[j]), isTrue);
        }
      }
      index += samples.length - 1;
    }
    expect(index, cap.rimCount);
    expect(cap.outer.length, cap.inner.length);
    expect(cap.thickness, 2.5);
    expect(cap.cutWalls.length, 2 * cap.rimCount);
    expect(cap.outerFaces.length, cap.innerFaces.length);
    expect(cap.outerFaces.length,
        (2 * (cap.ringCount - 1) + 1) * cap.rimCount);
    for (var i = 0; i < cap.outer.length; i++) {
      expect((cap.outer[i] - cap.inner[i]).length,
          closeTo(cap.thickness, 1e-7));
    }
    final maxIndex = cap.outer.length * 2 - 1;
    for (final group in [
      cap.outerFaces, cap.innerFaces, cap.cutWalls,
    ]) {
      for (final face in group) {
        if (face.a < 0 || face.b < 0 || face.c < 0 ||
            face.a > maxIndex || face.b > maxIndex || face.c > maxIndex ||
            face.a == face.b || face.b == face.c || face.a == face.c) {
          fail('Invalid F1 rigid material triangle');
        }
      }
    }
    final pole = cap.outer.last;
    expect(pole.x.abs() + pole.z.abs(), lessThan(1e-10));
    expect(pole.y, -graph.model.halfHeight);
    expect(() => EggOrganicCrownMaterial.build(ringCount: 1),
        throwsArgumentError);
    expect(() => EggOrganicCrownMaterial.build(thickness: 0),
        throwsArgumentError);
  });
}
