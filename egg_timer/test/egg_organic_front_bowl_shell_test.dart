import 'package:egg_timer/lab/egg_organic_front_bowl_shell.dart';
import 'package:egg_timer/lab/egg_organic_partitioned_meshes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V11.44: organic front shell has real interior and cut thickness', () {
    final meshes = EggOrganicPartitionedStaticMeshes.build();
    final shell = EggOrganicFrontBowlShellBuilder.build(meshes);
    final graph = meshes.partition.organic.draft;

    expect(shell.thickness, 2.5);
    expect(shell.exterior, same(meshes.bowl.vertices));
    expect(shell.outerFaces, same(meshes.bowl.triangles));
    expect(shell.interior.length, shell.exterior.length);
    expect(shell.innerFaces.length, shell.outerFaces.length);
    expect(shell.upperCutWalls.length,
        2 * (shell.upperCutRim.length - 1));
    expect(shell.combinedVertices.length, shell.exterior.length * 2);
    expect(shell.combinedFaces.length,
        shell.outerFaces.length * 2 + shell.upperCutWalls.length);

    final rim = shell.upperCutRim;
    expect(rim, isNotEmpty);
    final left = graph.nodes[6].onShell(graph.model);
    final right = graph.nodes[18].onShell(graph.model);
    expect((shell.exterior[rim.first] - left).length, lessThan(1e-7));
    expect((shell.exterior[rim.last] - right).length, lessThan(1e-7));

    for (var i = 0; i < shell.exterior.length; i += 29) {
      final a = shell.exterior[i], b = shell.interior[i];
      expect((a - b).length, closeTo(shell.thickness, 1e-7));
    }

    for (final face in shell.combinedFaces) {
      expect(face.a, inInclusiveRange(0, shell.combinedVertices.length - 1));
      expect(face.b, inInclusiveRange(0, shell.combinedVertices.length - 1));
      expect(face.c, inInclusiveRange(0, shell.combinedVertices.length - 1));
      expect({face.a, face.b, face.c}.length, 3);
    }

    // The refined top is exactly the material split of all organic cuts;
    // the physical side silhouette is intentionally OPEN for the rear.
    var originalSegments = 0;
    for (final section in meshes.partition.frontUpperBoundary) {
      originalSegments += section.samples(graph).length - 1;
    }
    expect(rim.length,
        originalSegments * (1 << meshes.refinementPasses) + 1);
    expect(shell.upperCutWalls.length,
        originalSegments * (1 << meshes.refinementPasses) * 2);
    expect(() => EggOrganicFrontBowlShellBuilder.build(
      meshes, thickness: -1,
    ), throwsArgumentError);
  });

  test('V11.44: old parent panel material is unaffected by new cut wall', () {
    final meshes = EggOrganicPartitionedStaticMeshes.build();
    final shell = EggOrganicFrontBowlShellBuilder.build(meshes);
    for (final parent in meshes.parents) {
      expect(parent.thickness, shell.thickness);
      expect(parent.outerTriangles, isNotEmpty);
    }
    for (final child in meshes.children) {
      expect(child.thickness, shell.thickness);
      expect(child.innerTriangles, isNotEmpty);
      expect(child.sideTriangles, isNotEmpty);
    }
  });
}
