import 'dart:math' as math;

import 'egg_organic_continuous_pose.dart';
import 'egg_shell_collision_diagnostic.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

/// A necessary-contact broad phase, never a penetration solver.
/// AABB overlap means ONLY 'possible triangle contact'. A complete count
/// of zero proves disjoint triangle AABBs at the exact sampled instant,
/// not at intermediate instants, not for the rear bowl or future chick.
class EggOrganicAabbReport {
  const EggOrganicAabbReport({
    required this.progress,
    required this.bowlCandidatePairs,
    required this.siblingCandidatePairs,
    required this.complete,
  });

  final double progress;
  final List<int> bowlCandidatePairs;
  final Map<String, int> siblingCandidatePairs;
  final bool complete;

  bool get hasAnyPossibleContact =>
      bowlCandidatePairs.any((v) => v > 0) ||
      siblingCandidatePairs.values.any((v) => v > 0);
}

class _Box3 {
  const _Box3(this.x0, this.x1, this.y0, this.y1, this.z0, this.z1);

  final double x0, x1, y0, y1, z0, z1;

  factory _Box3.triangle(EggShellPoint3 a,
      EggShellPoint3 b, EggShellPoint3 c) {
    final x0 = math.min(a.x, math.min(b.x, c.x));
    final x1 = math.max(a.x, math.max(b.x, c.x));
    final y0 = math.min(a.y, math.min(b.y, c.y));
    final y1 = math.max(a.y, math.max(b.y, c.y));
    final z0 = math.min(a.z, math.min(b.z, c.z));
    final z1 = math.max(a.z, math.max(b.z, c.z));
    if (![x0, x1, y0, y1, z0, z1].every((v) => v.isFinite)) {
      throw StateError('Non-finite organic triangle material');
    }
    return _Box3(x0, x1, y0, y1, z0, z1);
  }

  bool overlaps(_Box3 b) =>
      x0 <= b.x1 + 1e-7 && x1 >= b.x0 - 1e-7 &&
      y0 <= b.y1 + 1e-7 && y1 >= b.y0 - 1e-7 &&
      z0 <= b.z1 + 1e-7 && z1 >= b.z0 - 1e-7;
}

class _TriangleIndex {
  _TriangleIndex._(this.vertices, this.triangles, this.boxes, this.buckets);

  static const double cellWidth = 24;
  final List<EggShellPoint3> vertices;
  final List<EggShellTriangle> triangles;
  final List<_Box3> boxes;
  final Map<int, List<int>> buckets;

  factory _TriangleIndex.build(
    List<EggShellPoint3> vertices, List<EggShellTriangle> triangles,
  ) {
    final bounds = [
      for (final t in triangles)
        _Box3.triangle(
          vertices[t.a], vertices[t.b], vertices[t.c],
        ),
    ];
    final cells = <int, List<int>>{};
    for (var i = 0; i < bounds.length; i++) {
      final box = bounds[i];
      final lo = (box.x0 / cellWidth).floor();
      final hi = (box.x1 / cellWidth).floor();
      if (hi - lo > 128) {
        throw StateError('Unbounded organic triangle grid extent');
      }
      for (var x = lo; x <= hi; x++) {
        cells.putIfAbsent(x, () => <int>[]).add(i);
      }
    }
    return _TriangleIndex._(vertices, triangles, bounds, cells);
  }

  /// Classify each potential triangle pair using the existing single
  /// source-of-truth 3D SAT / plane-crossing kernel. The report describes
  /// only one sampled instant of the faces supplied to this index.
  (int, int, int, bool) inspectExact(
    _TriangleIndex moving, {
    int maxPairs = 20000,
  }) {
    if (maxPairs <= 0) {
      throw ArgumentError.value(maxPairs, 'maxPairs');
    }
    var tested = 0, touching = 0, penetrating = 0;
    for (var j = 0; j < moving.boxes.length; j++) {
      final movingBox = moving.boxes[j];
      final visited = <int>{};
      final lo = (movingBox.x0 / cellWidth).floor();
      final hi = (movingBox.x1 / cellWidth).floor();
      final movingFace = moving.triangles[j];
      for (var x = lo; x <= hi; x++) {
        for (final i in buckets[x] ?? const <int>[]) {
          if (!visited.add(i) || !movingBox.overlaps(boxes[i])) {
            continue;
          }
          final fixedFace = triangles[i];
          final classification = EggTriangleCollision.classify(
            vertices[fixedFace.a], vertices[fixedFace.b],
            vertices[fixedFace.c],
            moving.vertices[movingFace.a],
            moving.vertices[movingFace.b],
            moving.vertices[movingFace.c],
          );
          tested++;
          if (classification == EggTriangleContact.touching) touching++;
          if (classification == EggTriangleContact.intersecting) {
            penetrating++;
          }
          if (tested >= maxPairs) {
            return (tested, touching, penetrating, false);
          }
        }
      }
    }
    return (tested, touching, penetrating, true);
  }

  /// Deterministic bounded candidate inspection, no false-clear result
  /// when budget is exhausted. Only whole AABB overlaps are counted.
  (int, bool) compare(
    _TriangleIndex moving, {
    int maxCandidates = 20000,
  }) {
    if (maxCandidates <= 0) {
      throw ArgumentError.value(maxCandidates, 'maxCandidates');
    }
    var candidates = 0;
    for (final box in moving.boxes) {
      final visited = <int>{};
      final lo = (box.x0 / cellWidth).floor();
      final hi = (box.x1 / cellWidth).floor();
      for (var x = lo; x <= hi; x++) {
        for (final id in buckets[x] ?? const <int>[]) {
          if (!visited.add(id)) continue;
          if (!box.overlaps(boxes[id])) continue;
          candidates++;
          if (candidates >= maxCandidates) {
            return (candidates, false);
          }
        }
      }
    }
    return (candidates, true);
  }
}

/// Exact 3D triangle classification of ONE sampled position.
/// An observed intersection is genuine material penetration at that
/// sample; a complete clear sample does NOT certify the temporal interval.
class EggOrganicExactFrame {
  const EggOrganicExactFrame({
    required this.progress,
    required this.bowlTouching,
    required this.bowlIntersections,
    required this.siblingTouching,
    required this.siblingIntersections,
    required this.testedPairs,
    required this.complete,
  });

  final double progress;
  final List<int> bowlTouching, bowlIntersections;
  final Map<String, int> siblingTouching, siblingIntersections;
  final int testedPairs;
  final bool complete;

  bool get hasObservedIntersection =>
      bowlIntersections.any((value) => value > 0) ||
      siblingIntersections.values.any((value) => value > 0);
  bool get sampledFrameClear => complete &&
      !hasObservedIntersection &&
      !bowlTouching.any((value) => value > 0) &&
      !siblingTouching.values.any((value) => value > 0);
}

/// V11.40 — light diagnostic of the actual organics and their REMAINING
/// front bowl exterior surface. Does not change the rendered V11.32 mode.
/// Exact triangle intersection and full parent/rear-bowl swept collision
/// detection are required before displaying the new flying children.
class EggOrganicAabbPreflight {
  EggOrganicAabbPreflight._(this.scene, this.bowl);

  final EggOrganicContinuousPoseCoordinator scene;
  final _TriangleIndex bowl;

  factory EggOrganicAabbPreflight.build() {
    final scene = EggOrganicContinuousPoseCoordinator.fixed();
    final surface = scene.staged.meshes.bowl;
    final bowl = _TriangleIndex.build(
      surface.vertices, surface.triangles,
    );
    return EggOrganicAabbPreflight._(scene, bowl);
  }

  static _TriangleIndex _moving(EggOrganicMaterialSnapshot snap) {
    final size = snap.outer.length;
    final mesh = snap.mesh;
    final points = <EggShellPoint3>[...snap.outer, ...snap.inner];
    if (points.length != size * 2 ||
        mesh.inner.length != size) {
      throw StateError('Incomplete organic 3D thickness');
    }
    return _TriangleIndex.build(points, <EggShellTriangle>[
      ...mesh.outerTriangles, ...mesh.innerTriangles, ...mesh.sideTriangles,
    ]);
  }

  EggOrganicAabbReport inspect(
    double progress, {
    double afterZeroSeconds = 0,
    int maxCandidatesPerPair = 20000,
  }) {
    if (maxCandidatesPerPair <= 0) {
      throw ArgumentError.value(
        maxCandidatesPerPair, 'maxCandidatesPerPair',
      );
    }
    final moving = <_TriangleIndex>[
      for (var i = 0; i < scene.staged.meshes.children.length; i++)
        _moving(scene.poseAt(
          i, progress, afterZeroSeconds: afterZeroSeconds,
        )),
    ];
    var complete = true;
    final bowlHits = <int>[];
    for (final index in moving) {
      final (count, checked) = bowl.compare(
        index, maxCandidates: maxCandidatesPerPair,
      );
      complete = complete && checked;
      bowlHits.add(count);
    }
    final siblingHits = <String, int>{};
    for (var i = 0; i < moving.length; i++) {
      for (var j = i + 1; j < moving.length; j++) {
        final (count, checked) = moving[i].compare(
          moving[j], maxCandidates: maxCandidatesPerPair,
        );
        complete = complete && checked;
        siblingHits['$i:$j'] = count;
      }
    }
    return EggOrganicAabbReport(
      progress: progress,
      bowlCandidatePairs: List<int>.unmodifiable(bowlHits),
      siblingCandidatePairs: Map<String, int>.unmodifiable(siblingHits),
      complete: complete,
    );
  }
  /// Returns exact observed triangle penetrations of the *represented*
  /// front bowl and organic siblings; parent panels/rear bowl are not yet
  /// included. This is a bounded sample, NOT continuous collision proof.
  EggOrganicExactFrame inspectExact(
    double progress, {
    double afterZeroSeconds = 0,
    int maxPairsPerPair = 20000,
  }) {
    if (maxPairsPerPair <= 0) {
      throw ArgumentError.value(maxPairsPerPair, 'maxPairsPerPair');
    }
    final moving = <_TriangleIndex>[
      for (var i = 0; i < scene.staged.meshes.children.length; i++)
        _moving(scene.poseAt(
          i, progress, afterZeroSeconds: afterZeroSeconds,
        )),
    ];
    final bowlTouching = <int>[], bowlIntersecting = <int>[];
    final siblingTouching = <String, int>{};
    final siblingIntersecting = <String, int>{};
    var complete = true, tested = 0;
    for (final current in moving) {
      final (pairs, touching, intersecting, allPairs) =
          bowl.inspectExact(current, maxPairs: maxPairsPerPair);
      tested += pairs;
      complete = complete && allPairs;
      bowlTouching.add(touching);
      bowlIntersecting.add(intersecting);
    }
    for (var i = 0; i < moving.length; i++) {
      for (var j = i + 1; j < moving.length; j++) {
        final (pairs, touching, intersecting, allPairs) =
            moving[i].inspectExact(
              moving[j], maxPairs: maxPairsPerPair,
            );
        tested += pairs;
        complete = complete && allPairs;
        siblingTouching['$i:$j'] = touching;
        siblingIntersecting['$i:$j'] = intersecting;
      }
    }
    return EggOrganicExactFrame(
      progress: progress,
      bowlTouching: List<int>.unmodifiable(bowlTouching),
      bowlIntersections: List<int>.unmodifiable(bowlIntersecting),
      siblingTouching: Map<String, int>.unmodifiable(siblingTouching),
      siblingIntersections: Map<String, int>.unmodifiable(siblingIntersecting),
      testedPairs: tested,
      complete: complete,
    );
  }

}
