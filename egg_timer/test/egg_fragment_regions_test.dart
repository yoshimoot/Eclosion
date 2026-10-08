import 'package:flutter_test/flutter_test.dart';
import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';

void main() {
  test('V11.1: two closed candidate panels use real V10.4 graph edges', () {
    final network = EggFractureNetwork.fixed();
    final plan = EggFragmentRegionPlan.fromNetwork(network);

    expect(plan.regions.map((r) => r.id), ['left', 'right']);
    expect(plan.network, same(network));
    expect(plan.regions.length, 2);

    final left = plan.regions[0];
    final right = plan.regions[1];
    expect([left.crownRootA, left.crownRootB], [7, 11]);
    expect([right.crownRootA, right.crownRootB], [16, 11]);
    expect(left.boundary.length, 14);
    expect(right.boundary.length, 16);

    for (final region in plan.regions) {
      final seen = <int>{};
      for (var i = 0; i < region.boundary.length; i++) {
        final current = region.boundary[i];
        final next = region.boundary[(i + 1) % region.boundary.length];
        expect(seen.add(current.edgeId), isTrue);
        expect(current.endNode(network), next.startNode(network),
            reason: 'The physical graph loop must close at shared node IDs');
        expect(
          network.edges[current.edgeId].kind != EggCrackKind.secondary,
          isTrue,
          reason: 'Dead-end cracks do not create detachable boundaries',
        );
      }
    }
  });

  test('V11.1: three shared central material edges have opposite winding', () {
    final network = EggFractureNetwork.fixed();
    final plan = EggFragmentRegionPlan.fromNetwork(network);
    final left = plan.regions[0], right = plan.regions[1];

    expect(left.sharedEdgeIds(right).toSet(), {28, 29, 30});
    expect(right.sharedEdgeIds(left).toSet(), {28, 29, 30});
    for (final id in left.sharedEdgeIds(right)) {
      final l = left.boundary.singleWhere((s) => s.edgeId == id);
      final r = right.boundary.singleWhere((s) => s.edgeId == id);
      expect(l.forward, isNot(r.forward));
      expect(network.edges[id].kind, EggCrackKind.primary);
    }

    expect(left.boundary.where(
      (s) => network.edges[s.edgeId].kind == EggCrackKind.crown,
    ).length, 4);
    expect(right.boundary.where(
      (s) => network.edges[s.edgeId].kind == EggCrackKind.crown,
    ).length, 5);
  });

  test('V11.1: boundaries reuse 3D samples, never fabricate a 2D contour', () {
    final network = EggFractureNetwork.fixed();
    final plan = EggFragmentRegionPlan.fromNetwork(network);
    final original = <int, List<Object>>{
      for (final edge in network.edges)
        edge.id: List<Object>.of(edge.samples),
    };

    for (final region in plan.regions) {
      for (final step in region.boundary) {
        final source = network.edges[step.edgeId].samples;
        final oriented = step.samples(network);
        expect(oriented.length, source.length);
        expect(identical(oriented.first,
            step.forward ? source.first : source.last), isTrue);
        expect(identical(oriented.last,
            step.forward ? source.last : source.first), isTrue);
      }
      final perimeter = region.sampledPerimeter(network);
      expect(perimeter.length, greaterThan(50));
      // Each point is from a sampled edge; no independent coordinates.
      final allPoints = <Object>{
        for (final edge in network.edges) ...edge.samples,
      };
      expect(perimeter.every(allPoints.contains), isTrue);
    }

    for (final edge in network.edges) {
      expect(edge.samples.length, original[edge.id]!.length);
      for (var i = 0; i < edge.samples.length; i++) {
        expect(identical(edge.samples[i], original[edge.id]![i]), isTrue);
      }
    }
  });

  test('V11.1: side cracks and cap scratches are not candidate fragments', () {
    final network = EggFractureNetwork.fixed();
    final plan = EggFragmentRegionPlan.fromNetwork(network);
    final boundaries = {
      for (final region in plan.regions)
        for (final segment in region.boundary) segment.edgeId,
    };

    expect(network.edges.length, 52);
    expect(network.nodes.length, 50);
    expect(network.edges.length - network.nodes.length + 1, 3);
    for (final edge in network.edges.where(
      (e) => e.kind == EggCrackKind.secondary,
    )) {
      expect(boundaries.contains(edge.id), isFalse);
    }
    expect(network.edges.where(
      (e) => e.kind == EggCrackKind.crown,
    ).length, 24);
    expect(plan.regions.length, 2,
        reason: 'Unbounded lower bowl is not a detachable mesh yet');
  });

  test('V11.1: fixed-seed region topology is reproducible', () {
    final a = EggFragmentRegionPlan.fromNetwork(EggFractureNetwork.fixed());
    final b = EggFragmentRegionPlan.fromNetwork(EggFractureNetwork.fixed());
    expect(a.network.seed, EggFractureNetwork.fixedSeed);
    for (var i = 0; i < a.regions.length; i++) {
      expect(a.regions[i].id, b.regions[i].id);
      expect(a.regions[i].crownRootA, b.regions[i].crownRootA);
      expect(a.regions[i].crownRootB, b.regions[i].crownRootB);
      expect(
        a.regions[i].boundary.map(
          (step) => (step.edgeId, step.forward),
        ).toList(),
        b.regions[i].boundary.map(
          (step) => (step.edgeId, step.forward),
        ).toList(),
      );
    }
  });
}
