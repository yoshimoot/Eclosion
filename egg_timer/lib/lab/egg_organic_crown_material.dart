import 'dart:math' as math;

import 'egg_fracture_network.dart';
import 'egg_organic_bowl_partition.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

/// Material owner of the original F1 crown (360 degrees).
///
/// The cap is NOT animated or drawn by this structure. No physical
/// detachment of F1 is permitted before its 3D contacts are validated.
class EggOrganicCrownMaterial {
  const EggOrganicCrownMaterial._(
    this.partition, this.outer, this.inner,
    this.outerFaces, this.innerFaces, this.cutWalls,
    this.edgeOwners, this.rimCount, this.ringCount, this.thickness,
  );

  final EggOrganicBowlPartition partition;
  final List<EggShellPoint3> outer, inner;
  final List<EggShellTriangle> outerFaces, innerFaces, cutWalls;
  final Map<int, Set<String>> edgeOwners;
  final int rimCount, ringCount;
  final double thickness;

  /// The first [rimCount] exterior vertices ARE the source graph samples.
  List<EggShellPoint3> get crownRim =>
      List<EggShellPoint3>.unmodifiable(outer.take(rimCount));

  factory EggOrganicCrownMaterial.build({
    EggOrganicBowlPartition? partition,
    int ringCount = 6,
    double thickness = 2.5,
  }) {
    if (ringCount < 2 || ringCount > 12 ||
        !thickness.isFinite || thickness <= 0) {
      throw ArgumentError('Invalid crown material tessellation');
    }
    final body = partition ?? EggOrganicBowlPartition.fixed();
    final graph = body.organic.draft;
    final model = graph.model;
    final owners = <int, Set<String>>{
      for (var id = 0; id < 24; id++) id: {'crown-cap'},
    };
    void claim(int id, String part) {
      if (!owners[id]!.add(part)) {
        throw StateError('Duplicate F1 owner $part on edge $id');
      }
    }
    for (var id = 18; id < 24; id++) {
      claim(id, 'remaining-rear-bowl');
    }
    for (var id = 0; id < 6; id++) {
      claim(id, 'remaining-rear-bowl');
    }
    for (final panel in body.originalRegions.regions) {
      for (final edge in panel.boundary) {
        if (graph.edges[edge.edgeId].kind == EggCrackKind.crown) {
          claim(edge.edgeId, panel.id);
        }
      }
    }
    for (final edge in body.frontUpperBoundary) {
      if (graph.edges[edge.edgeId].kind == EggCrackKind.crown) {
        claim(edge.edgeId, 'remaining-front-bowl');
      }
    }
    for (final entry in owners.entries) {
      if (entry.value.length != 2) {
        throw StateError('Missing crown material neighbor ${entry.key}');
      }
    }

    final perimeter = <EggShellPoint3>[];
    for (var id = 0; id < 24; id++) {
      final edge = graph.edges[id];
      if (edge.kind != EggCrackKind.crown ||
          edge.startNode != id || edge.endNode != (id + 1) % 24) {
        throw StateError('Original crown topology was modified');
      }
      if (perimeter.isNotEmpty &&
          (perimeter.last - edge.samples.first).length > 1e-7) {
        throw StateError('Physical crown segment disconnected');
      }
      perimeter.addAll(id == 0 ? edge.samples : edge.samples.skip(1));
    }
    if ((perimeter.first - perimeter.last).length > 1e-7) {
      throw StateError('F1 crown does not close in 3D');
    }
    perimeter.removeLast();
    final count = perimeter.length;
    if (count < 24) throw StateError('Crown has missing samples');

    // A full front+rear 360° loop overlaps in XY projection. Loft the
    // ORIGINAL sampled 3D material ring toward the true upper pole;
    // never use a 2D ear clipper or redraw the accepted F1 border.
    final exterior = <EggShellPoint3>[...perimeter];
    for (var ring = 1; ring < ringCount; ring++) {
      final t = ring / ringCount;
      for (final point in perimeter) {
        final r = model.radiusAt(point.y);
        final d = model.depthRadiusAt(point.y);
        if (r <= 1e-8 || d <= 1e-8) {
          throw StateError('Zero-radius F1 boundary');
        }
        final angle = math.atan2(point.x / r, point.z / d);
        final y = point.y + (-model.halfHeight - point.y) * t;
        exterior.add(model.pointAt(y, angle));
      }
    }
    final pole = exterior.length;
    exterior.add(model.pointAt(-model.halfHeight, 0));
    final outerFaces = <EggShellTriangle>[];
    for (var ring = 0; ring + 1 < ringCount; ring++) {
      final start = ring * count, nextRing = (ring + 1) * count;
      for (var i = 0; i < count; i++) {
        final next = (i + 1) % count;
        outerFaces.add(EggShellTriangle(start + i, start + next,
            nextRing + i));
        outerFaces.add(EggShellTriangle(start + next, nextRing + next,
            nextRing + i));
      }
    }
    final last = (ringCount - 1) * count;
    for (var i = 0; i < count; i++) {
      outerFaces.add(EggShellTriangle(
          last + i, last + (i + 1) % count, pole));
    }
    final inside = List<EggShellPoint3>.unmodifiable([
      for (final p in exterior) model.inset(p, thickness),
    ]);
    final offset = exterior.length;
    final insideFaces = List<EggShellTriangle>.unmodifiable([
      for (final t in outerFaces)
        EggShellTriangle(t.a + offset, t.c + offset, t.b + offset),
    ]);
    final walls = <EggShellTriangle>[];
    for (var i = 0; i < count; i++) {
      final next = (i + 1) % count;
      walls.add(EggShellTriangle(next, i, i + offset));
      walls.add(EggShellTriangle(next, i + offset, next + offset));
    }
    return EggOrganicCrownMaterial._(
      body,
      List<EggShellPoint3>.unmodifiable(exterior),
      inside,
      List<EggShellTriangle>.unmodifiable(outerFaces),
      insideFaces,
      List<EggShellTriangle>.unmodifiable(walls),
      Map<int, Set<String>>.unmodifiable({
        for (final entry in owners.entries)
          entry.key: Set<String>.unmodifiable(entry.value),
      }),
      count, ringCount, thickness,
    );
  }
}
