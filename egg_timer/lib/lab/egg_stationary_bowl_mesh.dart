import 'dart:math' as math;

import 'egg_shell_fragment_mesh.dart';
import 'egg_stationary_bowl_boundary.dart';

/// Front exterior surface of the stationary bowl with both V11.2 panels
/// excluded; this is DATA only, not yet the active Flutter painter.
class EggStationaryBowlFrontMesh {
  const EggStationaryBowlFrontMesh._(this.boundary, this.surface);
  final EggStationaryBowlBoundary boundary;
  final EggShellSurfacePatch surface;
}

class EggStationaryBowlMeshBuilder {
  const EggStationaryBowlMeshBuilder._();

  static EggStationaryBowlFrontMesh build(
    EggStationaryBowlBoundary boundary, {
    int sideSegments = 64,
    double maxEdgeXY = 24,
    int? refinementPasses,
  }) {
    if (sideSegments < 2) {
      throw ArgumentError.value(sideSegments, 'sideSegments');
    }
    // Near the lateral F1 crown contacts, a coarse silhouette polygon
    // can cut across the true egg curve and become locally self-crossing.
    // Preserve the same EggShellModel profile, with enough side samples
    // to keep the material cut simple (never clip/delete an ear by alpha).
    final resolvedSides = math.max(64, sideSegments);
    final surface = EggShellPanelMeshBuilder.tessellateExterior(
      model: boundary.plan.network.model,
      closedPerimeter: boundary.sampledFrontPerimeter(
        sideSegments: resolvedSides,
      ),
      maxEdgeXY: maxEdgeXY,
      refinementPasses: refinementPasses,
    );
    return EggStationaryBowlFrontMesh._(boundary, surface);
  }
}
