import 'dart:math' as math;

import 'egg_organic_bowl_partition.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_front_assembly.dart';
import 'egg_shell_model.dart';

/// V11.34 — an entirely STATIC preview-independent partition:
/// two original parent solids + three new child solids + remaining front
/// bowl patch, with a common material-edge subdivision count.
///
/// This is NOT wired to Flutter's existing painter or collision integrator.
/// That requires a later validation of attachments and physical departure.
class EggOrganicPartitionedStaticMeshes {
  const EggOrganicPartitionedStaticMeshes._(
    this.partition,
    this.parents,
    this.children,
    this.bowl,
    this.refinementPasses,
  );

  final EggOrganicBowlPartition partition;
  final List<EggShellPanelMesh> parents;
  final List<EggShellPanelMesh> children;
  final EggShellSurfacePatch bowl;
  final int refinementPasses;

  static int _passes(int actual, int original) {
    if (original <= 0 || actual < original ||
        actual % original != 0) {
      throw StateError('Organic material perimeter refinement mismatch');
    }
    var factor = actual ~/ original;
    var result = 0;
    while (factor > 1 && factor.isEven) {
      factor ~/= 2;
      result++;
    }
    if (factor != 1 || result > 5) {
      throw StateError('Organic material boundary has nonuniform samples');
    }
    return result;
  }

  factory EggOrganicPartitionedStaticMeshes.build({
    double thickness = 2.5,
    double maxEdgeXY = 24,
    int sideSegments = 64,
  }) {
    if (!thickness.isFinite || thickness <= 0 ||
        !maxEdgeXY.isFinite || maxEdgeXY <= 0 ||
        sideSegments < 2) {
      throw ArgumentError('Invalid organic material mesh parameters');
    }
    final partition = EggOrganicBowlPartition.fixed();
    final model = partition.organic.draft.model;
    final original = EggShellFrontAssemblyBuilder.build(
      partition.originalRegions,
      thickness: thickness,
      maxEdgeXY: maxEdgeXY,
      sideSegments: sideSegments,
    );
    final rims = [
      for (final child in partition.organic.candidates)
        child.sampledPerimeter(partition.organic.draft),
    ];
    final initialChildren = <EggShellPanelMesh>[
      for (var i = 0; i < rims.length; i++)
        EggShellPanelMeshBuilder.fromClosedPerimeter(
          model: model,
          regionId: partition.organic.candidates[i].id,
          closedPerimeter: rims[i],
          thickness: thickness,
          maxEdgeXY: maxEdgeXY,
        ),
    ];
    final bowlRim = partition.sampledFrontPerimeter(
      sideSegments: sideSegments,
    );
    final initialBowl = EggShellPanelMeshBuilder.tessellateExterior(
      model: model,
      closedPerimeter: bowlRim,
      maxEdgeXY: maxEdgeXY,
    );
    final passes = <int>[
      original.refinementPasses,
      for (var i = 0; i < rims.length; i++)
        _passes(initialChildren[i].rim.length, rims[i].length - 1),
      _passes(initialBowl.rim.length, bowlRim.length - 1),
    ];
    final commonPasses = passes.reduce(math.max);
    final parents = commonPasses == original.refinementPasses
        ? original.panels
        : EggShellPanelMeshBuilder.build(
            partition.originalRegions,
            refinementPasses: commonPasses,
            thickness: thickness,
            maxEdgeXY: maxEdgeXY,
          );
    final children = List<EggShellPanelMesh>.unmodifiable([
      for (var i = 0; i < rims.length; i++)
        passes[1 + i] == commonPasses
            ? initialChildren[i]
            : EggShellPanelMeshBuilder.fromClosedPerimeter(
                model: model,
                regionId: partition.organic.candidates[i].id,
                closedPerimeter: rims[i],
                refinementPasses: commonPasses,
                thickness: thickness,
                maxEdgeXY: maxEdgeXY,
              ),
    ]);
    final bowl = passes.last == commonPasses
        ? initialBowl
        : EggShellPanelMeshBuilder.tessellateExterior(
            model: model,
            closedPerimeter: bowlRim,
            refinementPasses: commonPasses,
            maxEdgeXY: maxEdgeXY,
          );
    return EggOrganicPartitionedStaticMeshes._(
      partition,
      List<EggShellPanelMesh>.unmodifiable(parents),
      children,
      bowl,
      commonPasses,
    );
  }

  /// This is only a topology/material identity check. Collision clearance
  /// and visual quality must still be proved after animation is introduced.
  static double projectedArea(List<EggShellPoint3> perimeter) {
    var doubleArea = 0.0;
    for (var i = 0; i < perimeter.length - 1; i++) {
      final a = perimeter[i];
      final b = perimeter[i + 1];
      doubleArea += a.x * b.y - b.x * a.y;
    }
    return doubleArea.abs() / 2;
  }
}
