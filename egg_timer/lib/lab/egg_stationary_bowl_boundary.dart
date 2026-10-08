import 'dart:math' as math;

import 'egg_fragment_regions.dart';
import 'egg_fracture_network.dart';
import 'egg_shell_model.dart';

/// Boundary of the stationary FRONT bowl after reserving the two V11.2
/// panels. This is a geometry contract for future retessellation, not a
/// render-time clipping mask and not yet a cut bowl mesh.
///
/// Front silhouette endpoints are on the ORIGINAL EggShellModel F1 crown.
/// The gap between them is replaced with the actual graph edges bordering
/// the union of both candidate panels, excluding their shared inner edges.
class EggStationaryBowlBoundary {
  EggStationaryBowlBoundary._({
    required this.plan,
    required this.leftCrownNode,
    required this.rightCrownNode,
    required this.cutEdges,
    required this.remainingCrownEdges,
    required this.frontUpperBoundary,
  });

  factory EggStationaryBowlBoundary.fromRegions(
    EggFragmentRegionPlan plan,
  ) {
    final network = plan.network;
    const crownSize = 24;
    if (plan.regions.length != 2 || network.nodes.length < crownSize) {
      throw StateError('Two mapped V10.4 regions are required');
    }

    // A shared edge internal to the two panels is NOT a border of the
    // remaining bowl. Side branches are also not material cut boundaries.
    final owners = <int, int>{};
    for (final region in plan.regions) {
      for (final section in region.boundary) {
        owners.update(section.edgeId, (count) => count + 1,
            ifAbsent: () => 1);
      }
    }
    if (owners.values.any((count) => count < 1 || count > 2)) {
      throw StateError('Invalid candidate-region edge ownership');
    }
    final cutIds = <int>{};
    for (final entry in owners.entries) {
      final edge = network.edges[entry.key];
      if (entry.value != 1 || edge.kind == EggCrackKind.crown) {
        continue;
      }
      if (edge.kind != EggCrackKind.primary &&
          edge.kind != EggCrackKind.connection) {
        throw StateError('A dead-end branch cannot border the bowl cut');
      }
      cutIds.add(entry.key);
    }

    final incident = <int, List<int>>{};
    for (final id in cutIds) {
      final edge = network.edges[id];
      incident.putIfAbsent(edge.startNode, () => <int>[]).add(id);
      incident.putIfAbsent(edge.endNode, () => <int>[]).add(id);
    }
    if (incident.values.any((neighbors) => neighbors.length > 2)) {
      throw StateError('Bowl cut contains a branching or crossing junction');
    }
    final tips = incident.entries
        .where((entry) => entry.value.length == 1)
        .map((entry) => entry.key)
        .toList();
    if (tips.length != 2) {
      throw StateError('Bowl cut must be one unbranched open path');
    }
    tips.sort((a, b) => network.nodes[a].angle
        .compareTo(network.nodes[b].angle));
    final left = tips[0], right = tips[1];
    // The front arc of this 24-segment crown starts at -pi/2 (node 6)
    // and ends at pi/2 (node 18). Do NOT use the rear 12 crown segments.
    const leftFront = 6, rightFront = 18;
    if (left <= leftFront || right >= rightFront || left >= right ||
        left >= crownSize || right >= crownSize) {
      throw StateError('The cut must meet distinct front F1 crown nodes');
    }
    for (final id in tips) {
      final node = network.nodes[id];
      if ((node.y -
          network.model.crownFractureY(node.angle)).abs() > 1e-8) {
        throw StateError('A bowl-cut endpoint is not on the F1 crown');
      }
    }

    final path = <EggRegionBoundaryEdge>[];
    final used = <int>{};
    var current = left;
    while (current != right) {
      final available = incident[current]!.where(
        (id) => !used.contains(id),
      ).toList();
      if (available.length != 1) {
        throw StateError('Disconnected or ambiguous bowl-cut boundary');
      }
      final id = available.single;
      used.add(id);
      final edge = network.edges[id];
      final forward = edge.startNode == current;
      path.add(EggRegionBoundaryEdge(edgeId: id, forward: forward));
      current = forward ? edge.endNode : edge.startNode;
      if (path.length > cutIds.length) {
        throw StateError('Cyclic cut boundary');
      }
    }
    if (used.length != cutIds.length) {
      throw StateError('An unused cut-edge component remains');
    }

    final keptCrown = <EggRegionBoundaryEdge>[
      for (var id = leftFront; id < left; id++)
        EggRegionBoundaryEdge(edgeId: id, forward: true),
      for (var id = right; id < rightFront; id++)
        EggRegionBoundaryEdge(edgeId: id, forward: true),
    ];
    final top = <EggRegionBoundaryEdge>[
      for (var id = leftFront; id < left; id++)
        EggRegionBoundaryEdge(edgeId: id, forward: true),
      ...path,
      for (var id = right; id < rightFront; id++)
        EggRegionBoundaryEdge(edgeId: id, forward: true),
    ];

    if (top.first.startNode(network) != leftFront ||
        top.last.endNode(network) != rightFront) {
      throw StateError('Front shell top must join the F1 silhouette');
    }
    for (var i = 0; i + 1 < top.length; i++) {
      if (top[i].endNode(network) != top[i + 1].startNode(network)) {
        throw StateError('The remaining upper rim has a broken join');
      }
    }
    return EggStationaryBowlBoundary._(
      plan: plan,
      leftCrownNode: left,
      rightCrownNode: right,
      cutEdges: List<EggRegionBoundaryEdge>.unmodifiable(path),
      remainingCrownEdges:
          List<EggRegionBoundaryEdge>.unmodifiable(keptCrown),
      frontUpperBoundary:
          List<EggRegionBoundaryEdge>.unmodifiable(top),
    );
  }

  final EggFragmentRegionPlan plan;
  final int leftCrownNode;
  final int rightCrownNode;
  final List<EggRegionBoundaryEdge> cutEdges;
  final List<EggRegionBoundaryEdge> remainingCrownEdges;
  final List<EggRegionBoundaryEdge> frontUpperBoundary;

  /// Reuses ORIGINAL 3D crack samples and closes via the real front
  /// silhouette surface (not a painted/faked cut). The resulting simple
  /// perimeter is intended for a future constrained bowl triangulation.
  List<EggShellPoint3> sampledFrontPerimeter({
    int sideSegments = 64,
  }) {
    if (sideSegments < 2) {
      throw ArgumentError.value(sideSegments, 'sideSegments');
    }
    final network = plan.network;
    final model = network.model;
    final samples = <EggShellPoint3>[];
    for (final segment in frontUpperBoundary) {
      final edgeSamples = segment.samples(network);
      samples.addAll(samples.isEmpty ? edgeSamples : edgeSamples.skip(1));
    }

    final leftY = network.nodes[6].y;
    final rightY = network.nodes[18].y;
    for (var i = 1; i <= sideSegments; i++) {
      final t = i / sideSegments;
      samples.add(model.pointAt(
        rightY + (model.halfHeight - rightY) * t,
        math.pi / 2,
      ));
    }
    for (var i = 1; i < sideSegments; i++) {
      final t = i / sideSegments;
      samples.add(model.pointAt(
        model.halfHeight + (leftY - model.halfHeight) * t,
        -math.pi / 2,
      ));
    }
    samples.add(samples.first);
    return List<EggShellPoint3>.unmodifiable(samples);
  }
}
