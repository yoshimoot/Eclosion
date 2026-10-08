import 'dart:math' as math;

import 'egg_rear_bowl_boundary.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

/// Stationary curved rear shell patch. All initial perimeter vertices are
/// EXACT original V11.7 objects, including the shared front-side samples.
/// Interior rows are projected through EggShellModel.pointAt(y, angle).
///
/// This still is a geometry-only diagnostic: the live F1 painter is frozen.
class EggRearBowlMesh {
  const EggRearBowlMesh._({
    required this.boundary,
    required this.thickness,
    required this.exterior,
    required this.interior,
    required this.outerFaces,
    required this.innerFaces,
    required this.rearCrownWalls,
  });

  final EggRearBowlBoundary boundary;
  final double thickness;
  final List<EggShellPoint3> exterior;
  final List<EggShellPoint3> interior;
  final List<EggShellTriangle> outerFaces;
  final List<EggShellTriangle> innerFaces;

  /// Only the 192 rear F1 crown rim segments are given thickness walls.
  /// The front/rear side seams remain open for shared-vertex assembly.
  final List<EggShellTriangle> rearCrownWalls;

  int get vertexCount => exterior.length * 2;
  int get perimeterLength => boundary.closedPerimeter.length - 1;
  int get crownEdgeCount => boundary.rearCrown.length - 1;

  /// The rear silhouette is an unsealed pair of front-shared side arcs.
  int get sideSeamEdgeCount => perimeterLength - crownEdgeCount;
}

class EggRearBowlMeshBuilder {
  const EggRearBowlMeshBuilder._();

  static double _angle(EggShellPoint3 point, EggShellModel model) {
    if ((model.halfHeight - point.y).abs() <= 1e-8) {
      return math.pi; // The single bottom pole has no angular direction.
    }
    final r = model.radiusAt(point.y);
    final zRadius = model.depthRadiusAt(point.y);
    if (r <= 1e-10 || zRadius <= 1e-10) {
      throw StateError('Rear boundary cannot be parametrized');
    }
    var angle = math.atan2(point.x / r, point.z / zRadius);
    if (angle < 0) angle += 2 * math.pi;
    // The original back crown and the slightly front-offset silhouette
    // both unwrap continuously from right (pi/2) to left (3pi/2).
    if (angle < math.pi / 2 - .12 ||
        angle > math.pi * 1.5 + .12) {
      throw StateError('Rear boundary has an unexpected angular winding');
    }
    return angle;
  }

  /// Build a curved patch using concentric parameter-space bands.
  ///
  /// Unlike clipping a pre-existing grid, this construction has exactly
  /// the same boundary edges as V11.7, with NO extra seam vertices.
  /// The cap of each band connects to one internal rear pole, giving a
  /// single topological disk before the inner face and cut thickness.
  static EggRearBowlMesh build(
    EggRearBowlBoundary boundary, {
    double thickness = 2.5,
    int interiorBands = 3,
    double centerY = 34,
  }) {
    if (!thickness.isFinite || thickness <= 0) {
      throw ArgumentError.value(thickness, 'thickness');
    }
    if (interiorBands < 1 || interiorBands > 8) {
      throw ArgumentError.value(interiorBands, 'interiorBands');
    }
    final model = boundary.frontShell.assembly.bowl.boundary.plan.network.model;
    if (!centerY.isFinite ||
        centerY <= -model.halfHeight || centerY >= model.halfHeight) {
      throw ArgumentError.value(centerY, 'centerY');
    }
    if ((boundary.frontShell.thickness - thickness).abs() > 1e-8) {
      throw StateError('Rear and front fixed bowl thickness must agree');
    }
    final original = boundary.closedPerimeter;
    if (original.length < 10 || !identical(original.first, original.last)) {
      throw StateError('Rear boundary must have one shared closure vertex');
    }
    final size = original.length - 1;
    final shell = List<EggShellPoint3>.of(original.take(size));
    final angles = <double>[
      for (final p in shell) _angle(p, model),
    ];
    final center = model.pointAt(centerY, math.pi);

    // Place each internal band BETWEEN the shared exterior perimeter and
    // the rear center, always on the physical revolution surface.
    for (var layer = 1; layer <= interiorBands; layer++) {
      final fraction = layer / (interiorBands + 1);
      for (var i = 0; i < size; i++) {
        final y = shell[i].y + (centerY - shell[i].y) * fraction;
        final angle =
            angles[i] + (math.pi - angles[i]) * fraction;
        shell.add(model.pointAt(y, angle));
      }
    }
    final centerIndex = shell.length;
    shell.add(center);

    final faces = <EggShellTriangle>[];
    for (var layer = 0; layer < interiorBands; layer++) {
      final outer = layer * size;
      final inner = (layer + 1) * size;
      for (var i = 0; i < size; i++) {
        final next = (i + 1) % size;
        final a = outer + i, b = outer + next;
        final c = inner + i, d = inner + next;
        faces.add(EggShellTriangle(a, b, c));
        faces.add(EggShellTriangle(b, d, c));
      }
    }
    final lastLayer = interiorBands * size;
    for (var i = 0; i < size; i++) {
      faces.add(EggShellTriangle(
        lastLayer + i, lastLayer + (i + 1) % size, centerIndex,
      ));
    }

    final inner = List<EggShellPoint3>.unmodifiable([
      for (final point in shell) model.inset(point, thickness),
    ]);
    final offset = shell.length;
    final innerFaces = List<EggShellTriangle>.unmodifiable([
      for (final tri in faces)
        EggShellTriangle(
          tri.a + offset, tri.c + offset, tri.b + offset,
        ),
    ]);
    final crownEdges = boundary.rearCrown.length - 1;
    final walls = <EggShellTriangle>[];
    for (var i = 0; i < crownEdges; i++) {
      final a = i, b = i + 1;
      // The rear patch traces its perimeter from right crown -> left.
      walls.add(EggShellTriangle(b, a, a + offset));
      walls.add(EggShellTriangle(b, a + offset, b + offset));
    }

    return EggRearBowlMesh._(
      boundary: boundary,
      thickness: thickness,
      exterior: List<EggShellPoint3>.unmodifiable(shell),
      interior: inner,
      outerFaces: List<EggShellTriangle>.unmodifiable(faces),
      innerFaces: innerFaces,
      rearCrownWalls: List<EggShellTriangle>.unmodifiable(walls),
    );
  }
}
