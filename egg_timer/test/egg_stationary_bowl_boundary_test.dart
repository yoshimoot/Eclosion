import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_stationary_bowl_boundary.dart';

void main() {
  final network = EggFractureNetwork.fixed();
  final panels = EggFragmentRegionPlan.fromNetwork(network);
  final bowl = EggStationaryBowlBoundary.fromRegions(panels);

  test('V11.3: union of candidate panels leaves one real open cut', () {
    expect(bowl.leftCrownNode, 7);
    expect(bowl.rightCrownNode, 16);
    expect(bowl.cutEdges.length, 15);
    expect(bowl.cutEdges.first.startNode(network), 7);
    expect(bowl.cutEdges.last.endNode(network), 16);
    expect(
      bowl.cutEdges.map((s) => s.edgeId).toSet(),
      {24, 25, 26, 27, 31, 32, 33, 34, 35,
       36, 37, 38, 39, 40, 41},
    );
    for (var i = 0; i + 1 < bowl.cutEdges.length; i++) {
      expect(bowl.cutEdges[i].endNode(network),
          bowl.cutEdges[i + 1].startNode(network));
    }
    expect(bowl.cutEdges.map((s) => s.edgeId).toSet().length, 15);
  });

  test('V11.3: interior shared edges do not carve a false third hole', () {
    final cutIds = bowl.cutEdges.map((s) => s.edgeId).toSet();
    expect(cutIds.intersection({28, 29, 30}), isEmpty);
    expect(cutIds.contains(31), isTrue);
    final owners = <int, int>{};
    for (final region in panels.regions) {
      for (final step in region.boundary) {
        owners.update(step.edgeId, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    for (final id in cutIds) {
      expect(owners[id], 1,
          reason: 'Only one-panel ownership belongs to the remaining rim');
      expect(network.edges[id].kind == EggCrackKind.secondary, isFalse);
    }
    for (final id in <int>[28, 29, 30]) {
      expect(owners[id], 2);
    }
  });

  test('V11.3: fixed-body rim retains only the untouched front F1 arcs', () {
    expect(bowl.remainingCrownEdges.map((s) => s.edgeId), [6, 16, 17]);
    final top = bowl.frontUpperBoundary;
    expect(top.length, 18);
    expect(top.first.startNode(network), 6);
    expect(top.last.endNode(network), 18);
    for (var i = 0; i + 1 < top.length; i++) {
      expect(top[i].endNode(network), top[i + 1].startNode(network));
    }
    expect(top.where((s) =>
        network.edges[s.edgeId].kind == EggCrackKind.crown).length, 3);
    expect(top.where((s) =>
        network.edges[s.edgeId].kind == EggCrackKind.secondary), isEmpty);
  });

  test('V11.3: cut exactly reuses the shell graph sampled positions', () {
    final perimeter = bowl.sampledFrontPerimeter();
    expect(identical(perimeter.first, perimeter.last), isTrue);
    expect(perimeter.length, greaterThan(200));
    final cutSamples = <Object>{
      for (final s in bowl.cutEdges) ...s.samples(network),
    };
    for (final step in bowl.cutEdges) {
      final oriented = step.samples(network);
      final edge = network.edges[step.edgeId];
      expect(identical(oriented.first,
        step.forward ? edge.samples.first : edge.samples.last), isTrue);
      expect(identical(oriented.last,
        step.forward ? edge.samples.last : edge.samples.first), isTrue);
      expect(oriented.every(cutSamples.contains), isTrue);
    }
    for (final p in perimeter) {
      final sample = network.model.surfaceAt(p.x, p.y);
      expect(p.x, closeTo(sample.x, 1e-7));
      expect(p.y, closeTo(sample.y, 1e-7));
      expect(p.z, closeTo(sample.z, 1e-6));
    }
    expect(perimeter.any((p) =>
        (p.y - network.model.halfHeight).abs() < 1e-8), isTrue);
    expect(perimeter.any((p) => p.z.abs() < 1e-8), isTrue);
  });

  test('V11.3: no point reuse ambiguity and deterministic outer contour', () {
    final other = EggStationaryBowlBoundary.fromRegions(
      EggFragmentRegionPlan.fromNetwork(EggFractureNetwork.fixed()),
    );
    expect(
      bowl.cutEdges.map((s) => (s.edgeId, s.forward)).toList(),
      other.cutEdges.map((s) => (s.edgeId, s.forward)).toList(),
    );
    final front = bowl.sampledFrontPerimeter(sideSegments: 12);
    final clone = bowl.sampledFrontPerimeter(sideSegments: 12);
    expect(front.length, clone.length);
    for (var i = 0; i < front.length; i++) {
      expect(front[i].x, closeTo(clone[i].x, 1e-8));
      expect(front[i].y, closeTo(clone[i].y, 1e-8));
      expect(front[i].z, closeTo(clone[i].z, 1e-8));
    }
    expect(() => bowl.sampledFrontPerimeter(sideSegments: 1),
      throwsArgumentError);
    expect(network.edges.length, 52);
    expect(network.nodes.length, 50);
    expect(math.pi.isFinite, isTrue);
  });
}
