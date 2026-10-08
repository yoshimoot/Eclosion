import 'egg_fracture_network.dart';
import 'egg_shell_model.dart';

/// One directed use of an existing shared material edge.
/// Never stores new shell geometry or a painted replacement contour.
class EggRegionBoundaryEdge {
  const EggRegionBoundaryEdge({
    required this.edgeId,
    required this.forward,
  });

  final int edgeId;
  final bool forward;

  int startNode(EggFractureNetwork network) {
    final edge = network.edges[edgeId];
    return forward ? edge.startNode : edge.endNode;
  }

  int endNode(EggFractureNetwork network) {
    final edge = network.edges[edgeId];
    return forward ? edge.endNode : edge.startNode;
  }

  /// Reversed traversal reuses the ORIGINAL 3D point objects as well.
  List<EggShellPoint3> samples(EggFractureNetwork network) {
    final samples = network.edges[edgeId].samples;
    return forward ? samples : List<EggShellPoint3>.unmodifiable(
      samples.reversed,
    );
  }

  EggRegionBoundaryEdge reversed() => EggRegionBoundaryEdge(
    edgeId: edgeId,
    forward: !forward,
  );
}

/// A CLOSED candidate panel on the existing curved shell.
///
/// This is boundary topology only: not a cut mesh, triangle ownership,
/// thickness, hinge, detached fragment, or proof of chick clearance.
class EggCandidateShellRegion {
  const EggCandidateShellRegion._({
    required this.id,
    required this.crownRootA,
    required this.crownRootB,
    required this.boundary,
  });

  final String id;
  final int crownRootA;
  final int crownRootB;
  final List<EggRegionBoundaryEdge> boundary;

  List<int> sharedEdgeIds(EggCandidateShellRegion other) {
    final theirs = other.boundary.map((s) => s.edgeId).toSet();
    return List<int>.unmodifiable(
      boundary
          .where((s) => theirs.contains(s.edgeId))
          .map((s) => s.edgeId),
    );
  }

  /// Diagnostic perimeter only; each vertex comes from the shared graph.
  /// Use the boundary edge IDs to construct actual meshes in a later phase.
  List<EggShellPoint3> sampledPerimeter(EggFractureNetwork network) {
    final result = <EggShellPoint3>[];
    for (final segment in boundary) {
      final samples = segment.samples(network);
      result.addAll(result.isEmpty ? samples : samples.skip(1));
    }
    return List<EggShellPoint3>.unmodifiable(result);
  }
}

class _RootPath {
  const _RootPath(this.root, this.steps);

  final int root;
  final List<EggRegionBoundaryEdge> steps;
}

/// V11.1: derive candidate fragment boundaries from V10.4, without
/// modifying any fissure or assuming that a visible side exit cuts a shell.
///
/// Each of the two closing connection chains adds one cycle to the shared
/// crown + mother-fracture graph. Trace that cycle through existing graph
/// edges and the SHORTEST crown arc. The rest of the bowl remains one piece
/// until physical shell segmentation is designed and proven.
class EggFragmentRegionPlan {
  EggFragmentRegionPlan._(this.network, this.regions);

  factory EggFragmentRegionPlan.fromNetwork(EggFractureNetwork network) =>
      EggFragmentRegionPlan._(
        network,
        List<EggCandidateShellRegion>.unmodifiable(_findRegions(network)),
      );

  final EggFractureNetwork network;
  final List<EggCandidateShellRegion> regions;

  static List<EggCandidateShellRegion> _findRegions(
    EggFractureNetwork network,
  ) {
    const crownCount = 24;
    if (network.edges.length < crownCount) {
      throw StateError('Missing crown material edges');
    }

    final crown = network.edges.where(
      (edge) => edge.kind == EggCrackKind.crown,
    ).toList();
    if (crown.length != crownCount) {
      throw StateError('Expected exactly 24 original F1 crown edges');
    }
    for (var i = 0; i < crownCount; i++) {
      final edge = network.edges[i];
      if (edge.kind != EggCrackKind.crown ||
          edge.startNode != i ||
          edge.endNode != (i + 1) % crownCount) {
        throw StateError('Crown seam order was changed at edge $i');
      }
    }

    final motherParent = <int, EggCrackEdge>{};
    for (final edge in network.edges.where(
      (edge) => edge.kind == EggCrackKind.primary,
    )) {
      if (motherParent.containsKey(edge.endNode)) {
        throw StateError('Ambiguous mother at node ${edge.endNode}');
      }
      motherParent[edge.endNode] = edge;
    }

    _RootPath motherPath(int target) {
      var cursor = target;
      final visited = <int>{};
      final reverseSteps = <EggRegionBoundaryEdge>[];
      while (cursor >= crownCount) {
        if (!visited.add(cursor)) {
          throw StateError('Cyclic mother path at node $cursor');
        }
        final incoming = motherParent[cursor];
        if (incoming == null) {
          throw StateError('Unrooted mother path at node $cursor');
        }
        reverseSteps.add(EggRegionBoundaryEdge(
          edgeId: incoming.id,
          forward: true,
        ));
        cursor = incoming.startNode;
      }
      return _RootPath(cursor, reverseSteps.reversed.toList());
    }

    List<EggRegionBoundaryEdge> crownArc(int from, int to) {
      final forwards = (to - from + crownCount) % crownCount;
      final backwards = (from - to + crownCount) % crownCount;
      if (forwards == backwards) {
        throw StateError('Ambiguous F1 crown route from $from to $to');
      }
      final goForward = forwards < backwards;
      final result = <EggRegionBoundaryEdge>[];
      var cursor = from;
      while (cursor != to) {
        final id = goForward ? cursor : (cursor - 1 + crownCount) % crownCount;
        result.add(EggRegionBoundaryEdge(
          edgeId: id,
          forward: goForward,
        ));
        cursor = goForward
            ? (cursor + 1) % crownCount
            : (cursor - 1 + crownCount) % crownCount;
      }
      return result;
    }

    final connections = network.edges.where(
      (edge) => edge.kind == EggCrackKind.connection,
    );
    final groups = <List<EggCrackEdge>>[];
    for (final edge in connections) {
      if (groups.isEmpty || groups.last.last.endNode != edge.startNode) {
        groups.add(<EggCrackEdge>[edge]);
      } else {
        groups.last.add(edge);
      }
    }
    if (groups.length != 2) {
      throw StateError('V10.4 requires exactly two closing chains');
    }

    final regions = <EggCandidateShellRegion>[];
    for (final chain in groups) {
      final start = motherPath(chain.first.startNode);
      final end = motherPath(chain.last.endNode);
      if (start.root == end.root) {
        throw StateError('A closing chain must join distinct mothers');
      }
      var boundary = <EggRegionBoundaryEdge>[
        ...start.steps,
        for (final edge in chain)
          EggRegionBoundaryEdge(edgeId: edge.id, forward: true),
        for (final step in end.steps.reversed) step.reversed(),
        ...crownArc(end.root, start.root),
      ];

      // Orient both candidate faces consistently. In particular, a shared
      // mother edge MUST be traversed in opposite directions by neighbors.
      if (start.root > end.root) {
        boundary = <EggRegionBoundaryEdge>[
          for (final step in boundary.reversed) step.reversed(),
        ];
      }

      final used = <int>{};
      for (var i = 0; i < boundary.length; i++) {
        final step = boundary[i];
        final next = boundary[(i + 1) % boundary.length];
        if (!used.add(step.edgeId)) {
          throw StateError('Repeated boundary edge ${step.edgeId}');
        }
        if (step.endNode(network) != next.startNode(network)) {
          throw StateError('Open candidate region at edge ${step.edgeId}');
        }
        if (network.edges[step.edgeId].kind == EggCrackKind.secondary) {
          throw StateError('An open side crack cannot bound a fragment');
        }
      }
      regions.add(EggCandidateShellRegion._(
        id: start.root < end.root ? 'left' : 'right',
        crownRootA: start.root,
        crownRootB: end.root,
        boundary: List<EggRegionBoundaryEdge>.unmodifiable(boundary),
      ));
    }

    regions.sort((a, b) => a.id.compareTo(b.id));
    if (regions[0].id != 'left' || regions[1].id != 'right') {
      throw StateError('Unexpected V10.4 region ownership');
    }

    final shared = regions[0].sharedEdgeIds(regions[1]).toSet();
    for (final id in shared) {
      final a = regions[0].boundary.singleWhere((s) => s.edgeId == id);
      final b = regions[1].boundary.singleWhere((s) => s.edgeId == id);
      if (a.forward == b.forward) {
        throw StateError('Neighbor regions share an inconsistent edge $id');
      }
    }
    return regions;
  }
}
