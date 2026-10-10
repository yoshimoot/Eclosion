import 'dart:math' as math;

import 'egg_organic_attached_hinge_pose.dart';
import 'egg_organic_staged_assembly.dart';
import 'egg_shell_model.dart';

/// V11.37 — immutable, exact 3D initial data for future free flight.
///
/// A collision-aware flight solver must start at THIS pose (not reconstruct
/// an approximate new shard, move the 2D silhouette, or fade out the parent).
/// No velocities, collisions or rendering are invented in this data object.
class EggOrganicReleaseSeed {
  const EggOrganicReleaseSeed._({
    required this.childId,
    required this.releaseProgress,
    required this.center,
    required this.outward,
    required this.hingeAxis,
    required this.materialRadius,
    required this.floorY,
    required this.outer,
    required this.inner,
  });

  final String childId;
  final double releaseProgress;
  final EggShellPoint3 center;
  final EggShellPoint3 outward;
  final EggShellPoint3 hingeAxis;
  final double materialRadius;
  final double floorY;
  final List<EggShellPoint3> outer, inner;

  factory EggOrganicReleaseSeed.fromStaged(
    EggOrganicStagedAssembly staged,
    int index,
  ) {
    if (index < 0 || index >= staged.hinges.length) {
      throw RangeError.index(index, staged.hinges);
    }
    final pose = staged.hinges[index];
    final model = staged.meshes.partition.organic.draft.model;
    final mesh = staged.meshes.children[index];
    final time = pose.releaseProgress;
    final outer = pose.transformAllAttached(mesh.outer, time);
    final inner = pose.transformAllAttached(mesh.inner, time);

    // Material-area centroid, not the bounding-box middle. This is the
    // correct rigid-body origin when the free flight starts.
    var weightedCenter = const EggShellPoint3(0, 0, 0);
    var weightedOutward = const EggShellPoint3(0, 0, 0);
    var totalArea = 0.0;
    for (final face in mesh.outerTriangles) {
      final a = outer[face.a];
      final b = outer[face.b];
      final c = outer[face.c];
      final cross = EggShellPoint3(
        (b.y-a.y)*(c.z-a.z) - (b.z-a.z)*(c.y-a.y),
        (b.z-a.z)*(c.x-a.x) - (b.x-a.x)*(c.z-a.z),
        (b.x-a.x)*(c.y-a.y) - (b.y-a.y)*(c.x-a.x),
      );
      final area = cross.length / 2;
      if (!area.isFinite || area <= 1e-12) {
        throw StateError('Degenerate organic release triangle');
      }
      weightedCenter = weightedCenter + (a + b + c) * (area / 3);
      final materialNormal = (model.normalAt(mesh.outer[face.a]) +
          model.normalAt(mesh.outer[face.b]) +
          model.normalAt(mesh.outer[face.c])) * (1 / 3);
      weightedOutward = weightedOutward +
          pose.releaseNormalOf(materialNormal) * area;
      totalArea += area;
    }
    if (!totalArea.isFinite || totalArea <= 1e-8 ||
        weightedOutward.length <= 1e-8) {
      throw StateError('Organic release has no usable outward impulse');
    }
    final center = weightedCenter * (1 / totalArea);
    final outward = weightedOutward.normalized;
    var radius = 0.0;
    for (final p in [...outer, ...inner]) {
      radius = math.max(radius, (p - center).length);
    }
    if (!radius.isFinite || radius <= 1e-5 ||
        !center.x.isFinite || !center.y.isFinite || !center.z.isFinite) {
      throw StateError('Invalid organic rigid material release');
    }
    return EggOrganicReleaseSeed._(
      childId: pose.child.childId,
      releaseProgress: time,
      center: center,
      outward: outward,
      hingeAxis: pose.axis,
      materialRadius: radius,
      floorY: model.halfHeight + 8,
      outer: outer,
      inner: inner,
    );
  }
}
