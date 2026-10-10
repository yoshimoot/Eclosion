import 'dart:math' as math;

import 'egg_fracture_network.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

/// Real bottom 3D bowl material for the future lower-cradle partition.
///
/// It is a separate, NOT YET RENDERABLE partition candidate: the old
/// upper shell still owns the same material until its upper-side pieces
/// are subtracted along these exact shared lower-cut edge IDs.
class EggOrganicLowerCradleMaterial {
  const EggOrganicLowerCradleMaterial._(
    this.draft, this.outer, this.inner,
    this.outerFaces, this.innerFaces, this.cutWalls,
    this.cutEdgeIds, this.rimCount, this.ringCount, this.thickness,
  );

  final EggFractureNetwork draft;
  final List<EggShellPoint3> outer, inner;
  final List<EggShellTriangle> outerFaces, innerFaces, cutWalls;
  final List<int> cutEdgeIds;
  final int rimCount, ringCount;
  final double thickness;

  factory EggOrganicLowerCradleMaterial.build({
    EggFractureNetwork? draft,
    int ringCount = 6,
    double thickness = 2.5,
  }) {
    if (ringCount < 2 || ringCount > 12 ||
        !thickness.isFinite || thickness <= 0) {
      throw ArgumentError('Invalid lower-cradle material');
    }
    final graph = draft ?? EggFractureNetwork.lowerCradleStaticDraft();
    final original = EggFractureNetwork.organicStaticDraft(
      model: graph.model,
    );
    if (graph.edges.length != original.edges.length + 24) {
      throw StateError('Lower cradle requires 24 NEW shared crack edges');
    }
    final ids = List<int>.generate(
        24, (i) => original.edges.length + i);
    final rim = <EggShellPoint3>[];
    for (var i = 0; i < ids.length; i++) {
      final edge = graph.edges[ids[i]];
      if (edge.id != ids[i] ||
          edge.kind != EggCrackKind.connection ||
          edge.startNode != graph.edges[ids[0]].startNode + i ||
          edge.endNode !=
              graph.edges[ids[0]].startNode + (i + 1) % ids.length) {
        throw StateError('Lower ring is not a connected shell graph cycle');
      }
      if (rim.isNotEmpty &&
          (rim.last - edge.samples.first).length > 1e-7) {
        throw StateError('Lower material cut does not share its junction');
      }
      rim.addAll(i == 0 ? edge.samples : edge.samples.skip(1));
    }
    if ((rim.first - rim.last).length > 1e-7) {
      throw StateError('Lower cradle is not a closed 3D material ring');
    }
    rim.removeLast();
    final model = graph.model;
    final count = rim.length;
    final out = <EggShellPoint3>[...rim];
    for (var ring = 1; ring < ringCount; ring++) {
      final t = ring / ringCount;
      for (final point in rim) {
        final radius = model.radiusAt(point.y);
        final depth = model.depthRadiusAt(point.y);
        final angle = math.atan2(point.x / radius, point.z / depth);
        final y = point.y + (model.halfHeight - point.y) * t;
        out.add(model.pointAt(y, angle));
      }
    }
    final pole = out.length;
    out.add(model.pointAt(model.halfHeight, 0));
    final outside = <EggShellTriangle>[];
    for (var ring = 0; ring + 1 < ringCount; ring++) {
      final start = ring * count, nextRing = (ring + 1) * count;
      for (var i = 0; i < count; i++) {
        final j = (i + 1) % count;
        outside.add(EggShellTriangle(start + i, nextRing + i, start + j));
        outside.add(EggShellTriangle(start + j, nextRing + i,
            nextRing + j));
      }
    }
    for (var i = 0; i < count; i++) {
      outside.add(EggShellTriangle(
          (ringCount - 1) * count + i, pole,
          (ringCount - 1) * count + (i + 1) % count));
    }
    final inner = List<EggShellPoint3>.unmodifiable([
      for (final p in out) model.inset(p, thickness),
    ]);
    final offset = out.length;
    final innerFaces = List<EggShellTriangle>.unmodifiable([
      for (final t in outside)
        EggShellTriangle(t.a + offset, t.c + offset, t.b + offset),
    ]);
    final walls = <EggShellTriangle>[];
    for (var i = 0; i < count; i++) {
      final j = (i + 1) % count;
      walls.add(EggShellTriangle(i, j, i + offset));
      walls.add(EggShellTriangle(j, j + offset, i + offset));
    }
    return EggOrganicLowerCradleMaterial._(
      graph,
      List<EggShellPoint3>.unmodifiable(out),
      inner,
      List<EggShellTriangle>.unmodifiable(outside),
      innerFaces,
      List<EggShellTriangle>.unmodifiable(walls),
      List<int>.unmodifiable(ids),
      count, ringCount, thickness,
    );
  }

  /// A height measure for acceptance against the final reference;
  /// lower Y is higher on screen because Flutter's vertical axis grows
  /// downward. It does NOT make a visual mask or shorten the old bowl.
  double get retainedHeightFraction {
    final topmost = outer.take(rimCount)
        .map((p) => p.y)
        .reduce(math.min);
    return (draft.model.halfHeight - topmost) /
        (2 * draft.model.halfHeight);
  }
}
