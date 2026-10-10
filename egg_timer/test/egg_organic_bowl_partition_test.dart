import 'dart:math' as math;

import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_organic_bowl_partition.dart';
import 'package:egg_timer/lab/egg_organic_partitioned_meshes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V11.34: every organic cut is owned by exactly two solids', () {
    final plan = EggOrganicBowlPartition.fixed();
    expect(plan.organic.candidates.length, 3);
    expect(plan.originalRegions.regions.length, 2);
    expect(plan.edgeOwners, isNotEmpty);
    for (final owners in plan.edgeOwners.values) {
      expect(owners.length, 2);
    }
    final originalCuts = plan.originalBowl.cutEdges
        .map((edge) => edge.edgeId).toSet();
    final updatedCuts = plan.cutEdges.map((edge) => edge.edgeId).toSet();

    // One preexisting panel/bowl edge per child becomes panel/child.
    // Three newly bounded edges per child become child/bowl.
    final detached = <int>{};
    for (final child in plan.organic.candidates) {
      final inherited = child.boundary
          .where((step) => originalCuts.contains(step.edgeId))
          .toList();
      expect(inherited.length, 1);
      final parentShared = inherited.single.edgeId;
      expect(detached.add(parentShared), isTrue);
      final owners = plan.edgeOwners[parentShared]!;
      expect(owners, contains(child.id));
      expect(owners, contains(anyOf('left', 'right')));
      expect(owners.contains('remaining-front-bowl'), isFalse);

      for (final step in child.boundary) {
        if (step.edgeId == parentShared) continue;
        expect(originalCuts.contains(step.edgeId), isFalse);
        expect(updatedCuts.contains(step.edgeId), isTrue);
        expect(plan.edgeOwners[step.edgeId],
            {child.id, 'remaining-front-bowl'});
      }
    }
    expect(detached.length, 3);
    expect(updatedCuts.length, originalCuts.length - 3 + 9);
    for (final edge in originalCuts.difference(detached)) {
      expect(updatedCuts, contains(edge));
    }
    for (final edge in originalCuts.intersection(detached)) {
      expect(updatedCuts.contains(edge), isFalse);
    }
  });

  test('V11.34: no duplicate cuts or discontinued original F1 crown', () {
    final partition = EggOrganicBowlPartition.fixed();
    final original = partition.originalBowl.frontUpperBoundary;
    final cut = partition.frontUpperBoundary;
    final graph = partition.organic.draft;
    expect(cut.first.edgeId, original.first.edgeId);
    expect(cut.last.edgeId, original.last.edgeId);
    expect(cut.first.startNode(graph), 6);
    expect(cut.last.endNode(graph), 18);
    for (var i = 0; i + 1 < cut.length; i++) {
      expect(cut[i].endNode(graph), cut[i + 1].startNode(graph));
    }
    final unique = cut.map((step) => step.edgeId).toSet();
    expect(unique.length, cut.length);
    for (final edge in graph.edges) {
      if (edge.kind == EggCrackKind.crown && edge.id <= 23) {
        expect(
          partition.organic.draft.edges[edge.id].samples.length,
          partition.organic.original.edges[edge.id].samples.length,
        );
      }
    }
  });

  test('V11.34: projected material area is conserved by bowl partition', () {
    final plan = EggOrganicBowlPartition.fixed();
    final original = plan.originalBowl.sampledFrontPerimeter();
    final revised = plan.sampledFrontPerimeter();
    final baseArea = EggOrganicPartitionedStaticMeshes.projectedArea(
        original);
    final newBowlArea = EggOrganicPartitionedStaticMeshes.projectedArea(
        revised);
    final fragments = [
      for (final child in plan.organic.candidates)
        EggOrganicPartitionedStaticMeshes.projectedArea(
          child.sampledPerimeter(plan.organic.draft),
        ),
    ];
    expect(baseArea, greaterThan(0));
    expect(newBowlArea, greaterThan(0));
    expect(fragments.every((area) => area > 0), isTrue);
    expect(newBowlArea, lessThan(baseArea));
    final sumArea = newBowlArea + fragments.reduce((a, b) => a + b);
    expect(sumArea, closeTo(baseArea, 1e-4),
        reason: 'The static mesh partition must neither duplicate '
            'nor destroy projected front-shell material');
  });

  test('V11.34: all five solids share one curved shell meshing rule', () {
    final source = EggOrganicPartitionedStaticMeshes.build();
    final partition = source.partition;
    expect(source.parents.length, 2);
    expect(source.children.length, 3);
    expect(source.refinementPasses, inInclusiveRange(0, 5));
    final originals = partition.originalRegions.regions;
    for (var i = 0; i < source.parents.length; i++) {
      expect(source.parents[i].regionId, originals[i].id);
      expect(source.parents[i].thickness, 2.5);
      expect(source.parents[i].sideTriangles.length,
          source.parents[i].rim.length * 2);
    }
    for (var i = 0; i < source.children.length; i++) {
      final mesh = source.children[i];
      expect(mesh.regionId, partition.organic.candidates[i].id);
      expect(mesh.thickness, 2.5);
      expect(mesh.inner.length, mesh.outer.length);
      expect(mesh.sideTriangles.length, mesh.rim.length * 2);
      expect(mesh.outerTriangles, isNotEmpty);
      for (var k = 0; k < mesh.outer.length; k += 17) {
        final outer = mesh.outer[k], inner = mesh.inner[k];
        expect((outer - inner).length, closeTo(2.5, 1e-7));
      }
    }
    expect(source.bowl.vertices, isNotEmpty);
    expect(source.bowl.triangles, isNotEmpty);
    // All rim subdivisions follow 2^commonPasses original segments.
    final factor = math.pow(2, source.refinementPasses).toInt();
    for (var i = 0; i < source.children.length; i++) {
      final originalLength = partition.organic.candidates[i]
          .sampledPerimeter(partition.organic.draft).length - 1;
      expect(source.children[i].rim.length, originalLength * factor);
    }
    final revisedPerimeter = partition.sampledFrontPerimeter();
    expect(source.bowl.rim.length,
        (revisedPerimeter.length - 1) * factor);
  });
}
