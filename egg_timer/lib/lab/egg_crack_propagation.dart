import 'dart:math' as math;

import 'egg_fracture_network.dart';
import 'egg_shell_model.dart';

/// Time interval assigned to ONE existing shared geometric crack edge.
///
/// A schedule never owns or recreates geometry. Its edgeId refers directly
/// to EggFractureNetwork.edges[edgeId] throughout the whole timer session.
class EggCrackSchedule {
  const EggCrackSchedule({
    required this.edgeId,
    required this.kind,
    required this.onset,
    required this.completion,
    required this.preservedF1,
    this.predecessorEdgeId,
  });

  final int edgeId;
  final EggCrackKind kind;
  final double onset;
  final double completion;
  final bool preservedF1;
  final int? predecessorEdgeId;

  /// Continuous visible fraction of the original edge, from 0 to 1.
  double visibleFraction(double progress) {
    if (!progress.isFinite) {
      throw ArgumentError.value(progress, 'progress', 'Must be finite');
    }
    if (preservedF1) return 1;
    final t = progress.clamp(0.0, 1.0).toDouble();
    if (t <= onset) return 0;
    if (t >= completion) return 1;
    return (t - onset) / (completion - onset);
  }
}

/// V9 is a causal PROPAGATION PLAN, not a painter or timer implementation.
///
/// - F1 crown and its two existing upper-cap scratches are preserved.
/// - Mother cracks start from the shared crown nodes.
/// - Secondary branches can start only after their parent reaches the fork.
/// - Closing connections appear later and preserve the same geometric edges.
/// - Normalized progress is independent of clock/Flutter animation frames.
/// - V10 will reveal fractions of the SAME sampled 3D paths, not new strokes.
///
/// The V8 crack layout is provisional; this plan deliberately does not
/// approve it or alter any node/edge positions.
class EggCrackPropagationPlan {
  EggCrackPropagationPlan(EggFractureNetwork network)
      : network = network,
        schedules = List<EggCrackSchedule>.unmodifiable(
          _buildSchedules(network),
        );

  final EggFractureNetwork network;
  final List<EggCrackSchedule> schedules;

  static bool _isPreservedF1(
    EggFractureNetwork network,
    EggCrackEdge edge,
  ) {
    if (edge.kind == EggCrackKind.crown) return true;
    if (edge.kind != EggCrackKind.secondary) return false;
    final tip = network.nodes[edge.endNode];
    // The two intentionally retained F1 scratches lie ABOVE the crown.
    // Do not accidentally retime them while developing the fixed bowl.
    return tip.y < network.model.crownFractureY(tip.angle);
  }

  static double _edgeLength(EggCrackEdge edge) {
    var length = 0.0;
    for (var i = 1; i < edge.samples.length; i++) {
      final EggShellPoint3 a = edge.samples[i - 1];
      final EggShellPoint3 b = edge.samples[i];
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final dz = b.z - a.z;
      length += math.sqrt(dx * dx + dy * dy + dz * dz);
    }
    return length;
  }

  static List<EggCrackSchedule> _buildSchedules(
    EggFractureNetwork network,
  ) {
    final edges = network.edges;
    final preserved = <bool>[
      for (final edge in edges) _isPreservedF1(network, edge),
    ];
    final result = List<EggCrackSchedule?>.filled(edges.length, null);
    final visiting = <int>{};

    int? choosePredecessor(EggCrackEdge edge) {
      final candidates = edges.where((incoming) =>
          incoming.endNode == edge.startNode &&
          incoming.id != edge.id &&
          !preserved[incoming.id]);

      // Explicit provenance. A new late closing connection must NOT delay
      // the pre-existing main fault it joins at the other end.
      final preferred = switch (edge.kind) {
        EggCrackKind.primary => EggCrackKind.primary,
        EggCrackKind.connection => EggCrackKind.connection,
        EggCrackKind.secondary => EggCrackKind.secondary,
        EggCrackKind.crown => EggCrackKind.crown,
      };
      for (final incoming in candidates) {
        if (incoming.kind == preferred) return incoming.id;
      }
      for (final incoming in candidates) {
        if (incoming.kind == EggCrackKind.primary) return incoming.id;
      }
      if (edge.startNode < 24) return null; // Root on the shared F1 crown.
      throw StateError(
        'Crack edge ${edge.id} has no causally reachable parent at node '
        '${edge.startNode}',
      );
    }

    EggCrackSchedule resolve(int id) {
      final existing = result[id];
      if (existing != null) return existing;
      if (!visiting.add(id)) {
        throw StateError('Cyclic propagation dependencies at edge $id');
      }
      final edge = edges[id];
      if (edge.id != id) {
        throw StateError('Crack edge IDs must match their list positions');
      }
      if (preserved[id]) {
        final locked = EggCrackSchedule(
          edgeId: id,
          kind: edge.kind,
          onset: 0,
          completion: 0,
          preservedF1: true,
        );
        result[id] = locked;
        visiting.remove(id);
        return locked;
      }

      final parentId = choosePredecessor(edge);
      final parent = parentId == null ? null : resolve(parentId);
      final gate = switch (edge.kind) {
        EggCrackKind.primary => .16,
        EggCrackKind.secondary => .51,
        EggCrackKind.connection => .69,
        EggCrackKind.crown => throw StateError('Crown must remain preserved'),
      };
      final rootStagger = parent == null &&
              edge.kind == EggCrackKind.primary
          ? (edge.startNode % 5) * .012
          : 0.0;
      final onset = math.max(
        gate + rootStagger,
        parent == null ? 0.0 : parent.completion + .012,
      );
      // Length affects propagation; no frame-dependent random values.
      final duration = .018 + math.min(.060, _edgeLength(edge) * .00105);
      final completion = onset + duration;
      if (completion > 1.0) {
        throw StateError(
          'Crack edge $id cannot finish before session end: $completion',
        );
      }
      final scheduled = EggCrackSchedule(
        edgeId: id,
        kind: edge.kind,
        onset: onset,
        completion: completion,
        preservedF1: false,
        predecessorEdgeId: parentId,
      );
      result[id] = scheduled;
      visiting.remove(id);
      return scheduled;
    }

    for (var id = 0; id < edges.length; id++) {
      resolve(id);
    }
    return <EggCrackSchedule>[
      for (final scheduled in result) scheduled!,
    ];
  }

  /// Pure, deterministic state at arbitrary normalized elapsed progress.
  /// No rendering, mutations, animations or frame-to-frame integration.
  List<double> visibleFractionsAt(double progress) {
    if (!progress.isFinite) {
      throw ArgumentError.value(progress, 'progress', 'Must be finite');
    }
    return List<double>.unmodifiable(
      <double>[for (final edge in schedules) edge.visibleFraction(progress)],
    );
  }
}
