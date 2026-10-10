import 'egg_fracture_network.dart';
import 'egg_fragment_regions.dart';
import 'egg_shell_model.dart';

/// V11.33 — an immutable *candidate* 3D piece bounded only by shared crack
/// edges. It has no triangle ownership, thickness, hinge or animation yet.
/// In particular it must NOT be drawn over the current two-panel shell.
class EggOrganicCandidateRegion {
  const EggOrganicCandidateRegion({
    required this.id,
    required this.boundary,
  });

  final String id;
  final List<EggRegionBoundaryEdge> boundary;

  /// Each oriented edge reuses the exact 3D samples in the source network.
  /// The last sample closes against the first without inventing a seam.
  List<EggShellPoint3> sampledPerimeter(EggFractureNetwork network) {
    if (boundary.length < 3) {
      throw StateError('Candidate material contour has too few edges');
    }
    final result = <EggShellPoint3>[];
    for (var i = 0; i < boundary.length; i++) {
      final current = boundary[i];
      final next = boundary[(i + 1) % boundary.length];
      if (current.endNode(network) != next.startNode(network)) {
        throw StateError('Organic candidate does not close at graph nodes');
      }
      final samples = current.samples(network);
      result.addAll(result.isEmpty ? samples : samples.skip(1));
    }
    if ((result.first - result.last).length > 1e-7) {
      throw StateError('Organic candidate has a disconnected material rim');
    }
    return List<EggShellPoint3>.unmodifiable(result);
  }
}

/// Read-only structural draft for THREE smaller closed regions.
/// The original V10.4 fracture topology remains unchanged in [original].
///
/// The candidate edge shared with its future neighbour is an actual
/// EggCrackEdge object, not an independently traced or animated 2D outline.
/// This plan deliberately does not replace EggFragmentRegionPlan or split its
/// current two meshes until complete material ownership is available.
class EggOrganicFracturePlan {
  const EggOrganicFracturePlan._(
    this.original, this.draft, this.candidates,
  );

  final EggFractureNetwork original;
  final EggFractureNetwork draft;
  final List<EggOrganicCandidateRegion> candidates;

  factory EggOrganicFracturePlan.fixed({
    EggShellModel model = EggShellModel.reference,
  }) {
    final original = EggFractureNetwork.fixed(model: model);
    final draft = EggFractureNetwork.organicStaticDraft(model: model);
    final addedEdges = draft.edges.skip(original.edges.length);
    const names = <String>['upper-left-small', 'lower-left-small', 'lower-right-small'];
    final candidates = <EggOrganicCandidateRegion>[];
    var index = 0;
    for (final closure in addedEdges) {
      final fromMotherToTip = _pathFrom(
        original, closure.endNode, closure.startNode,
      );
      if (fromMotherToTip.length != 3) {
        throw StateError('Expected a local three-edge parent crack path');
      }
      final boundary = List<EggRegionBoundaryEdge>.unmodifiable([
        EggRegionBoundaryEdge(edgeId: closure.id, forward: true),
        ...fromMotherToTip,
      ]);
      final candidate = EggOrganicCandidateRegion(
        id: names[index++], boundary: boundary,
      );
      candidate.sampledPerimeter(draft);
      candidates.add(candidate);
    }
    if (candidates.length != names.length) {
      throw StateError('Organic draft has missing material closures');
    }
    return EggOrganicFracturePlan._(
      original,
      draft,
      List<EggOrganicCandidateRegion>.unmodifiable(candidates),
    );
  }

  /// A shortest exact directed path on the immutable ORIGINAL crack graph.
  /// This excludes the new closing edge and prevents overlapping new cuts
  /// from being mistaken for source material boundaries.
  static List<EggRegionBoundaryEdge> _pathFrom(
    EggFractureNetwork network, int start, int end,
  ) {
    final pending = <int>[start];
    final visited = <int>{start};
    final previous = <int, (int, int, bool)>{};
    for (var cursor = 0; cursor < pending.length; cursor++) {
      final node = pending[cursor];
      if (node == end) break;
      for (final edge in network.edges) {
        if (edge.startNode != node && edge.endNode != node) continue;
        final forward = edge.startNode == node;
        final next = forward ? edge.endNode : edge.startNode;
        if (!visited.add(next)) continue;
        previous[next] = (node, edge.id, forward);
        pending.add(next);
      }
    }
    if (!visited.contains(end)) {
      throw StateError('Candidate cannot reconnect to original material');
    }
    final reversed = <EggRegionBoundaryEdge>[];
    var cursor = end;
    while (cursor != start) {
      final step = previous[cursor];
      if (step == null) throw StateError('Broken material closure path');
      reversed.add(EggRegionBoundaryEdge(
        edgeId: step.$2, forward: step.$3,
      ));
      cursor = step.$1;
    }
    return List<EggRegionBoundaryEdge>.unmodifiable(reversed.reversed);
  }
}
