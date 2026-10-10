import 'dart:math' as math;

import 'egg_fragment_regions.dart';
import 'egg_fracture_network.dart';
import 'egg_organic_bowl_partition.dart';
import 'egg_organic_fracture_plan.dart';

/// Which physical material interface is holding one organic child.
enum EggOrganicAttachmentKind { parentCrack, bowlCrack, hinge }

/// A real graph edge, with a *single* deterministic rupture time.
/// No separate outline, fake pixel-space joint or frame-derived randomness.
class EggOrganicAttachment {
  const EggOrganicAttachment({
    required this.edgeId,
    required this.neighborId,
    required this.kind,
    required this.travelDistance,
    required this.ruptureProgress,
  });

  final int edgeId;
  final String neighborId;
  final EggOrganicAttachmentKind kind;
  final double travelDistance;
  final double ruptureProgress;

  bool intactAt(double progress) => progress < ruptureProgress;
}

/// Material state of a child at any normalized animation position.
/// State is a pure query: rewinding or skipping frames changes nothing.
class EggOrganicAttachmentState {
  const EggOrganicAttachmentState({
    required this.intactEdgeIds,
    required this.hingeIntact,
    required this.fullyReleased,
  });

  final Set<int> intactEdgeIds;
  final bool hingeIntact;
  final bool fullyReleased;

  int get intactCount => intactEdgeIds.length;
}

/// Attachment chain of a single daughter fragment; all cuts refer to IDs
/// in EggOrganicBowlPartition.organic.draft, including the parent interface.
class EggOrganicChildAttachmentPlan {
  const EggOrganicChildAttachmentPlan({
    required this.childId,
    required this.parentId,
    required this.attachments,
  });

  final String childId;
  final String parentId;
  final List<EggOrganicAttachment> attachments;

  EggOrganicAttachment get parentCrack =>
      attachments.singleWhere((a) => a.kind == EggOrganicAttachmentKind.parentCrack);
  EggOrganicAttachment get hinge =>
      attachments.singleWhere((a) => a.kind == EggOrganicAttachmentKind.hinge);

  EggOrganicAttachmentState stateAt(double progress) {
    if (!progress.isFinite || progress < 0 || progress > 1) {
      throw ArgumentError.value(progress, 'progress');
    }
    final intact = <int>{
      for (final edge in attachments)
        if (edge.intactAt(progress)) edge.edgeId,
    };
    return EggOrganicAttachmentState(
      intactEdgeIds: Set<int>.unmodifiable(intact),
      hingeIntact: intact.contains(hinge.edgeId),
      fullyReleased: intact.isEmpty,
    );
  }
}

/// V11.35 — PURE material rupture sequence, NOT a movement/renderer.
///
/// The primary left/right panels provide the source event (55% of the
/// experimental 'Sortie' sequence). A crack front then propagates at the
/// SAME surface speed through every child loop, along the same physical
/// graph edges already used by the watertight static partition.
///
/// Each child has four source edges: one shared parent cut, two side cuts
/// and one opposite edge acting as the LAST holding hinge. Hinge rupture
/// gets one common short global lag, after the material front reaches it.
/// None of these states move any point, deform the shell or remove a mesh.
/// An independent pose/collision stage must use them before rendering.
class EggOrganicAttachmentPlan {
  const EggOrganicAttachmentPlan._(
    this.partition, this.children, this.propagationSpeed,
  );

  static const double parentReleaseProgress = .55;
  static const double waveEndProgress = .84;
  static const double hingeLag = .07;

  final EggOrganicBowlPartition partition;
  final List<EggOrganicChildAttachmentPlan> children;
  /// Material arc length per unit normalized progress; shared globally.
  final double propagationSpeed;

  static double _edgeLength(EggCrackEdge edge) {
    var length = 0.0;
    for (var i = 1; i < edge.samples.length; i++) {
      length += (edge.samples[i] - edge.samples[i - 1]).length;
    }
    if (!length.isFinite || length <= 1e-8) {
      throw StateError('Invalid material crack length ${edge.id}');
    }
    return length;
  }

  /// Distance from source parent-edge midpoint to every other edge
  /// midpoint, along the shortest route around the REAL closed loop.
  static Map<int, double> _materialDistances(
    EggOrganicCandidateRegion candidate, EggFractureNetwork graph,
    int parentEdgeId,
  ) {
    final lengths = [
      for (final section in candidate.boundary)
        _edgeLength(graph.edges[section.edgeId]),
    ];
    final perimeter = lengths.reduce((a, b) => a + b);
    var cursor = 0.0;
    final centres = <int, double>{};
    for (var i = 0; i < candidate.boundary.length; i++) {
      centres[candidate.boundary[i].edgeId] = cursor + lengths[i] / 2;
      cursor += lengths[i];
    }
    final start = centres[parentEdgeId];
    if (start == null) throw StateError('Missing source material edge');
    return Map<int, double>.unmodifiable({
      for (final entry in centres.entries)
        entry.key: math.min(
          (entry.value - start).abs(),
          perimeter - (entry.value - start).abs(),
        ),
    });
  }

  factory EggOrganicAttachmentPlan.fixed() {
    final partition = EggOrganicBowlPartition.fixed();
    final graph = partition.organic.draft;
    final originalCuts = {
      for (final edge in partition.originalBowl.cutEdges) edge.edgeId,
    };
    final sources = <(EggOrganicCandidateRegion, int, String, Map<int, double>)>[];
    var longest = 0.0;
    for (final candidate in partition.organic.candidates) {
      final parents = candidate.boundary.where(
        (s) => originalCuts.contains(s.edgeId),
      ).toList();
      if (parents.length != 1 || candidate.boundary.length != 4) {
        throw StateError('A child must have exactly one parent material cut');
      }
      final edgeId = parents.single.edgeId;
      final owners = partition.edgeOwners[edgeId];
      if (owners == null || !owners.contains(candidate.id)) {
        throw StateError('Missing validated material ownership');
      }
      final parent = owners.singleWhere((id) => id != candidate.id);
      if (parent != 'left' && parent != 'right') {
        throw StateError('The organic impulse must originate in a panel');
      }
      final distances = _materialDistances(candidate, graph, edgeId);
      for (final step in candidate.boundary) {
        if (step.edgeId == edgeId) continue;
        longest = math.max(longest, distances[step.edgeId]!);
      }
      sources.add((candidate, edgeId, parent, distances));
    }
    if (!longest.isFinite || longest <= 0) {
      throw StateError('No crack propagation path');
    }
    // A single physical wave speed calibrates ALL three closed contours;
    // no independent per-piece animation or hardcoded panel motion.
    final rate = longest / (waveEndProgress - parentReleaseProgress);
    final children = <EggOrganicChildAttachmentPlan>[];
    for (final (candidate, sourceEdge, parent, distances) in sources) {
      final remaining = candidate.boundary
          .where((step) => step.edgeId != sourceEdge)
          .map((step) => step.edgeId)
          .toList()
        ..sort((a, b) {
          final order = distances[a]!.compareTo(distances[b]!);
          return order != 0 ? order : a.compareTo(b);
        });
      if (remaining.length != 3 ||
          distances[remaining[0]]! <= 0 ||
          distances[remaining[1]]! <= 0) {
        throw StateError('Invalid organic side attachments');
      }
      final hingeId = remaining.last;
      final attachments = <EggOrganicAttachment>[
        EggOrganicAttachment(
          edgeId: sourceEdge,
          neighborId: parent,
          kind: EggOrganicAttachmentKind.parentCrack,
          travelDistance: 0,
          ruptureProgress: parentReleaseProgress,
        ),
        for (final edgeId in remaining)
          EggOrganicAttachment(
            edgeId: edgeId,
            neighborId: 'remaining-front-bowl',
            kind: edgeId == hingeId
                ? EggOrganicAttachmentKind.hinge
                : EggOrganicAttachmentKind.bowlCrack,
            travelDistance: distances[edgeId]!,
            ruptureProgress: parentReleaseProgress +
                distances[edgeId]! / rate +
                (edgeId == hingeId ? hingeLag : 0),
          ),
      ];
      if (attachments.any((a) => a.ruptureProgress > 1.0)) {
        throw StateError('Organic rupture exceeds available timeline');
      }
      children.add(EggOrganicChildAttachmentPlan(
        childId: candidate.id,
        parentId: parent,
        attachments: List<EggOrganicAttachment>.unmodifiable(attachments),
      ));
    }
    return EggOrganicAttachmentPlan._(
      partition,
      List<EggOrganicChildAttachmentPlan>.unmodifiable(children),
      rate,
    );
  }
}
