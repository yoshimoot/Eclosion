import 'dart:math' as math;

import 'egg_fragment_regions.dart';
import 'egg_fracture_network.dart';
import 'egg_organic_fracture_plan.dart';
import 'egg_shell_model.dart';
import 'egg_stationary_bowl_boundary.dart';

/// One STATIC, non-overlapping material partition of the front shell.
///
/// The original left and right release panels remain whole. Each organic
/// child replaces a patch of the previously fixed FRONT bowl, attached along
/// exactly one already existing original panel/bowl material edge.
///
/// The remaining front bowl is a SINGLE polygon: along those three edges
/// its upper perimeter detours around the other three edges of each child.
/// This represents genuine surface ownership, not an overlay, alpha mask,
/// newly invented crack contour, or moving panel.
///
/// No mesh or animation is changed until this is separately validated.
class EggOrganicBowlPartition {
  EggOrganicBowlPartition._(
    this.organic,
    this.originalRegions,
    this.originalBowl,
    this.cutEdges,
    this.frontUpperBoundary,
    this.edgeOwners,
  );

  final EggOrganicFracturePlan organic;
  final EggFragmentRegionPlan originalRegions;
  final EggStationaryBowlBoundary originalBowl;

  /// New front bowl cuts, excluding the edges now shared parent/child.
  final List<EggRegionBoundaryEdge> cutEdges;

  /// Full F1-front upper seam including intact crown spans, unchanged at
  /// either end; all three child detours use source graph edges by ID.
  final List<EggRegionBoundaryEdge> frontUpperBoundary;

  /// Every material cut has exactly two distinct owners: original parents,
  /// three new organic children and/or the remaining static front bowl.
  /// F1 crown and decorative dead-end fissures are deliberately excluded.
  final Map<int, Set<String>> edgeOwners;

  factory EggOrganicBowlPartition.fixed({
    EggShellModel model = EggShellModel.reference,
  }) {
    final organic = EggOrganicFracturePlan.fixed(model: model);
    final graph = organic.draft;
    final originalRegions =
        EggFragmentRegionPlan.fromNetwork(organic.original);
    final bowl = EggStationaryBowlBoundary.fromRegions(originalRegions);
    final previousCut = {
      for (final edge in bowl.cutEdges) edge.edgeId,
    };
    final replacements = <int, List<EggRegionBoundaryEdge>>{};

    for (final child in organic.candidates) {
      final shared = child.boundary
          .where((step) => previousCut.contains(step.edgeId)).toList();
      if (shared.length != 1) {
        throw StateError('Each child must replace exactly one '
            'old parent/bowl cut: ${child.id}');
      }
      final oldEdge = shared.single;
      if (replacements.containsKey(oldEdge.edgeId)) {
        throw StateError('Two organic children claim the same parent cut');
      }
      final index = child.boundary.indexOf(oldEdge);
      final remaining = <EggRegionBoundaryEdge>[
        ...child.boundary.skip(index + 1),
        ...child.boundary.take(index),
      ];
      if (remaining.length != child.boundary.length - 1 ||
          remaining.length != 3) {
        throw StateError('Unexpected organic cut topology');
      }

      // The remaining oriented path runs from old.end -> old.start.
      // Reverse it only when the actual bowl cut has the opposite winding.
      final sourceStep = bowl.cutEdges.singleWhere(
          (step) => step.edgeId == oldEdge.edgeId);
      final path = sourceStep.startNode(graph) ==
              remaining.first.startNode(graph)
          ? remaining
          : [
              for (final part in remaining.reversed) part.reversed(),
            ];
      if (path.first.startNode(graph) != sourceStep.startNode(graph) ||
          path.last.endNode(graph) != sourceStep.endNode(graph)) {
        throw StateError('Organic bowl detour reverses a material cut');
      }
      replacements[oldEdge.edgeId] =
          List<EggRegionBoundaryEdge>.unmodifiable(path);
    }
    if (replacements.length != 3) {
      throw StateError('Expected three new organic bowl detours');
    }

    List<EggRegionBoundaryEdge> reroute(
      List<EggRegionBoundaryEdge> source,
    ) => List<EggRegionBoundaryEdge>.unmodifiable([
      for (final segment in source)
        ...(replacements[segment.edgeId] ??
            <EggRegionBoundaryEdge>[segment]),
    ]);

    final cuts = reroute(bowl.cutEdges);
    final top = reroute(bowl.frontUpperBoundary);
    for (var i = 0; i < top.length - 1; i++) {
      if (top[i].endNode(graph) != top[i + 1].startNode(graph)) {
        throw StateError('Rerouted front bowl boundary is not continuous');
      }
    }
    if (top.first.startNode(graph) != 6 ||
        top.last.endNode(graph) != 18) {
      throw StateError('Rerouted bowl must keep original F1 crown points');
    }

    // Real material ownership: every cut is between EXACTLY two regions.
    final owners = <int, Set<String>>{};
    void assign(String region, EggRegionBoundaryEdge section) {
      if (graph.edges[section.edgeId].kind == EggCrackKind.crown) return;
      final regions = owners.putIfAbsent(
          section.edgeId, () => <String>{});
      if (!regions.add(region)) {
        throw StateError('Repeated material edge in the same region');
      }
    }
    for (final parent in originalRegions.regions) {
      for (final segment in parent.boundary) {
        assign(parent.id, segment);
      }
    }
    for (final child in organic.candidates) {
      for (final segment in child.boundary) {
        assign(child.id, segment);
      }
    }
    for (final segment in cuts) {
      assign('remaining-front-bowl', segment);
    }
    if (owners.values.any((regions) => regions.length != 2)) {
      throw StateError('A crack has missing or duplicate material owners');
    }
    final used = <int>{};
    for (final edge in cuts) {
      if (!used.add(edge.edgeId)) {
        throw StateError('Rerouted bowl follows a cut twice');
      }
    }
    for (final original in replacements.keys) {
      if (used.contains(original)) {
        throw StateError('Original parent/child cut still belongs to bowl');
      }
    }

    return EggOrganicBowlPartition._(
      organic,
      originalRegions,
      bowl,
      cuts,
      top,
      Map.unmodifiable({
        for (final entry in owners.entries)
          entry.key: Set<String>.unmodifiable(entry.value),
      }),
    );
  }

  /// A single simple closed 3D bowl perimeter. The lower silhouette is
  /// sampled directly on the ORIGINAL EggShellModel; F1/side shape is frozen.
  List<EggShellPoint3> sampledFrontPerimeter({
    int sideSegments = 64,
  }) {
    if (sideSegments < 2) {
      throw ArgumentError.value(sideSegments, 'sideSegments');
    }
    final model = organic.draft.model;
    final points = <EggShellPoint3>[];
    for (final step in frontUpperBoundary) {
      final samples = step.samples(organic.draft);
      points.addAll(points.isEmpty ? samples : samples.skip(1));
    }
    final leftY = organic.draft.nodes[6].y;
    final rightY = organic.draft.nodes[18].y;
    final effectiveSegments = math.max(64, sideSegments);
    for (var i = 1; i <= effectiveSegments; i++) {
      final fraction = i / effectiveSegments;
      points.add(model.pointAt(
        rightY + (model.halfHeight - rightY) * fraction,
        math.pi / 2,
      ));
    }
    for (var i = 1; i < effectiveSegments; i++) {
      final fraction = i / effectiveSegments;
      points.add(model.pointAt(
        model.halfHeight + (leftY - model.halfHeight) * fraction,
        -math.pi / 2,
      ));
    }
    points.add(points.first);
    return List<EggShellPoint3>.unmodifiable(points);
  }
}
