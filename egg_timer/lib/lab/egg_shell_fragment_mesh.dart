import 'dart:math' as math;

import 'egg_fragment_regions.dart';
import 'egg_shell_model.dart';

/// Indices in a combined list: exterior first, inward face second.
class EggShellTriangle {
  const EggShellTriangle(this.a, this.b, this.c);
  final int a;
  final int b;
  final int c;
}

/// Geometry-only exterior patch shared by the V11.2 panel tessellator
/// and the new V11.4 stationary front-bowl tessellator.
class EggShellSurfacePatch {
  const EggShellSurfacePatch._(this.vertices, this.rim, this.triangles);
  final List<EggShellPoint3> vertices;
  final List<int> rim;
  final List<EggShellTriangle> triangles;
}

/// A real static 3D shell patch: outer face, inner face, and all side walls.
/// This is NOT yet removed from the original bowl or animated.
class EggShellPanelMesh {
  const EggShellPanelMesh._(
    this.regionId, this.thickness, this.outer, this.inner, this.rim,
    this.outerTriangles, this.innerTriangles, this.sideTriangles,
  );

  final String regionId;
  final double thickness;
  final List<EggShellPoint3> outer;
  final List<EggShellPoint3> inner;
  final List<int> rim;
  final List<EggShellTriangle> outerTriangles;
  final List<EggShellTriangle> innerTriangles;
  final List<EggShellTriangle> sideTriangles;

  int get vertexCount => outer.length * 2;
  int get triangleCount =>
      outerTriangles.length + innerTriangles.length + sideTriangles.length;
}

/// Pure geometry: derive two watertight candidate pieces from V11.1
/// material boundaries, without changing the drawing or F1.
///
/// The original crack samples ARE the initial rim vertices. Ear clipping
/// triangulates in x/y, and uniform shared-edge subdivision makes triangles
/// conform to EggShellModel.surfaceAt instead of spanning flat chords.
/// The side wall follows exactly the same subdivided rim: no T-junctions.
class EggShellPanelMeshBuilder {
  const EggShellPanelMeshBuilder._();

  static List<EggShellPanelMesh> build(
    EggFragmentRegionPlan plan, {
    double thickness = 2.5,
    double maxEdgeXY = 24,
    int? refinementPasses,
  }) {
    if (!thickness.isFinite || thickness <= 0) {
      throw ArgumentError.value(thickness, 'thickness');
    }
    if (!maxEdgeXY.isFinite || maxEdgeXY <= 0) {
      throw ArgumentError.value(maxEdgeXY, 'maxEdgeXY');
    }
    return List<EggShellPanelMesh>.unmodifiable([
      for (final region in plan.regions)
        _mesh(plan, region, thickness, maxEdgeXY, refinementPasses),
    ]);
  }

  static double _cross(EggShellPoint3 a, EggShellPoint3 b, EggShellPoint3 c) =>
      (b.x - a.x) * (c.y - a.y) -
      (b.y - a.y) * (c.x - a.x);

  static double _distance(EggShellPoint3 a, EggShellPoint3 b) =>
      math.sqrt((a.x - b.x) * (a.x - b.x) +
          (a.y - b.y) * (a.y - b.y));

  static bool _same(EggShellPoint3 a, EggShellPoint3 b) =>
      (a.x - b.x).abs() < 1e-7 &&
      (a.y - b.y).abs() < 1e-7 &&
      (a.z - b.z).abs() < 1e-7;

  /// Ear clipping of a positively oriented, simple x/y polygon.
  /// Inclusive point testing prevents omission of collinear rim vertices.
  static List<EggShellTriangle> _ears(List<EggShellPoint3> polygon) {
    final pending = List<int>.generate(polygon.length, (i) => i);
    final result = <EggShellTriangle>[];
    while (pending.length > 3) {
      var found = false;
      for (var i = 0; i < pending.length; i++) {
        final ia = pending[(i + pending.length - 1) % pending.length];
        final ib = pending[i], ic = pending[(i + 1) % pending.length];
        final a = polygon[ia], b = polygon[ib], c = polygon[ic];
        if (_cross(a, b, c) <= 1e-8) continue;
        var contains = false;
        for (final j in pending) {
          if (j == ia || j == ib || j == ic) continue;
          final p = polygon[j];
          if (_cross(a, b, p) >= -1e-8 &&
              _cross(b, c, p) >= -1e-8 &&
              _cross(c, a, p) >= -1e-8) {
            contains = true;
            break;
          }
        }
        if (contains) continue;
        result.add(EggShellTriangle(ia, ib, ic));
        pending.removeAt(i);
        found = true;
        break;
      }
      if (!found) {
        throw StateError('Untriangulable shell region: invalid rim geometry');
      }
    }
    if (_cross(polygon[pending[0]], polygon[pending[1]],
            polygon[pending[2]]) <= 1e-8) {
      throw StateError('Degenerate final shell triangle');
    }
    result.add(EggShellTriangle(pending[0], pending[1], pending[2]));
    return result;
  }

  /// Triangulates the *actual* sampled 3D shell boundary; every inserted
  /// vertex is projected to the shared EggShellModel curved surface.
  static EggShellSurfacePatch tessellateExterior({
    required EggShellModel model,
    required List<EggShellPoint3> closedPerimeter,
    double maxEdgeXY = 24,
    int? refinementPasses,
  }) {
    if (refinementPasses != null &&
        (refinementPasses < 0 || refinementPasses > 5)) {
      throw ArgumentError.value(refinementPasses, 'refinementPasses');
    }
    if (!maxEdgeXY.isFinite || maxEdgeXY <= 0) {
      throw ArgumentError.value(maxEdgeXY, 'maxEdgeXY');
    }
    final sampled = closedPerimeter;
    if (sampled.length < 4 || !_same(sampled.first, sampled.last)) {
      throw StateError('Unclosed original shell perimeter');
    }
    final points = List<EggShellPoint3>.of(sampled)..removeLast();
    final originalSize = points.length;
    var signedArea = 0.0;
    for (var i = 0; i < originalSize; i++) {
      final a = points[i], b = points[(i + 1) % originalSize];
      signedArea += a.x * b.y - b.x * a.y;
    }
    if (signedArea.abs() <= 1e-7) {
      throw StateError('Zero-area shell region');
    }
    if (signedArea < 0) {
      points.setAll(0, points.reversed.toList());
    }

    var triangles = _ears(points);
    final rimNext = <int, int>{
      for (var i = 0; i < originalSize; i++)
        i: (i + 1) % originalSize,
    };
    var maxLength = 0.0;
    for (final t in triangles) {
      final a = points[t.a], b = points[t.b], c = points[t.c];
      maxLength = math.max(maxLength, math.max(_distance(a, b),
          math.max(_distance(b, c), _distance(c, a))));
    }
    var refinements = 0;
    while (maxLength > maxEdgeXY && refinements < 5) {
      refinements++;
      maxLength /= 2;
    }
    if (maxLength > maxEdgeXY) {
      throw StateError('Too large a triangle for bounded subdivision');
    }

    // Common material boundaries must share the same midpoint count.
    // Standalone tessellation keeps its original adaptive refinement.
    final passes = refinementPasses ?? refinements;
    for (var pass = 0; pass < passes; pass++) {
      final sharedMidpoints = <String, int>{};
      int midpoint(int a, int b) {
        final lo = math.min(a, b), hi = math.max(a, b);
        final key = '$lo:$hi';
        final cached = sharedMidpoints[key];
        if (cached != null) return cached;
        final pa = points[a], pb = points[b];
        final id = points.length;
        points.add(model.surfaceAt(
          (pa.x + pb.x) / 2, (pa.y + pb.y) / 2,
        ));
        sharedMidpoints[key] = id;
        if (rimNext[a] == b) {
          rimNext[a] = id;
          rimNext[id] = b;
        } else if (rimNext[b] == a) {
          rimNext[b] = id;
          rimNext[id] = a;
        }
        return id;
      }

      final nextTriangles = <EggShellTriangle>[];
      for (final t in triangles) {
        final ab = midpoint(t.a, t.b);
        final bc = midpoint(t.b, t.c);
        final ca = midpoint(t.c, t.a);
        nextTriangles.addAll([
          EggShellTriangle(t.a, ab, ca),
          EggShellTriangle(ab, t.b, bc),
          EggShellTriangle(ca, bc, t.c),
          EggShellTriangle(ab, bc, ca),
        ]);
      }
      triangles = nextTriangles;
    }

    final rim = <int>[];
    var current = 0;
    do {
      rim.add(current);
      final next = rimNext[current];
      if (next == null || rim.length > points.length) {
        throw StateError('Invalid refined shell rim');
      }
      current = next;
    } while (current != 0);
    if (rim.length != rimNext.length) {
      throw StateError('Disconnected rim edges');
    }


    return EggShellSurfacePatch._(
      List<EggShellPoint3>.unmodifiable(points),
      List<int>.unmodifiable(rim),
      List<EggShellTriangle>.unmodifiable(triangles),
    );
  }

  static EggShellPanelMesh _mesh(
    EggFragmentRegionPlan plan,
    EggCandidateShellRegion region,
    double thickness,
    double maxEdgeXY,
    int? refinementPasses,
  ) {
    final model = plan.network.model;
    final patch = tessellateExterior(
      model: model,
      closedPerimeter: region.sampledPerimeter(plan.network),
      maxEdgeXY: maxEdgeXY,
      refinementPasses: refinementPasses,
    );
    final points = patch.vertices;
    final triangles = patch.triangles;
    final rim = patch.rim;
    final inside = <EggShellPoint3>[
      for (final point in points) model.inset(point, thickness),
    ];
    final shift = points.length;
    final innerFaces = <EggShellTriangle>[
      for (final t in triangles)
        EggShellTriangle(t.a + shift, t.c + shift, t.b + shift),
    ];
    final walls = <EggShellTriangle>[];
    for (var i = 0; i < rim.length; i++) {
      final a = rim[i], b = rim[(i + 1) % rim.length];
      walls.add(EggShellTriangle(b, a, a + shift));
      walls.add(EggShellTriangle(b, a + shift, b + shift));
    }
    return EggShellPanelMesh._(
      region.id, thickness,
      List<EggShellPoint3>.unmodifiable(points),
      List<EggShellPoint3>.unmodifiable(inside),
      List<int>.unmodifiable(rim),
      List<EggShellTriangle>.unmodifiable(triangles),
      List<EggShellTriangle>.unmodifiable(innerFaces),
      List<EggShellTriangle>.unmodifiable(walls),
    );
  }
}
