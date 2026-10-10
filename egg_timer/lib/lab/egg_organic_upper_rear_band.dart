import 'dart:math' as math;

import 'egg_organic_full_shell_draft.dart';
import 'egg_organic_upper_front_band.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

/// Physical REAR side strip between the unchanged F1 crown and the
/// new low 360-degree material cut. Both lateral joins share the exact
/// vertex OBJECTS of the separately tessellated upper FRONT strip.
///
/// No rear silhouette cap is added: front/back meet on their curved
/// surfaces, while F1 and low-cut walls use the actual shell thickness.
class EggOrganicUpperRearBand {
  const EggOrganicUpperRearBand._(
    this.front, this.outer, this.inner,
    this.outerFaces, this.innerFaces, this.cutWalls,
    this.rowLength, this.bandCount,
  );

  final EggOrganicUpperFrontBand front;
  final List<EggShellPoint3> outer, inner;
  final List<EggShellTriangle> outerFaces, innerFaces, cutWalls;
  final int rowLength, bandCount;

  static EggOrganicUpperRearBand build({
    required EggOrganicFullShellDraft draft,
    required EggOrganicUpperFrontBand front,
  }) {
    final graph = draft.network;
    final model = graph.model;
    final upper = <EggShellPoint3>[];
    final lower = <EggShellPoint3>[];
    for (final id in <int>[
      for (var i = 18; i < 24; i++) i,
      for (var i = 0; i < 6; i++) i,
    ]) {
      final crownSamples = graph.edges[id].samples;
      final lowerSamples = graph.edges[
          draft.cradle.cutEdgeIds[id]].samples;
      upper.addAll(upper.isEmpty
          ? crownSamples : crownSamples.skip(1));
      lower.addAll(lower.isEmpty
          ? lowerSamples : lowerSamples.skip(1));
    }
    final bands = front.rightSeam.length - 1;
    if (bands < 4 || upper.length != lower.length ||
        upper.length < 25 || front.leftSeam.length != bands + 1) {
      throw StateError('Rear and front share no compatible 3D grid');
    }
    final n = upper.length;
    // Reuse by IDENTITY the four meeting points of the front, lower and
    // rear shells: no reconstructed corner, no 2D matching tolerance.
    upper[0] = front.topPerimeter.last;
    upper[n - 1] = front.topPerimeter.first;
    lower[0] = front.lowerFrontArc.last;
    lower[n - 1] = front.lowerFrontArc.first;

    final outer = <EggShellPoint3>[];
    for (var layer = 0; layer <= bands; layer++) {
      final t = layer / bands;
      for (var j = 0; j < n; j++) {
        if (j == 0) {
          outer.add(front.rightSeam[layer]);
        } else if (j == n - 1) {
          outer.add(front.leftSeam[bands - layer]);
        } else if (layer == 0) {
          outer.add(upper[j]);
        } else if (layer == bands) {
          outer.add(lower[j]);
        } else {
          final p = lower[j];
          final r = model.radiusAt(p.y);
          final d = model.depthRadiusAt(p.y);
          final angle = math.atan2(p.x / r, p.z / d);
          final y = upper[j].y + (lower[j].y - upper[j].y) * t;
          outer.add(model.pointAt(y, angle));
        }
      }
    }
    final faces = <EggShellTriangle>[];
    for (var row = 0; row < bands; row++) {
      final a = row * n, b = (row + 1) * n;
      for (var j = 0; j + 1 < n; j++) {
        faces.add(EggShellTriangle(a + j, a + j + 1, b + j));
        faces.add(EggShellTriangle(a + j + 1, b + j + 1, b + j));
      }
    }
    final thickness = draft.cradle.thickness;
    final inner = List<EggShellPoint3>.unmodifiable([
      for (final point in outer) model.inset(point, thickness),
    ]);
    final offset = outer.length;
    final innerFaces = List<EggShellTriangle>.unmodifiable([
      for (final f in faces)
        EggShellTriangle(f.a + offset, f.c + offset, f.b + offset),
    ]);
    final walls = <EggShellTriangle>[];
    for (final row in [0, bands]) {
      final start = row * n;
      for (var i = 0; i + 1 < n; i++) {
        final a = start + i, b = a + 1;
        walls.add(EggShellTriangle(b, a, a + offset));
        walls.add(EggShellTriangle(b, a + offset, b + offset));
      }
    }
    return EggOrganicUpperRearBand._(
      front,
      List<EggShellPoint3>.unmodifiable(outer),
      inner,
      List<EggShellTriangle>.unmodifiable(faces),
      innerFaces,
      List<EggShellTriangle>.unmodifiable(walls),
      n, bands,
    );
  }
}
