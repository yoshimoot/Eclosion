import 'dart:math' as math;

import 'egg_full_bowl_mesh.dart';
import 'egg_panel_release_motion.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

/// Pairwise 3D triangle classification (not a 2D screen overlap test).
///
/// The separating-axis checks include both triangle normals, the nine edge
/// cross-products and the in-plane axes needed for coplanar triangles.
/// A point or edge contact is reported separately from a transverse overlap.
/// Numerical tolerance is in ORIGINAL EggShellModel units.
enum EggTriangleContact { separated, touching, intersecting }

class EggTriangleCollision {
  const EggTriangleCollision._();

  static EggShellPoint3 _cross(EggShellPoint3 a, EggShellPoint3 b) =>
      EggShellPoint3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x,
      );

  static double _dot(EggShellPoint3 a, EggShellPoint3 b) =>
      a.x * b.x + a.y * b.y + a.z * b.z;

  /// True only when a segment crosses the opposing triangle's PLANE
  /// and the crossing lies strictly inside its material face. Boundary
  /// touches and coplanar intersections are not volume penetrations.
  static bool _pierces(
    List<EggShellPoint3> moving,
    List<EggShellPoint3> fixed,
    EggShellPoint3 fixedNormal,
    double tolerance,
  ) {
    final planeScale = fixedNormal.length;
    final base = fixed[0];
    final ab = fixed[1] - base;
    final ac = fixed[2] - base;
    final d00 = _dot(ab, ab);
    final d01 = _dot(ab, ac);
    final d11 = _dot(ac, ac);
    final determinant = d00 * d11 - d01 * d01;
    if (determinant <= 1e-20) {
      throw StateError('Degenerate collision target triangle');
    }
    for (var i = 0; i < 3; i++) {
      final from = moving[i];
      final to = moving[(i + 1) % 3];
      final start = _dot(from - base, fixedNormal) / planeScale;
      final end = _dot(to - base, fixedNormal) / planeScale;
      final straddles = (start < -tolerance && end > tolerance) ||
          (start > tolerance && end < -tolerance);
      if (!straddles) continue;
      final fraction = start / (start - end);
      final point = from + (to - from) * fraction;
      final ap = point - base;
      final d20 = _dot(ap, ab), d21 = _dot(ap, ac);
      final u = (d11 * d20 - d01 * d21) / determinant;
      final v = (d00 * d21 - d01 * d20) / determinant;
      final minBarycentric = 1e-9;
      if (u > minBarycentric && v > minBarycentric &&
          u + v < 1 - minBarycentric) {
        return true;
      }
    }
    return false;
  }

  static EggTriangleContact classify(
    EggShellPoint3 a0,
    EggShellPoint3 a1,
    EggShellPoint3 a2,
    EggShellPoint3 b0,
    EggShellPoint3 b1,
    EggShellPoint3 b2, {
    double tolerance = 1e-7,
  }) {
    if (!tolerance.isFinite || tolerance < 0) {
      throw ArgumentError.value(tolerance, 'tolerance');
    }
    final a = <EggShellPoint3>[a0, a1, a2];
    final b = <EggShellPoint3>[b0, b1, b2];
    for (final point in [...a, ...b]) {
      if (!point.x.isFinite || !point.y.isFinite || !point.z.isFinite) {
        throw ArgumentError('Triangle vertices must be finite');
      }
    }
    final ea = [a1 - a0, a2 - a1, a0 - a2];
    final eb = [b1 - b0, b2 - b1, b0 - b2];
    final na = _cross(ea[0], ea[1]);
    final nb = _cross(eb[0], eb[1]);
    if (na.length < 1e-12 || nb.length < 1e-12) {
      throw StateError('Degenerate triangle in collision diagnostic');
    }

    final axes = <EggShellPoint3>[
      na, nb,
      for (final x in ea) _cross(na, x),
      for (final y in eb) _cross(nb, y),
      for (final x in ea)
        for (final y in eb) _cross(x, y),
    ];
    for (final candidate in axes) {
      final length = candidate.length;
      if (length < 1e-10) continue;
      final unit = candidate * (1 / length);
      final av = a.map((p) => _dot(p, unit)).toList();
      final bv = b.map((p) => _dot(p, unit)).toList();
      final aMin = av.reduce(math.min), aMax = av.reduce(math.max);
      final bMin = bv.reduce(math.min), bMax = bv.reduce(math.max);
      final overlap = math.min(aMax, bMax) - math.max(aMin, bMin);
      if (overlap < -tolerance) return EggTriangleContact.separated;
    }
    // Planar triangles have zero extent along their OWN face normals.
    // SAT can reject disjoint pairs, but its overlap depth CANNOT classify
    // contact versus transversal crossing. Test plane crossings explicitly.
    if (_pierces(a, b, nb, tolerance) ||
        _pierces(b, a, na, tolerance)) {
      return EggTriangleContact.intersecting;
    }
    return EggTriangleContact.touching;
  }
}

class _Box3 {
  const _Box3(this.minX, this.maxX, this.minY, this.maxY, this.minZ, this.maxZ);
  final double minX, maxX, minY, maxY, minZ, maxZ;

  factory _Box3.fromTriangle(
    EggShellPoint3 a, EggShellPoint3 b, EggShellPoint3 c,
  ) => _Box3(
    math.min(a.x, math.min(b.x, c.x)),
    math.max(a.x, math.max(b.x, c.x)),
    math.min(a.y, math.min(b.y, c.y)),
    math.max(a.y, math.max(b.y, c.y)),
    math.min(a.z, math.min(b.z, c.z)),
    math.max(a.z, math.max(b.z, c.z)),
  );

  factory _Box3.enclosing(List<_Box3> boxes, List<int> indices) {
    var minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    var maxZ = double.negativeInfinity;
    for (final id in indices) {
      final b = boxes[id];
      minX = math.min(minX, b.minX);
      minY = math.min(minY, b.minY);
      minZ = math.min(minZ, b.minZ);
      maxX = math.max(maxX, b.maxX);
      maxY = math.max(maxY, b.maxY);
      maxZ = math.max(maxZ, b.maxZ);
    }
    return _Box3(minX, maxX, minY, maxY, minZ, maxZ);
  }

  double center(int axis) => switch (axis) {
    0 => (minX + maxX) * .5,
    1 => (minY + maxY) * .5,
    _ => (minZ + maxZ) * .5,
  };

  bool overlaps(_Box3 b, double padding) =>
      minX <= b.maxX + padding && maxX >= b.minX - padding &&
      minY <= b.maxY + padding && maxY >= b.minY - padding &&
      minZ <= b.maxZ + padding && maxZ >= b.minZ - padding;
}

class _Node {
  const _Node(this.bounds, this.triangles, this.left, this.right);
  final _Box3 bounds;
  final List<int>? triangles;
  final _Node? left, right;
}

/// Results apply to ONE sampled time only. Even when [complete] is true,
/// clear frames do NOT prove the absence of collisions BETWEEN time samples.
class EggBowlCollisionFrame {
  const EggBowlCollisionFrame({
    required this.seconds,
    required this.testedPairs,
    required this.touchingPairs,
    required this.intersectingPairs,
    required this.complete,
    required this.firstTouchingBowlTriangle,
    required this.firstIntersectingBowlTriangle,
  });

  final double seconds;
  final int testedPairs, touchingPairs, intersectingPairs;
  final bool complete;
  final int? firstTouchingBowlTriangle;
  final int? firstIntersectingBowlTriangle;

  bool get hasContact => touchingPairs > 0 || intersectingPairs > 0;
  bool get hasIntersection => intersectingPairs > 0;
  bool get sampledFrameClear => complete && !hasContact;
}

/// Static bowl BVH + moving panel triangle soup. Construct once and query
/// a few selected release times; do NOT rebuild static indexes per frame.
///
/// This is a diagnostic, not collision response, continuous collision
/// detection, or validated avoidance dynamics.
class EggBowlCollisionInspector {
  EggBowlCollisionInspector({
    required EggFullBowlMesh bowl,
    required EggShellPanelMesh panel,
    required EggPanelReleaseMotion motion,
    this.tolerance = 1e-7,
  }) : _panel = panel, _motion = motion,
       _fixedVertices = List<EggShellPoint3>.unmodifiable([
         ...bowl.outer, ...bowl.inner,
       ]),
       _fixedFaces = List<EggShellTriangle>.unmodifiable(
         bowl.allFaces,
       ) {
    if (!tolerance.isFinite || tolerance < 0) {
      throw ArgumentError.value(tolerance, 'tolerance');
    }
    if (!panel.outer.any((p) => identical(p, motion.hinge.anchorA)) ||
        !panel.outer.any((p) => identical(p, motion.hinge.anchorB))) {
      throw StateError('Release motion is not based on this panel');
    }
    _staticBoxes = List<_Box3>.generate(_fixedFaces.length, (i) {
      final t = _fixedFaces[i];
      return _Box3.fromTriangle(
        _fixedVertices[t.a], _fixedVertices[t.b], _fixedVertices[t.c],
      );
    });
    if (_staticBoxes.isEmpty) {
      throw StateError('Stationary collision mesh is empty');
    }
    _tree = _buildTree(List<int>.generate(_staticBoxes.length, (i) => i));
    _movingFaces = List<EggShellTriangle>.unmodifiable([
      ...panel.outerTriangles,
      ...panel.innerTriangles,
      ...panel.sideTriangles,
    ]);
  }

  final EggShellPanelMesh _panel;
  final EggPanelReleaseMotion _motion;
  final List<EggShellPoint3> _fixedVertices;
  final List<EggShellTriangle> _fixedFaces;
  final double tolerance;
  late final List<_Box3> _staticBoxes;
  late final List<EggShellTriangle> _movingFaces;
  late final _Node _tree;

  _Node _buildTree(List<int> indices) {
    final bounds = _Box3.enclosing(_staticBoxes, indices);
    if (indices.length <= 8) {
      return _Node(bounds, List<int>.unmodifiable(indices), null, null);
    }
    final spans = [
      bounds.maxX - bounds.minX,
      bounds.maxY - bounds.minY,
      bounds.maxZ - bounds.minZ,
    ];
    final axis = spans.indexOf(spans.reduce(math.max));
    indices.sort((a, b) =>
        _staticBoxes[a].center(axis).compareTo(
          _staticBoxes[b].center(axis),
        ));
    final mid = indices.length ~/ 2;
    return _Node(bounds, null,
        _buildTree(indices.sublist(0, mid)),
        _buildTree(indices.sublist(mid)));
  }

  /// Index and triangle soup are immutable. The only variable is seconds.
  ///
  /// If [maxPairs] is reached, [EggBowlCollisionFrame.complete] is false;
  /// the result MUST NOT be interpreted as certified clearance.
  EggBowlCollisionFrame inspect(double seconds, {int maxPairs = 50000}) {
    if (!seconds.isFinite || seconds < 0 || seconds > 2) {
      throw ArgumentError.value(seconds, 'seconds');
    }
    if (maxPairs <= 0) {
      throw ArgumentError.value(maxPairs, 'maxPairs');
    }
    final outside = _motion.transformAll(_panel.outer, seconds);
    final inside = _motion.transformAll(_panel.inner, seconds);
    final vertices = <EggShellPoint3>[...outside, ...inside];
    var checked = 0, touches = 0, crossings = 0;
    int? firstTouch, firstCross;
    var stopped = false;

    void inspectNode(_Node node, _Box3 moving, EggShellTriangle triangle) {
      if (stopped || !node.bounds.overlaps(moving, tolerance)) return;
      final childIds = node.triangles;
      if (childIds != null) {
        for (final i in childIds) {
          if (!_staticBoxes[i].overlaps(moving, tolerance)) continue;
          if (checked >= maxPairs) {
            stopped = true;
            return;
          }
          checked++;
          final fixed = _fixedFaces[i];
          final contact = EggTriangleCollision.classify(
            vertices[triangle.a], vertices[triangle.b],
            vertices[triangle.c],
            _fixedVertices[fixed.a], _fixedVertices[fixed.b],
            _fixedVertices[fixed.c],
            tolerance: tolerance,
          );
          if (contact == EggTriangleContact.touching) {
            touches++;
            firstTouch ??= i;
          } else if (contact == EggTriangleContact.intersecting) {
            crossings++;
            firstCross ??= i;
          }
        }
      } else {
        if (node.left != null) inspectNode(node.left!, moving, triangle);
        if (node.right != null) inspectNode(node.right!, moving, triangle);
      }
    }

    for (final face in _movingFaces) {
      if (stopped) break;
      final bounds = _Box3.fromTriangle(
        vertices[face.a], vertices[face.b], vertices[face.c],
      );
      inspectNode(_tree, bounds, face);
    }
    return EggBowlCollisionFrame(
      seconds: seconds,
      testedPairs: checked,
      touchingPairs: touches,
      intersectingPairs: crossings,
      complete: !stopped,
      firstTouchingBowlTriangle: firstTouch,
      firstIntersectingBowlTriangle: firstCross,
    );
  }
}
