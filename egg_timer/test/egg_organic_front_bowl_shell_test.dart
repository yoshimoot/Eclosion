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
    // These getters materialize immutable copies. Never call them inside
    // the per-triangle loop: doing so is O(vertices * triangles) and stalled
    // the original V11.44 Windows test even though the geometry was sound.
    final combinedVertices = shell.combinedVertices;
    final combinedFaces = shell.combinedFaces;
    expect(combinedVertices.length, shell.exterior.length * 2);
    expect(combinedFaces.length,
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

    final maxVertexIndex = combinedVertices.length - 1;
    // Scan every triangle. Fail with its index on the first corrupted face,
    // rather than allocating 4 Matcher objects and 3 vertex-list copies
    // for EACH of the many refined triangles.
    for (var i = 0; i < combinedFaces.length; i++) {
      final face = combinedFaces[i];
      if (face.a < 0 || face.a > maxVertexIndex ||
          face.b < 0 || face.b > maxVertexIndex ||
          face.c < 0 || face.c > maxVertexIndex ||
          face.a == face.b || face.b == face.c || face.c == face.a) {
        fail('Invalid organic 3D triangle #$i: '
            '(${face.a}, ${face.b}, ${face.c}), '
            'valid vertex range 0..$maxVertexIndex');
      }
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
