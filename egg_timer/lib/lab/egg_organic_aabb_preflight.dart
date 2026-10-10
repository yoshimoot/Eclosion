import 'dart:math' as math;

import 'egg_exit_motion_config.dart';
import 'egg_geometry_preview.dart';
import 'egg_panel_hinge_pose.dart';
import 'egg_panel_release_motion.dart';
import 'egg_rear_bowl_boundary.dart';
import 'egg_rear_bowl_mesh.dart';
import 'egg_shell_front_assembly.dart';
import 'egg_stationary_bowl_shell.dart';
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

  bool overlaps(_Box3 b) => overlapsWithMargin(b, 1e-7);

  /// Inflate the *relative* movement of both rigid materials; this
  /// produces a conservative Minkowski envelope in world XYZ.
  bool overlapsWithMargin(_Box3 b, double margin) =>
      x0 <= b.x1 + margin && x1 >= b.x0 - margin &&
      y0 <= b.y1 + margin && y1 >= b.y0 - margin &&
      z0 <= b.z1 + margin && z1 >= b.z0 - margin;
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

  /// Conservative interval broad phase. A returning (false, true)
  /// means EVERY pair of triangle world AABBs is separated throughout
  /// the interval if [maximumRelativeDisplacement] bounds both objects'
  /// material vertex movements from the sampled midpoint.
  ///
  /// A budget stop returns (true, false), NEVER a false clearance.
  (bool, bool) possibleDuringInterval(
    _TriangleIndex moving, {
    required double maximumRelativeDisplacement,
    int maxBoxChecks = 200000,
  }) {
    if (!maximumRelativeDisplacement.isFinite ||
        maximumRelativeDisplacement < 0 || maxBoxChecks <= 0) {
      throw ArgumentError('Invalid conservative collision envelope');
    }
    final margin = maximumRelativeDisplacement + 1e-7;
    var inspected = 0;
    for (final box in moving.boxes) {
      final seen = <int>{};
      final lo = ((box.x0 - margin) / cellWidth).floor();
      final hi = ((box.x1 + margin) / cellWidth).floor();
      for (var cell = lo; cell <= hi; cell++) {
        for (final id in buckets[cell] ?? const <int>[]) {
          if (!seen.add(id)) continue;
          inspected++;
          if (inspected > maxBoxChecks) return (true, false);
          if (box.overlapsWithMargin(boxes[id], margin)) {
            return (true, true);
          }
        }
      }
    }
    return (false, true);
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

/// V11.42 — exact SINGLE-SAMPLE supplement covering the rear fixed
/// shell and the two historical V11.32 panels, in addition to the
/// front-bowl/sibling tests of [EggOrganicAabbPreflight.inspectExact].
/// It is still not a conservative continuous-time collision sweep.
class EggOrganicEnvironmentExactFrame {
  const EggOrganicEnvironmentExactFrame({
    required this.frontAndSiblings,
    required this.rearTouching,
    required this.rearIntersections,
    required this.parentTouching,
    required this.parentIntersections,
    required this.testedPairs,
    required this.complete,
  });

  final EggOrganicExactFrame frontAndSiblings;
  final List<int> rearTouching, rearIntersections;
  final Map<String, int> parentTouching, parentIntersections;
  final int testedPairs;
  final bool complete;

  bool get hasObservedIntersection =>
      frontAndSiblings.hasObservedIntersection ||
      rearIntersections.any((count) => count > 0) ||
      parentIntersections.values.any((count) => count > 0);

  bool get sampledFrameClear => complete &&
      frontAndSiblings.sampledFrameClear &&
      !rearTouching.any((count) => count > 0) &&
      !rearIntersections.any((count) => count > 0) &&
      !parentTouching.values.any((count) => count > 0) &&
      !parentIntersections.values.any((count) => count > 0);
}

/// The verdict is conservative ONLY for the represented triangle
/// surfaces over [startProgress, endProgress]; it is not a valid renderer
/// approval if any of the referenced mesh builders failed earlier tests.
enum EggOrganicIntervalVerdict {
  certifiedClear,
  observedIntersection,
  inconclusive,
}

class EggOrganicIntervalReport {
  const EggOrganicIntervalReport({
    required this.startProgress,
    required this.endProgress,
    required this.verdict,
    required this.envelopeComplete,
    required this.sampledExactComplete,
  });

  final double startProgress;
  final double endProgress;
  final EggOrganicIntervalVerdict verdict;
  final bool envelopeComplete;
  final bool sampledExactComplete;
}

class EggOrganicEnvironmentPreflight {
  const EggOrganicEnvironmentPreflight._(
    this.organic, this.rear, this.parents, this.parentMeshes,
  );

  final EggOrganicAabbPreflight organic;
  final _TriangleIndex rear;
  final List<EggPanelReleaseMotion> parents;
  final List<EggShellPanelMesh> parentMeshes;

  factory EggOrganicEnvironmentPreflight.build() {
    final organic = EggOrganicAabbPreflight.build();
    final scene = organic.scene;
    final staged = scene.staged.meshes;
    final regions = staged.partition.originalRegions;
    final originalAssembly = EggShellFrontAssemblyBuilder.build(regions);
    final originalFront = EggStationaryBowlShellBuilder.build(
      originalAssembly,
    );
    final rearMesh = EggRearBowlMeshBuilder.build(
      EggRearBowlBoundaryBuilder.build(originalFront),
    );
    final rear = _TriangleIndex.build(
      <EggShellPoint3>[
        ...rearMesh.exterior, ...rearMesh.interior,
      ],
      <EggShellTriangle>[
        ...rearMesh.outerFaces,
        ...rearMesh.innerFaces,
        ...rearMesh.rearCrownWalls,
      ],
    );
    // Use the EXACT V11.32 panel motion, not a new animation approximation.
    final parentMotions = <EggPanelReleaseMotion>[
      for (var i = 0; i < staged.parents.length; i++)
        EggExitMotionConfig.build(
          panel: staged.parents[i],
          model: regions.network.model,
          hinge: EggPanelHingePose.fromGraph(
            panel: staged.parents[i],
            region: regions.regions[i],
            neighbor: regions.regions[1 - i],
            network: regions.network,
            openingDegrees: EggExitTimeline.finalHingeDegrees,
          ),
        ),
    ];
    return EggOrganicEnvironmentPreflight._(
      organic,
      rear,
      List<EggPanelReleaseMotion>.unmodifiable(parentMotions),
      staged.parents,
    );
  }

  /// Only valid AFTER the big panels release at 55% of diagnostic progress.
  /// At 100% they keep their actual final V11.32 pose while organic pieces
  /// may continue to settle for up to 3 seconds after their own release.
  EggOrganicEnvironmentExactFrame inspectExact(
    double progress, {
    double afterZeroSeconds = 0,
    int maxPairsPerPair = 20000,
  }) {
    if (!progress.isFinite || progress < .55 || progress > 1 ||
        maxPairsPerPair <= 0) {
      throw ArgumentError('Environment collision sample must be after '
          'the mother panels release, with positive triangle budget');
    }
    final base = organic.inspectExact(
      progress,
      afterZeroSeconds: afterZeroSeconds,
      maxPairsPerPair: maxPairsPerPair,
    );
    final releaseClock = math.min(
      2.0, (progress - .55) * (2 / .45),
    );
    final movingChildren = <_TriangleIndex>[
      for (var i = 0; i < organic.scene.staged.meshes.children.length; i++)
        EggOrganicAabbPreflight._moving(
          organic.scene.poseAt(
            i, progress, afterZeroSeconds: afterZeroSeconds,
          ),
        ),
    ];
    final movingParents = <_TriangleIndex>[
      for (var i = 0; i < parentMeshes.length; i++)
        _TriangleIndex.build(
          <EggShellPoint3>[
            ...parents[i].transformAll(
              parentMeshes[i].outer, releaseClock,
            ),
            ...parents[i].transformAll(
              parentMeshes[i].inner, releaseClock,
            ),
          ],
          <EggShellTriangle>[
            ...parentMeshes[i].outerTriangles,
            ...parentMeshes[i].innerTriangles,
            ...parentMeshes[i].sideTriangles,
          ],
        ),
    ];
    final rearTouch = <int>[], rearCross = <int>[];
    final parentTouch = <String, int>{};
    final parentCross = <String, int>{};
    var complete = base.complete;
    var inspected = base.testedPairs;
    for (var i = 0; i < movingChildren.length; i++) {
      final (pairs, touching, crossing, all) =
          rear.inspectExact(
            movingChildren[i], maxPairs: maxPairsPerPair,
          );
      inspected += pairs;
      complete = complete && all;
      rearTouch.add(touching);
      rearCross.add(crossing);
      for (var j = 0; j < movingParents.length; j++) {
        final (count, touchingParent, crossingParent, checked) =
            movingParents[j].inspectExact(
              movingChildren[i], maxPairs: maxPairsPerPair,
            );
        inspected += count;
        complete = complete && checked;
        parentTouch['$i:$j'] = touchingParent;
        parentCross['$i:$j'] = crossingParent;
      }
    }
    return EggOrganicEnvironmentExactFrame(
      frontAndSiblings: base,
      rearTouching: List<int>.unmodifiable(rearTouch),
      rearIntersections: List<int>.unmodifiable(rearCross),
      parentTouching: Map<String, int>.unmodifiable(parentTouch),
      parentIntersections: Map<String, int>.unmodifiable(parentCross),
      testedPairs: inspected,
      complete: complete,
    );
  }
  /// A strict conservative time-interval preflight. Every queried triangle
  /// is enclosed by its midpoint world AABB plus the maximal material
  /// travel from midpoint to either endpoint. If ALL such relative
  /// envelopes are disjoint, the entire interval is proven clear of those
  /// represented surfaces. Otherwise inspect the exact midpoint; an
  /// observed transverse intersection is a real sampled failure, while
  /// all other outcomes remain inconclusive (not an invented clearance).
  EggOrganicIntervalReport inspectInterval({
    required double startProgress,
    required double endProgress,
    int maxBoxChecksPerPair = 200000,
    int maxExactPairsPerPair = 20000,
  }) {
    if (!startProgress.isFinite || !endProgress.isFinite ||
        startProgress < .55 || endProgress > 1 ||
        endProgress <= startProgress ||
        maxBoxChecksPerPair <= 0 || maxExactPairsPerPair <= 0) {
      throw ArgumentError('Invalid physical inspection window or budget');
    }
    final midpoint = (startProgress + endProgress) / 2;
    final halfWidth = (endProgress - startProgress) / 2;
    const secondsPerProgress = 2 / .45;
    final childIndices = <_TriangleIndex>[
      for (var i = 0; i < organic.scene.seeds.length; i++)
        EggOrganicAabbPreflight._moving(
          organic.scene.poseAt(i, midpoint),
        ),
    ];
    final parentIndices = <_TriangleIndex>[
      for (var i = 0; i < parentMeshes.length; i++)
        _TriangleIndex.build(
          <EggShellPoint3>[
            ...parents[i].transformAll(
              parentMeshes[i].outer,
              (midpoint - .55) * secondsPerProgress,
            ),
            ...parents[i].transformAll(
              parentMeshes[i].inner,
              (midpoint - .55) * secondsPerProgress,
            ),
          ],
          <EggShellTriangle>[
            ...parentMeshes[i].outerTriangles,
            ...parentMeshes[i].innerTriangles,
            ...parentMeshes[i].sideTriangles,
          ],
        ),
    ];

    // Max derivative of smoothstep(u)=u*u*(3-2*u) is 1.5.
    // Every original mesh point remains at most this lever arm away from
    // the hinge anchor during the attached phase.
    final childMaximumSpeeds = <double>[];
    for (var i = 0; i < organic.scene.staged.hinges.length; i++) {
      final hinge = organic.scene.staged.hinges[i];
      final width =
          hinge.releaseProgress - hinge.openingStartProgress;
      var attachedLever = 0.0;
      for (final point in [
        ...hinge.mesh.outer,
        ...hinge.mesh.inner,
      ]) {
        attachedLever = math.max(
          attachedLever, (point - hinge.anchorA).length,
        );
      }
      final attachedSpeed =
          hinge.signedMaxRadians.abs() * 1.5 / width * attachedLever;
      final flyingSpeed = organic.scene.flights[i]
          .materialVertexSpeedUpperBoundAt(3) * secondsPerProgress;
      childMaximumSpeeds.add(math.max(attachedSpeed, flyingSpeed));
    }
    final parentMaximumSpeeds = <double>[
      for (final motion in parents)
        (motion.linearSpeedUpperBoundAt(2) +
            motion.angularSpeedUpperBoundAt(2) *
                motion.materialRadius) * secondsPerProgress,
    ];

    var allClear = true, complete = true;
    void check(
      _TriangleIndex stationary,
      _TriangleIndex moving,
      double relativeSpeed,
    ) {
      final (potential, done) = stationary.possibleDuringInterval(
        moving,
        maximumRelativeDisplacement: relativeSpeed * halfWidth,
        maxBoxChecks: maxBoxChecksPerPair,
      );
      complete = complete && done;
      if (potential) allClear = false;
    }

    for (var i = 0; i < childIndices.length; i++) {
      check(organic.bowl, childIndices[i], childMaximumSpeeds[i]);
      check(rear, childIndices[i], childMaximumSpeeds[i]);
      for (var j = 0; j < parentIndices.length; j++) {
        check(
          parentIndices[j],
          childIndices[i],
          childMaximumSpeeds[i] + parentMaximumSpeeds[j],
        );
      }
      for (var j = i + 1; j < childIndices.length; j++) {
        check(
          childIndices[i],
          childIndices[j],
          childMaximumSpeeds[i] + childMaximumSpeeds[j],
        );
      }
    }
    if (allClear && complete) {
      return EggOrganicIntervalReport(
        startProgress: startProgress,
        endProgress: endProgress,
        verdict: EggOrganicIntervalVerdict.certifiedClear,
        envelopeComplete: true,
        sampledExactComplete: false,
      );
    }
    final sample = inspectExact(
      midpoint, maxPairsPerPair: maxExactPairsPerPair,
    );
    return EggOrganicIntervalReport(
      startProgress: startProgress,
      endProgress: endProgress,
      verdict: sample.hasObservedIntersection
          ? EggOrganicIntervalVerdict.observedIntersection
          : EggOrganicIntervalVerdict.inconclusive,
      envelopeComplete: complete,
      sampledExactComplete: sample.complete,
    );
  }


}
