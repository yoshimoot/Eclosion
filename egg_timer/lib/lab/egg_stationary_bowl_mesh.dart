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
  }) {
    final surface = EggShellPanelMeshBuilder.tessellateExterior(
      model: boundary.plan.network.model,
      closedPerimeter:
          boundary.sampledFrontPerimeter(sideSegments: sideSegments),
      maxEdgeXY: maxEdgeXY,
    );
    return EggStationaryBowlFrontMesh._(boundary, surface);
  }
}
