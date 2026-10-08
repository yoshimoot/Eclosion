import 'egg_rear_bowl_boundary.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

/// Stationary curved rear shell patch. All initial perimeter vertices are
/// EXACT original V11.7 objects, including the shared front-side samples.
/// Interior bands are projected to EggShellModel.surfaceAt(back: true),
/// respecting the actual seam even when its longitude shifts near the pole.
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
    // Keep the V11.7 original boundary untouched. Its refined silhouette
    // is not guaranteed to have an azimuth confined to the ideal rear half.
    // Reconstructing an angular winding around the bottom pole is therefore
    // both unnecessary and capable of folding the patch.
    final center = model.surfaceAt(0, centerY, back: true);

    // Interpolate the boundary's projected x/y towards the back center,
    // then project *only the new vertices* onto the rear egg surface.
    // This does not change a single shared front/rear seam vertex.
    // Unlike azimuth interpolation, it has no discontinuity at the
    // bottom pole and avoids foldovers beside the curved silhouette.
    for (var layer = 1; layer <= interiorBands; layer++) {
      final fraction = layer / (interiorBands + 1);
      for (var i = 0; i < size; i++) {
        final originalPoint = shell[i];
        final y = originalPoint.y +
            (centerY - originalPoint.y) * fraction;
        final x = originalPoint.x * (1 - fraction);
        shell.add(model.surfaceAt(x, y, back: true));
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
