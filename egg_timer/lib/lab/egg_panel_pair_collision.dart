import 'dart:math' as math;

import 'egg_panel_release_motion.dart';
import 'egg_shell_collision_diagnostic.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

/// V11.15: collision report for ONE sampled pair of independent release
/// elapsed times. An exhaustive sample is not continuous collision
/// detection, and touching is not necessarily penetration.
class EggPanelPairCollisionFrame {
  const EggPanelPairCollisionFrame({
    required this.firstSeconds,
    required this.secondSeconds,
    required this.testedPairs,
    required this.touchingPairs,
    required this.intersectingPairs,
    required this.complete,
    required this.firstTouchingTrianglePair,
    required this.firstIntersectingTrianglePair,
  });

  final double firstSeconds;
  final double secondSeconds;
  final int testedPairs;
  final int touchingPairs;
  final int intersectingPairs;
  final bool complete;

  /// (triangle index in first panel, triangle index in second panel).
  final (int, int)? firstTouchingTrianglePair;
  final (int, int)? firstIntersectingTrianglePair;

  bool get hasContact => touchingPairs > 0 || intersectingPairs > 0;
  bool get hasIntersection => intersectingPairs > 0;

  /// Clearance of this SAMPLE only, if the spatial search was complete.
  bool get sampledFrameClear => complete && !hasContact;
}

class _Bounds3 {
  const _Bounds3(
    this.x0, this.x1, this.y0, this.y1, this.z0, this.z1,
  );
  final double x0, x1, y0, y1, z0, z1;

  factory _Bounds3.triangle(
    EggShellPoint3 a, EggShellPoint3 b, EggShellPoint3 c,
  ) => _Bounds3(
    math.min(a.x, math.min(b.x, c.x)),
    math.max(a.x, math.max(b.x, c.x)),
    math.min(a.y, math.min(b.y, c.y)),
    math.max(a.y, math.max(b.y, c.y)),
    math.min(a.z, math.min(b.z, c.z)),
    math.max(a.z, math.max(b.z, c.z)),
  );

  factory _Bounds3.union(List<_Bounds3> boxes, List<int> ids) {
    var x0 = double.infinity, y0 = double.infinity, z0 = double.infinity;
    var x1 = double.negativeInfinity;
    var y1 = double.negativeInfinity;
    var z1 = double.negativeInfinity;
    for (final id in ids) {
      final box = boxes[id];
      x0 = math.min(x0, box.x0); x1 = math.max(x1, box.x1);
      y0 = math.min(y0, box.y0); y1 = math.max(y1, box.y1);
      z0 = math.min(z0, box.z0); z1 = math.max(z1, box.z1);
    }
    return _Bounds3(x0, x1, y0, y1, z0, z1);
  }

  double centerOn(int dimension) => switch (dimension) {
    0 => (x0 + x1) / 2,
    1 => (y0 + y1) / 2,
    _ => (z0 + z1) / 2,
  };

  bool overlaps(_Bounds3 other, double tolerance) =>
      x0 <= other.x1 + tolerance && x1 >= other.x0 - tolerance &&
      y0 <= other.y1 + tolerance && y1 >= other.y0 - tolerance &&
      z0 <= other.z1 + tolerance && z1 >= other.z0 - tolerance;
}

class _PairNode {
  const _PairNode(this.bounds, this.ids, this.left, this.right);
  final _Bounds3 bounds;
  final List<int>? ids;
  final _PairNode? left;
  final _PairNode? right;
}

/// Two moving rigid panels, ONE prebuilt BVH.
///
/// The first panel is indexed at rest. At every sample the second moving
/// panel is transformed from world space back into the FIRST panel's original
/// material frame. This is possible because both V11.13 poses are rigid:
/// no repeated BVH rebuild, no deformation, no shortcut via 2D projection.
///
/// The separate elapsed times support staggered release. No integration with
/// the active Flutter painter or timer; no collision avoidance is imposed.
class EggPanelPairCollisionInspector {
  EggPanelPairCollisionInspector({
    required EggShellPanelMesh first,
    required EggShellPanelMesh second,
    required EggPanelReleaseMotion firstMotion,
    required EggPanelReleaseMotion secondMotion,
    this.tolerance = 1e-7,
  }) : _firstMotion = firstMotion,
       _secondMotion = secondMotion,
       _second = second,
       _fixedPoints = List<EggShellPoint3>.unmodifiable([
         ...first.outer, ...first.inner,
       ]),
       _firstTriangles = List<EggShellTriangle>.unmodifiable([
         ...first.outerTriangles,
         ...first.innerTriangles,
         ...first.sideTriangles,
       ]),
       _secondTriangles = List<EggShellTriangle>.unmodifiable([
         ...second.outerTriangles,
         ...second.innerTriangles,
         ...second.sideTriangles,
       ]) {
    if (!tolerance.isFinite || tolerance < 0) {
      throw ArgumentError.value(tolerance, 'tolerance');
    }
    if (identical(first, second) || first.regionId == second.regionId) {
      throw ArgumentError('The two shell panels must be distinct');
    }
    if (!_belongs(first, firstMotion) || !_belongs(second, secondMotion)) {
      throw StateError('A release trajectory does not belong to its panel');
    }
    if (first.inner.length != first.outer.length ||
        second.inner.length != second.outer.length ||
        _firstTriangles.isEmpty || _secondTriangles.isEmpty) {
      throw StateError('Incomplete shell collision geometry');
    }
    _firstBoxes = List<_Bounds3>.generate(_firstTriangles.length, (i) {
      final triangle = _firstTriangles[i];
      return _Bounds3.triangle(
        _fixedPoints[triangle.a],
        _fixedPoints[triangle.b],
        _fixedPoints[triangle.c],
      );
    });
    _firstTree = _build(
      List<int>.generate(_firstTriangles.length, (i) => i),
    );
  }

  static bool _belongs(
    EggShellPanelMesh panel, EggPanelReleaseMotion motion,
  ) =>
      panel.outer.any((p) => identical(p, motion.hinge.anchorA)) &&
      panel.outer.any((p) => identical(p, motion.hinge.anchorB));

  final EggPanelReleaseMotion _firstMotion;
  final EggPanelReleaseMotion _secondMotion;
  final EggShellPanelMesh _second;
  final List<EggShellPoint3> _fixedPoints;
  final List<EggShellTriangle> _firstTriangles;
  final List<EggShellTriangle> _secondTriangles;
  final double tolerance;

  late final List<_Bounds3> _firstBoxes;
  late final _PairNode _firstTree;

  _PairNode _build(List<int> indices) {
    final box = _Bounds3.union(_firstBoxes, indices);
    if (indices.length <= 8) {
      return _PairNode(
        box, List<int>.unmodifiable(indices), null, null,
      );
    }
    final spans = [
      box.x1 - box.x0,
      box.y1 - box.y0,
      box.z1 - box.z0,
    ];
    final axis = spans.indexOf(spans.reduce(math.max));
    indices.sort((a, b) => _firstBoxes[a].centerOn(axis)
        .compareTo(_firstBoxes[b].centerOn(axis)));
    final midpoint = indices.length ~/ 2;
    return _PairNode(
      box, null,
      _build(indices.sublist(0, midpoint)),
      _build(indices.sublist(midpoint)),
    );
  }

  static double _dot(EggShellPoint3 a, EggShellPoint3 b) =>
      a.x * b.x + a.y * b.y + a.z * b.z;

  static EggShellPoint3 _cross(EggShellPoint3 a, EggShellPoint3 b) =>
      EggShellPoint3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x,
      );

  static EggShellPoint3 _rotate(
    EggShellPoint3 p, EggShellPoint3 axis, double angle,
  ) {
    final c = math.cos(angle), s = math.sin(angle);
    return p * c + _cross(axis, p) * s +
        axis * (_dot(axis, p) * (1 - c));
  }

  /// Exact inverse of V11.13's combined attached+free rotation:
  /// world = centerAt(t) + R(hingeAngle + freeSpin) * (source - materialCenter).
  /// R is a rotation about the SAME normalized hinge axis in both phases.
  EggShellPoint3 toFirstMaterialSpace(
    EggShellPoint3 world, double firstSeconds,
  ) {
    final angle = _firstMotion.hinge.signedRadians +
        _firstMotion.spinRadiansAt(firstSeconds);
    return _firstMotion.materialCenter +
        _rotate(
          world - _firstMotion.centerAt(firstSeconds),
          _firstMotion.hinge.axis,
          -angle,
        );
  }

  /// Inspect an instantaneous pose of both moving shell panels.
  ///
  /// The budget counts candidate TRIANGLE PAIRS after the broad-phase
  /// boxes overlap. If reached, [complete] is false and zero collisions
  /// is NOT clearance. Different sample times are permitted.
  EggPanelPairCollisionFrame inspect({
    required double firstSeconds,
    required double secondSeconds,
    int maxPairs = 50000,
  }) {
    if (maxPairs <= 0) {
      throw ArgumentError.value(maxPairs, 'maxPairs');
    }
    // V11.13 validates each release time in [0, 2] independently.
    final secondOuter = _secondMotion.transformAll(
      _second.outer, secondSeconds,
    );
    final secondInner = _secondMotion.transformAll(
      _second.inner, secondSeconds,
    );
    final worldPoints = <EggShellPoint3>[
      ...secondOuter, ...secondInner,
    ];
    final localPoints = <EggShellPoint3>[
      for (final point in worldPoints)
        toFirstMaterialSpace(point, firstSeconds),
    ];
    var tested = 0, contacts = 0, intersections = 0;
    (int, int)? firstTouch, firstCross;
    var incomplete = false;

    void visit(
      _PairNode node, _Bounds3 movingBox,
      EggShellTriangle movingTriangle, int movingId,
    ) {
      if (incomplete || !node.bounds.overlaps(movingBox, tolerance)) {
        return;
      }
      final ids = node.ids;
      if (ids != null) {
        for (final id in ids) {
          if (!_firstBoxes[id].overlaps(movingBox, tolerance)) continue;
          if (tested >= maxPairs) {
            incomplete = true;
            return;
          }
          tested++;
          final fixed = _firstTriangles[id];
          final state = EggTriangleCollision.classify(
            _fixedPoints[fixed.a],
            _fixedPoints[fixed.b],
            _fixedPoints[fixed.c],
            localPoints[movingTriangle.a],
            localPoints[movingTriangle.b],
            localPoints[movingTriangle.c],
            tolerance: tolerance,
          );
          if (state == EggTriangleContact.touching) {
            contacts++;
            firstTouch ??= (id, movingId);
          } else if (state == EggTriangleContact.intersecting) {
            intersections++;
            firstCross ??= (id, movingId);
          }
        }
      } else {
        if (node.left != null) {
          visit(node.left!, movingBox, movingTriangle, movingId);
        }
        if (node.right != null) {
          visit(node.right!, movingBox, movingTriangle, movingId);
        }
      }
    }

    for (var i = 0; i < _secondTriangles.length; i++) {
      if (incomplete) break;
      final face = _secondTriangles[i];
      final box = _Bounds3.triangle(
        localPoints[face.a],
        localPoints[face.b],
        localPoints[face.c],
      );
      visit(_firstTree, box, face, i);
    }

    return EggPanelPairCollisionFrame(
      firstSeconds: firstSeconds,
      secondSeconds: secondSeconds,
      testedPairs: tested,
      touchingPairs: contacts,
      intersectingPairs: intersections,
      complete: !incomplete,
      firstTouchingTrianglePair: firstTouch,
      firstIntersectingTrianglePair: firstCross,
    );
  }
}
