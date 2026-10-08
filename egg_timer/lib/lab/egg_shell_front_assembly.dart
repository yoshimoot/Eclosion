import 'dart:math' as math;

import 'egg_fragment_regions.dart';
import 'egg_fracture_network.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';
import 'egg_stationary_bowl_boundary.dart';
import 'egg_stationary_bowl_mesh.dart';

/// The two solid candidate panels and the stationary front bowl, with
/// IDENTICAL vertex sampling along every material interface.
/// Geometry only: no live painter, rear shell, hinges or movement.
class EggShellFrontAssembly {
  const EggShellFrontAssembly._(
    this.panels, this.bowl, this.refinementPasses,
  );

  final List<EggShellPanelMesh> panels;
  final EggStationaryBowlFrontMesh bowl;
  final int refinementPasses;
}

class EggShellFrontAssemblyBuilder {
  const EggShellFrontAssemblyBuilder._();

  /// The existing 1-to-4 tessellator splits each original rim edge exactly
  /// once per pass. Infer the adaptive pass count from its actual geometry.
  static int _passes(int rimSize, int originalSegments) {
    if (originalSegments <= 0 || rimSize < originalSegments ||
        rimSize % originalSegments != 0) {
      throw StateError('Invalid original shell boundary subdivision');
    }
    var multiplier = rimSize ~/ originalSegments;
    var result = 0;
    while (multiplier > 1 && multiplier.isEven) {
      multiplier ~/= 2;
      result++;
    }
    if (multiplier != 1 || result > 5) {
      throw StateError('Nonuniform rim subdivisions detected');
    }
    return result;
  }

  /// Parametric coordinates along an ORIGINAL crack subsegment in XY.
  /// The Z coordinate is checked independently when comparing neighbors.
  static double _parameter(
    EggShellPoint3 p, EggShellPoint3 a, EggShellPoint3 b,
  ) {
    final dx = b.x - a.x, dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    if (len2 < 1e-12) {
      throw StateError('Degenerate original material segment');
    }
    final vx = p.x - a.x, vy = p.y - a.y;
    final t = (vx * dx + vy * dy) / len2;
    final cross = vx * dy - vy * dx;
    if (t < -1e-7 || t > 1 + 1e-7 ||
        cross.abs() > 1e-7 * math.sqrt(len2)) {
      return double.nan;
    }
    return t.clamp(0.0, 1.0).toDouble();
  }

  static List<EggShellPoint3> _along(
    List<EggShellPoint3> vertices, List<int> rim,
    EggShellPoint3 a, EggShellPoint3 b,
  ) {
    final positions = <(double, EggShellPoint3)>[];
    for (final id in rim) {
      final p = vertices[id];
      final fraction = _parameter(p, a, b);
      if (fraction.isFinite) positions.add((fraction, p));
    }
    positions.sort((x, y) => x.$1.compareTo(y.$1));
    if (positions.length < 2) {
      throw StateError('Unmapped material rim segment');
    }
    return positions.map((entry) => entry.$2).toList();
  }

  static void _verifyShared(
    EggCrackEdge edge,
    List<EggShellPoint3> va, List<int> ra,
    List<EggShellPoint3> vb, List<int> rb,
  ) {
    for (var i = 0; i + 1 < edge.samples.length; i++) {
      final a = edge.samples[i], b = edge.samples[i + 1];
      final x = _along(va, ra, a, b);
      final y = _along(vb, rb, a, b);
      if (x.length != y.length) {
        throw StateError('T-junction on crack edge ${edge.id}');
      }
      for (var j = 0; j < x.length; j++) {
        if ((x[j].x - y[j].x).abs() > 1e-7 ||
            (x[j].y - y[j].y).abs() > 1e-7 ||
            (x[j].z - y[j].z).abs() > 1e-6) {
          throw StateError('Mismatched 3D material edge ${edge.id}');
        }
      }
    }
  }

  static EggShellFrontAssembly build(
    EggFragmentRegionPlan regions, {
    int sideSegments = 64,
    double maxEdgeXY = 24,
    double thickness = 2.5,
  }) {
    final network = regions.network;
    if (regions.regions.length != 2) {
      throw StateError('V10.4 needs exactly two candidate panels');
    }
    final boundary = EggStationaryBowlBoundary.fromRegions(regions);
    final initialPanels = EggShellPanelMeshBuilder.build(
      regions, thickness: thickness, maxEdgeXY: maxEdgeXY,
    );
    final initialBowl = EggStationaryBowlMeshBuilder.build(
      boundary, sideSegments: sideSegments, maxEdgeXY: maxEdgeXY,
    );
    final counts = <int>[
      for (var i = 0; i < 2; i++)
        _passes(
          initialPanels[i].rim.length,
          regions.regions[i].sampledPerimeter(network).length - 1,
        ),
      _passes(
        initialBowl.surface.rim.length,
        boundary.sampledFrontPerimeter(
          sideSegments: math.max(64, sideSegments),
        ).length - 1,
      ),
    ];
    final sharedPasses = counts.reduce(math.max);
    // Rebuild only surfaces whose adaptive refinement was too coarse.
    final upgradedPanels = counts[0] == sharedPasses &&
            counts[1] == sharedPasses
        ? initialPanels
        : EggShellPanelMeshBuilder.build(
            regions,
            thickness: thickness,
            maxEdgeXY: maxEdgeXY,
            refinementPasses: sharedPasses,
          );
    final panels = List<EggShellPanelMesh>.unmodifiable([
      for (var i = 0; i < 2; i++)
        counts[i] == sharedPasses
            ? initialPanels[i]
            : upgradedPanels[i],
    ]);
    final bowl = counts[2] == sharedPasses
        ? initialBowl
        : EggStationaryBowlMeshBuilder.build(
            boundary,
            sideSegments: sideSegments,
            maxEdgeXY: maxEdgeXY,
            refinementPasses: sharedPasses,
          );

    // 15 panel-to-bowl boundaries and 3 panel-to-panel boundaries are
    // compared *per original crack sample segment*, not by silhouette.
    final owner = <int, int>{};
    for (var i = 0; i < 2; i++) {
      for (final segment in regions.regions[i].boundary) {
        owner.putIfAbsent(segment.edgeId, () => i);
      }
    }
    for (final segment in boundary.cutEdges) {
      final i = owner[segment.edgeId];
      if (i == null) {
        throw StateError('Material cut has no panel owner');
      }
      _verifyShared(
        network.edges[segment.edgeId],
        panels[i].outer, panels[i].rim,
        bowl.surface.vertices, bowl.surface.rim,
      );
    }
    for (final id in regions.regions[0].sharedEdgeIds(regions.regions[1])) {
      _verifyShared(
        network.edges[id],
        panels[0].outer, panels[0].rim,
        panels[1].outer, panels[1].rim,
      );
    }
    return EggShellFrontAssembly._(panels, bowl, sharedPasses);
  }
}
