import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'fragment_surface_probe.dart';
export 'fragment_surface_probe.dart' show FragmentSurfaceColors;

const double _eggHalfWidth = 128;
const double _eggHalfHeight = 220;
const double _eggDepth = 65;

// Boolean operations produce non-overlapping contours, potentially with holes.
// CanvasKit can reset Skia's even-odd result to the FIRST operand's winding
// rule. Explicit parity preserves those holes independently of contour winding:
// shell = egg - aperture; occluded = behind intersect shell; visible = !occluded.
// The injectable operation lets native tests exercise that Web backend contract.
@visibleForTesting
Path combineFragmentOcclusionPaths(
  PathOperation operation,
  Path a,
  Path b, {
  Path Function(PathOperation, Path, Path)? combine,
}) =>
    (combine ?? Path.combine)(operation, a, b)..fillType = PathFillType.evenOdd;

double _part(double t, double start, double end) =>
    ((t - start) / (end - start)).clamp(0.0, 1.0);
double _smooth(double t) => t * t * (3 - 2 * t);
double _smoother(double t) => t * t * t * (t * (t * 6 - 15) + 10);

double _pulse(double t, double center, double halfWidth) {
  final distance = ((t - center) / halfWidth).abs();
  return distance >= 1 ? 0 : _smooth(1 - distance);
}

class _PressureEvent {
  const _PressureEvent(
    this.center,
    this.halfWidth,
    this.strength,
    this.point, {
    this.radius = 65,
  });

  final double center, halfWidth, strength, radius;
  final Offset point;
  double at(double t) => strength * _pulse(t, center, halfWidth);
  double advance(double t) => _part(t, center - halfWidth, center + halfWidth);
}

class _ChickContactEpisode {
  const _ChickContactEpisode({
    required this.start,
    required this.peak,
    required this.end,
    required this.startPoint,
    required this.peakPoint,
    required this.endPoint,
    required this.startRadius,
    required this.peakRadius,
    required this.endRadius,
    required this.strength,
  });

  final double start, peak, end, strength;
  final Offset startPoint, peakPoint, endPoint;
  final double startRadius, peakRadius, endRadius;

  double envelope(double t) {
    if (t <= start || t >= end) return 0;
    return t < peak
        ? _smoother(_part(t, start, peak))
        : 1 - _smoother(_part(t, peak, end));
  }

  Offset pointAt(double t) {
    if (t <= peak) {
      final u = _smoother(_part(t, start, peak));
      return Offset.lerp(startPoint, peakPoint, u)!;
    }
    final u = _smoother(_part(t, peak, end));
    return Offset.lerp(peakPoint, endPoint, u)!;
  }

  double radiusAt(double t) {
    if (t <= peak) {
      final u = _smoother(_part(t, start, peak));
      return startRadius + (peakRadius - startRadius) * u;
    }
    final u = _smoother(_part(t, peak, end));
    return peakRadius + (endRadius - peakRadius) * u;
  }
}

class _CrackAdvance {
  const _CrackAdvance(this.pressure, this.start, this.end);
  final int pressure;
  final double start, end;
  double at(double t, List<_PressureEvent> events) =>
      _smooth(_part(events[pressure].advance(t), start, end));
}

class _LiftPush {
  const _LiftPush(this.start, this.end, this.amount, this.point);
  final double start, end, amount;
  final Offset point;
  double at(double t) => amount * _smooth(_part(t, start, end));
}

class _ShellAttachment {
  const _ShellAttachment(
    this.vertex,
    this.releaseStart,
    this.releaseEnd,
    this.scarEnd, {
    this.damageStart,
    this.damageEnd,
  });

  final int vertex;
  final double releaseStart, releaseEnd;
  final Offset scarEnd;
  final double? damageStart, damageEnd;

  double hold(double t, {double? damage}) {
    if (damageStart != null && damageEnd != null) {
      assert(damage != null);
      return 1 - _smooth(_part(damage!, damageStart!, damageEnd!));
    }
    return 1 - _smooth(_part(t, releaseStart, releaseEnd));
  }
}

class _BodyEpisode {
  const _BodyEpisode(this.start, this.peak, this.end, this.tilt, this.rise);
  final double start, peak, end, tilt, rise;

  double weight(double t) {
    if (t <= start || t >= end) return 0;
    return t < peak
        ? _smoother(_part(t, start, peak))
        : 1 - _smoother(_part(t, peak, end));
  }
}

String fragmentPhase(double t) => t < .25
    ? 'P1 · mouvements internes'
    : t < .50
    ? 'P2 · bec / premières fissures'
    : t < .75
    ? 'P3 · tête-front / propagation'
    : t < .95
    ? 'P4 · pression étendue / fragilisation'
    : t < 1
    ? 'Ouverture / détachement'
    : 'Éclosion';

class _V {
  const _V(this.x, this.y, this.z);
  final double x, y, z;
  _V operator +(_V b) => _V(x + b.x, y + b.y, z + b.z);
  _V operator -(_V b) => _V(x - b.x, y - b.y, z - b.z);
  _V rotate(double pitch, double yaw, double roll) {
    final yy = y * math.cos(pitch) - z * math.sin(pitch);
    final zz = y * math.sin(pitch) + z * math.cos(pitch);
    final xx = x * math.cos(yaw) + zz * math.sin(yaw);
    return _V(
      xx * math.cos(roll) - yy * math.sin(roll),
      xx * math.sin(roll) + yy * math.cos(roll),
      -x * math.sin(yaw) + zz * math.cos(yaw),
    );
  }

  static _V lerp(_V a, _V b, double t) =>
      _V(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t);
  Offset get xy => Offset(x, y);
}

class _Face {
  _Face(
    this.vertices,
    this.color, {
    this.shader,
    this.shade = 0,
    this.highlight = 0,
  });
  final List<_V> vertices;
  final Color color;
  final Shader? shader;
  final double shade, highlight;
  double get depth => vertices.fold(0.0, (s, v) => s + v.z) / vertices.length;
  double get screenArea {
    var area = 0.0;
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      area += a.x * b.y - b.x * a.y;
    }
    return area;
  }
}

double _diffuse(List<_V> vertices) {
  final a = vertices[0];
  final b = vertices[1];
  final c = vertices[2];
  final ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z;
  final vx = c.x - a.x, vy = c.y - a.y, vz = c.z - a.z;
  final nx = uy * vz - uz * vy;
  final ny = uz * vx - ux * vz;
  final nz = ux * vy - uy * vx;
  final length = math.sqrt(nx * nx + ny * ny + nz * nz);
  if (length == 0) return 0;
  return ((-.35 * nx - .45 * ny + .82 * nz) / length).clamp(0.0, 1.0);
}

Path _polygon(Iterable<Offset> points) =>
    Path()..addPolygon(points.toList(), true);

/// Numeric view of the exact geometry used by the painter (egg-local units).
@visibleForTesting
class FragmentGeometrySnapshot {
  const FragmentGeometrySnapshot(
    this.material,
    this.positions,
    this.retention,
    this.holds,
    this.rigid,
    this.minimumAreaRatio,
    this.innerPositions,
  );
  final List<(double, double, double)> material, positions, rigid;
  final List<double> retention, holds;
  final double minimumAreaRatio;
  final List<(double, double, double)> innerPositions;
}

@visibleForTesting
class FragmentFlightSnapshot {
  const FragmentFlightSnapshot(
    this.geometry,
    this.flight,
    this.lift,
    this.shift,
    this.rotation,
    this.detachmentProgress,
    this.shellNormal,
  );

  final FragmentGeometrySnapshot geometry;
  final double flight, lift, detachmentProgress;
  final (double, double, double) shift, rotation, shellNormal;
}

/// Captured from paint itself, so browser diagnostics describe the displayed
/// frame rather than a separately reconstructed timeline or opening.
class FragmentPaintDiagnostics {
  FragmentPaintDiagnostics(
    this.progress,
    Path opening,
    Path footprint,
    this.lift,
    this.maxBorderGap,
    this.holds,
    this.size,
  ) : opening = Path.from(opening),
      footprint = Path.from(footprint);
  final double progress, lift, maxBorderGap;
  final Path opening, footprint;
  final List<double> holds;
  final Size size;
  final List<Path> occludingFaces = [];
  Path? fragmentVisibility;
  final Map<String, double> surfaces = {};
  final fixedLipFaces = <List<(double, double, double)>>[];
  Map<String, double> Function()? meshSummary;
  FragmentSurfaceProbe? probe;

  // Evaluate on demand: these are the faces that paint actually accepted,
  // with the same depth clip. No color classification is needed.
  bool interiorVisibleAt(Offset point) =>
      opening.contains(point) &&
      (!(fragmentVisibility?.contains(point) ?? true) ||
          !occludingFaces.any((face) => face.contains(point)));

  // Diagnostic only, evaluated on demand by the copy button, never per frame.
  Map<String, Object> toMap() {
    final bounds = footprint.getBounds();
    var covered = 0, total = 0;
    var visible = 0;
    const step = .25;
    for (var y = bounds.top + step / 2; y < bounds.bottom; y += step) {
      for (var x = bounds.left + step / 2; x < bounds.right; x += step) {
        final point = Offset(x, y);
        if (footprint.contains(point)) total++;
        if (opening.contains(point)) covered++;
        if (interiorVisibleAt(point)) visible++;
      }
    }
    return {
      'diagnostic': 'surface-paint-v4',
      'paintedProgress': progress,
      'openingAreaSampled': covered * step * step,
      'visibleInteriorAreaSampled': visible * step * step,
      'footprintAreaSampled': total * step * step,
      'sampleStep': step,
      'lift': lift,
      'maxBorderGap': maxBorderGap,
      'holds': holds,
      'canvasWidth': size.width,
      'canvasHeight': size.height,
      'surfaces': {...surfaces, ...?meshSummary?.call()},
    };
  }
}

class _MaterialMesh {
  _MaterialMesh(List<_V> outer, _V center) {
    for (var ring = 0; ring < 10; ring++) {
      for (var i = 0; i < outer.length; i++) {
        final j = (i + 1) % outer.length;
        final a = _V.lerp(center, outer[i], ring / 10);
        final b = _V.lerp(center, outer[i], (ring + 1) / 10);
        final c = _V.lerp(center, outer[j], (ring + 1) / 10);
        final d = _V.lerp(center, outer[j], ring / 10);
        triangles.addAll([
          a,
          b,
          c,
          if (ring > 0) ...[a, c, d],
        ]);
      }
    }
    final ids = <(double, double, double), int>{};
    for (final v in triangles) {
      indices.add(
        ids.putIfAbsent((v.x, v.y, v.z), () {
          vertices.add(v);
          return vertices.length - 1;
        }),
      );
    }

    for (var i = 0; i < outer.length; i++) {
      final a = outer[i].xy, b = outer[(i + 1) % outer.length].xy;
      final farA = center.xy + (a - center.xy) * 20;
      final farB = center.xy + (b - center.xy) * 20;
      shellMesh.addAll([a, farA, farB, a, farB, b]);
    }
  }

  final triangles = <_V>[];
  final vertices = <_V>[];
  final indices = <int>[];
  final shellMesh = <Offset>[];
  late final textureCoordinates = vertices.map((v) => v.xy).toList();
  final _bindings = <Offset, (int, double, double)?>{};
  final _cavityMeshes = <(double, bool), ui.Vertices>{};

  // The far INNER wall belongs to the resting egg, never to the mobile pose.
  // Project its concave ellipsoid onto the same material tessellation. Normals
  // point into the cavity; lighting uses the existing upper-left scene light.
  // Prepare once per thickness/mode, not once per animation frame.
  ui.Vertices cavityMesh(
    double thickness,
    bool identify,
  ) => _cavityMeshes.putIfAbsent((thickness, identify), () {
    final rx = _eggHalfWidth - thickness,
        ry = _eggHalfHeight - thickness,
        rz = _eggDepth - thickness;

    // Build one GLOBAL inner-wall mesh for the egg. It is completely
    // independent of fragment geometry: openings only clip/reveal it.
    // A mild perspective projection lets the real concave z coordinate
    // affect screen position, so depth is carried by geometry as well as
    // by shading. Future fragments therefore reveal the same continuous
    // interior surface.
    const columns = 28;
    const rows = 44;
    const cameraDistance = 900.0;
    final positions = <Offset>[];
    final colors = <Color>[];
    final cavityIndices = <int>[];

    for (var row = 0; row <= rows; row++) {
      final y = -ry + (2 * ry * row / rows);
      for (var column = 0; column <= columns; column++) {
        final x = -rx + (2 * rx * column / columns);
        final radialSquared = x * x / (rx * rx) + y * y / (ry * ry);
        final inside = radialSquared <= 1.0;
        final z = inside
            ? -rz * math.sqrt(math.max(0.0, 1 - radialSquared))
            : 0.0;

        final perspective = cameraDistance / (cameraDistance - z);
        positions.add(Offset(x * perspective, y * perspective));

        if (!inside) {
          colors.add(
            identify ? FragmentSurfaceColors.cavity : const Color(0xff9b7060),
          );
          continue;
        }

        final nx = -x / (rx * rx), ny = -y / (ry * ry), nz = -z / (rz * rz);
        final normalLength = math.sqrt(nx * nx + ny * ny + nz * nz);
        final diffuse = ((-.35 * nx - .45 * ny + .82 * nz) / normalLength)
            .clamp(0.0, 1.0);

        // Optical depth through the hollow egg: at this screen point,
        // the ray travels from the front inner shell to the rear inner
        // wall. That chord length is a GLOBAL property of the egg and is
        // independent of every fragment/opening. Longer travel means less
        // light reaches the far wall; nearer side regions remain lighter.
        final opticalDepth = (-z / rz).clamp(0.0, 1.0);
        final sideExposure = math.pow((1 - opticalDepth).clamp(0.0, 1.0), .22);
        final directionalRelief = .035 * (diffuse - .5);
        final exposure =
            (.22 + .46 * sideExposure - .08 * opticalDepth + directionalRelief)
                .clamp(.20, .56);

        final innerShell = Color.lerp(
          const Color(0xff9b7060),
          const Color(0xfff0d8c0),
          exposure,
        )!;
        colors.add(identify ? FragmentSurfaceColors.cavity : innerShell);
      }
    }

    final stride = columns + 1;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final a = row * stride + column;
        final b = a + 1;
        final c = a + stride;
        final d = c + 1;
        cavityIndices.addAll([a, c, b, b, c, d]);
      }
    }

    return ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      colors: colors,
      indices: cavityIndices,
    );
  });

  // Grain-to-material coordinates never depend on the pose.
  (int, double, double)? bind(Offset point) => _bindings.putIfAbsent(point, () {
    for (var i = 0; i < indices.length; i += 3) {
      final a = vertices[indices[i]],
          b = vertices[indices[i + 1]],
          c = vertices[indices[i + 2]];
      final ab = b.xy - a.xy, ac = c.xy - a.xy, ap = point - a.xy;
      final determinant = ab.dx * ac.dy - ab.dy * ac.dx;
      if (determinant.abs() < 1e-10) continue;
      final u = (ap.dx * ac.dy - ap.dy * ac.dx) / determinant;
      final v = (ab.dx * ap.dy - ab.dy * ap.dx) / determinant;
      if (u < -1e-8 || v < -1e-8 || u + v > 1 + 1e-8) continue;
      return (i, u, v);
    }
    return null;
  });
}

class _FragmentGeometry {
  _FragmentGeometry({
    required this.outer,
    required this.projectedOuter,
    required this.projectedInner,
    required this.center,
    required this.transform,
    required this.rigidTransform,
    required this.flight,
    required this.shift,
    required this.rotation,
    required this.bounce,
    required this.lift,
  }) : material = _materials[outer] ??= _MaterialMesh(outer, center);

  // The immutable boundary is shared across frames; the pose is not cached.
  static final _materials = Expando<_MaterialMesh>();
  final _MaterialMesh material;
  final List<_V> outer, projectedOuter, projectedInner;
  final _V center, shift, rotation;
  final _V Function(_V) transform, rigidTransform;
  final double flight, bounce, lift;
  List<_V> get mesh => material.triangles;
  List<Offset> get shellMesh => material.shellMesh;
  late final projectedVertices = material.vertices.map(transform).toList();
  late final projectedPositions = projectedVertices.map((v) => v.xy).toList();

  List<double> occlusionDepths(_V Function(Offset) surface) => [
    // The resting mesh interpolates curved material with planar triangles.
    // Its interpolation error is not penetration into the remaining shell.
    // Compare changes from that SAME material reference on both sides: at
    // identity the two differences are exactly zero, at every mesh vertex.
    for (var i = 0; i < projectedVertices.length; i++)
      (projectedVertices[i].z - material.vertices[i].z) -
          (surface(projectedVertices[i].xy).z -
              surface(material.vertices[i].xy).z),
  ];

  _V materialPoint(Offset point) {
    final binding = material.bind(point);
    if (binding == null) return transform(center);
    final (i, u, v) = binding;
    final a = material.vertices[material.indices[i]];
    final b = material.vertices[material.indices[i + 1]];
    final c = material.vertices[material.indices[i + 2]];
    final da = projectedVertices[material.indices[i]] - a;
    final db = projectedVertices[material.indices[i + 1]] - b;
    final dc = projectedVertices[material.indices[i + 2]] - c;
    // Interpolate displacement, not absolute coordinates. A resting grain
    // point must retain exactly the same coordinates as on the fixed shell.
    return _V(
      point.dx + da.x + u * (db.x - da.x) + v * (dc.x - da.x),
      point.dy + da.y + u * (db.y - da.y) + v * (dc.y - da.y),
      a.z +
          u * (b.z - a.z) +
          v * (c.z - a.z) +
          da.z +
          u * (db.z - da.z) +
          v * (dc.z - da.z),
    );
  }

  // Same per-triangle depth clipping as before. Cancel shared directed edges
  // before Path.combine: internal tessellation is not an occlusion boundary.
  Path visibility(Path shell, _V Function(Offset) surface) {
    final points = [...projectedVertices];
    final depths = occlusionDepths(surface);
    final crossings = <(int, int), int>{};
    final edges = <(int, int), (int, int)>{};
    (int, int) key(int a, int b) => a < b ? (a, b) : (b, a);
    int crossing(int a, int b) {
      final pair = key(a, b);
      return crossings.putIfAbsent(pair, () {
        final (first, second) = pair;
        points.add(
          _V.lerp(
            points[first],
            points[second],
            depths[first] / (depths[first] - depths[second]),
          ),
        );
        return points.length - 1;
      });
    }

    for (var i = 0; i < material.indices.length; i += 3) {
      final triangle = material.indices.sublist(i, i + 3);
      final clipped = <int>[];
      for (var j = 0; j < 3; j++) {
        final a = triangle[j], b = triangle[(j + 1) % 3];
        if (depths[a] < 0) clipped.add(a);
        if ((depths[a] < 0) != (depths[b] < 0)) clipped.add(crossing(a, b));
      }
      for (var j = 0; j < clipped.length; j++) {
        final a = clipped[j], b = clipped[(j + 1) % clipped.length];
        if (a == b) continue;
        final pair = key(a, b);
        if (edges.containsKey(pair)) {
          edges.remove(pair);
        } else {
          edges[pair] = (a, b);
        }
      }
    }
    final next = <int, List<int>>{};
    for (final (a, b) in edges.values) {
      (next[a] ??= []).add(b);
    }
    final behind = Path();
    while (next.isNotEmpty) {
      final start = next.keys.first;
      var current = start;
      behind.moveTo(points[start].x, points[start].y);
      do {
        final outgoing = next[current]!;
        final end = outgoing.removeLast();
        if (outgoing.isEmpty) next.remove(current);
        behind.lineTo(points[end].x, points[end].y);
        current = end;
      } while (current != start);
      behind.close();
    }
    final occluded = combineFragmentOcclusionPaths(
      PathOperation.intersect,
      behind,
      shell,
    );
    final result = combineFragmentOcclusionPaths(
      PathOperation.difference,
      Path()..addRect(const Rect.fromLTRB(-1000, -1000, 1000, 1000)),
      occluded,
    );
    return result;
  }
}

// Material details use the same accepted faces and depth clip as their carrier.
// Positive winding of accepted faces makes this compound path their union.
class _MaterialVisibility {
  _MaterialVisibility(
    Path shell,
    Path fragmentClip,
    List<_Face> faces,
    _Face outerFace,
  ) {
    final fragment = Path();
    var exposedOuter = Path();
    var coveringOuter = Path();
    for (final face in faces) {
      if (face.screenArea <= 0) continue;
      final path = _polygon(face.vertices.map((v) => v.xy));
      fragment.addPath(path, Offset.zero);
      if (identical(face, outerFace)) {
        exposedOuter = path;
        coveringOuter = Path();
      } else {
        coveringOuter.addPath(path, Offset.zero);
      }
    }
    final visibleFragment = Path.combine(
      PathOperation.intersect,
      fragment,
      fragmentClip,
    );
    fixed = Path.combine(PathOperation.difference, shell, visibleFragment);
    exposedOuter = Path.combine(
      PathOperation.difference,
      exposedOuter,
      coveringOuter,
    );
    mobile = Path.combine(PathOperation.intersect, exposedOuter, fragmentClip);
  }
  late final Path fixed, mobile;
}

class _FractureEdgeSpec {
  const _FractureEdgeSpec({
    required this.id,
    required this.points,
    required this.advance,
  });

  final int id;
  final List<Offset> points;
  final _CrackAdvance advance;
}

class _FragmentEdgeRef {
  const _FragmentEdgeRef(this.edgeId, {required this.reversed});

  final int edgeId;
  final bool reversed;
}

class _ClusterCrackSpec {
  const _ClusterCrackSpec(this.points, this.advance);

  final List<Offset> points;
  final _CrackAdvance advance;
}

class _FractureClusterSpec {
  const _FractureClusterSpec({
    required this.seed,
    required this.pressureEvents,
    required this.chickContacts,
    required this.edges,
    required this.branches,
    required this.microBranches,
  });

  final int seed;
  final List<_PressureEvent> pressureEvents;
  final List<_ChickContactEpisode> chickContacts;
  final List<_FractureEdgeSpec> edges;
  final List<_ClusterCrackSpec> branches;
  final List<_ClusterCrackSpec> microBranches;

  _FractureEdgeSpec edge(_FragmentEdgeRef ref) => edges[ref.edgeId];

  List<Offset> edgePoints(_FragmentEdgeRef ref) {
    final points = edge(ref).points;
    return ref.reversed ? points.reversed.toList(growable: false) : points;
  }

  double _spatialWeight(Offset source, Offset target, {double radius = 65}) {
    final normalized = 1 - (target - source).distance / radius;
    return _smooth(normalized.clamp(0.0, 1.0).toDouble());
  }

  // Instantaneous pressure bends still-attached shell material.
  double pressureAt(double t, Offset point) {
    var pressure = 0.0;
    for (final event in pressureEvents) {
      pressure +=
          event.at(t) *
          _spatialWeight(event.point, point, radius: event.radius + 5);
    }
    for (final contact in chickContacts) {
      pressure +=
          contact.strength *
          contact.envelope(t) *
          _spatialWeight(
            contact.pointAt(t),
            point,
            radius: contact.radiusAt(t),
          );
    }
    return pressure;
  }

  // Shell response keeps a short mechanical tail after each internal impulse.
  // This is not a fragment timer: it is the relaxation of the same shared
  // pressure event after the chick stops pushing.
  double responseAt(double t, Offset point) {
    var response = 0.0;
    for (final event in pressureEvents) {
      final weight = _spatialWeight(
        event.point,
        point,
        radius: event.radius + 5,
      );
      final end = event.center + event.halfWidth;
      final relaxation = t <= end
          ? 0.0
          : .35 * event.strength * (1 - _smoother(_part(t, end, end + .055)));
      response += (event.at(t) + relaxation) * weight;
    }
    for (final contact in chickContacts) {
      response +=
          contact.strength *
          contact.envelope(t) *
          _spatialWeight(
            contact.pointAt(t),
            point,
            radius: contact.radiusAt(t),
          );
    }
    return response;
  }

  // Damage is cumulative and therefore never heals when the chick releases
  // pressure. It is the structural signal used by coupled shell attachments.
  double damageAt(double t, Offset point) {
    var damage = 0.0;
    for (final event in pressureEvents) {
      damage +=
          event.strength *
          _smooth(event.advance(t)) *
          _spatialWeight(event.point, point, radius: event.radius);
    }

    // Integrate the moving chick contact over its traveled path. A fixed number
    // of deterministic segments keeps damage continuous and reproducible while
    // preserving the spatial history of the contact.
    const samples = 12;
    for (final contact in chickContacts) {
      final completed = _part(t, contact.start, contact.end);
      if (completed <= 0) continue;
      var accumulated = 0.0;
      for (var i = 0; i < samples; i++) {
        final u0 = i / samples;
        final u1 = (i + 1) / samples;
        final coverage = _part(completed, u0, u1);
        if (coverage <= 0) continue;
        final u = u0 + (u1 - u0) * coverage * .5;
        final sampleT = contact.start + (contact.end - contact.start) * u;
        accumulated +=
            contact.envelope(sampleT) *
            _spatialWeight(
              contact.pointAt(sampleT),
              point,
              radius: contact.radiusAt(sampleT),
            ) *
            coverage;
      }
      damage += contact.strength * 2 * accumulated / samples;
    }
    return damage;
  }

  // Resultant moment arm of the current internal effort around a fragment
  // center. Two plates under the same chick contact can therefore rotate in
  // different directions without fragment-specific animation tracks.
  Offset momentAt(double t, Offset center) {
    var moment = Offset.zero;
    for (final event in pressureEvents) {
      final weight =
          event.at(t) *
          _spatialWeight(event.point, center, radius: event.radius + 5);
      moment += (event.point - center) * weight;
    }
    for (final contact in chickContacts) {
      final point = contact.pointAt(t);
      final weight =
          contact.strength *
          contact.envelope(t) *
          _spatialWeight(point, center, radius: contact.radiusAt(t));
      moment += (point - center) * weight;
    }
    return moment;
  }
}

class _FragmentSpec {
  const _FragmentSpec({
    required this.seed,
    required this.cluster,
    required this.edgeRefs,
    required this.boundary,
    required this.fractureBoundary,
    required this.liftPushes,
    required this.attachments,
    required this.materialBoundary,
    required this.centerOnShell,
    required this.impactPitch,
    required this.impactYaw,
    required this.impactRoll,
    required this.flightShiftX,
    required this.settleShiftX,
    this.pressureCoupling = 0,
  });

  // Reserved for future deterministic generation. It is metadata only for the
  // reference fragment today: no random value is sampled during animation.
  final int seed;
  final _FractureClusterSpec cluster;
  final List<_FragmentEdgeRef> edgeRefs;
  final List<Offset> boundary;
  final List<Offset> fractureBoundary;
  final List<_LiftPush> liftPushes;
  final List<_ShellAttachment> attachments;
  final List<_V> materialBoundary;
  final Offset centerOnShell;
  final double impactPitch, impactYaw, impactRoll;
  final double flightShiftX, settleShiftX;
  final double pressureCoupling;
}

class _FragmentFrame {
  const _FragmentFrame({
    required this.spec,
    required this.geometry,
    required this.aperture,
    required this.silhouette,
    required this.gap,
  });

  final _FragmentSpec spec;
  final _FragmentGeometry geometry;
  final Path aperture;
  final Path silhouette;
  final Path gap;

  // Painter's algorithm depth for the whole rigid plate. Higher z is closer to
  // the viewer in the existing shell model, matching the per-face depth sort.
  // Use the displayed boundary, not creation order, so detached plates can pass
  // in front of still-attached neighbours.
  double get paintDepth =>
      geometry.projectedOuter.fold(0.0, (sum, point) => sum + point.z) /
      geometry.projectedOuter.length;
}

Path _unionPaths(Iterable<Path> paths) {
  final iterator = paths.iterator;
  if (!iterator.moveNext()) return Path();
  var result = Path.from(iterator.current)..fillType = PathFillType.evenOdd;
  while (iterator.moveNext()) {
    result = combineFragmentOcclusionPaths(
      PathOperation.union,
      result,
      iterator.current,
    );
  }
  return result..fillType = PathFillType.evenOdd;
}

class FragmentScene extends CustomPainter {
  FragmentScene({
    required this.progress,
    required this.thickness,
    required this.motion,
    required this.guides,
    required this.showEgg,
    required this.shadow,
    this.onDiagnostics,
    this.identifySurfaces = false,
  });
  final double progress, thickness, motion;
  final bool guides, showEgg, shadow;
  final bool identifySurfaces;
  final ValueChanged<FragmentPaintDiagnostics>? onDiagnostics;
  Color _surfaceColor(Color normal, Color identity) =>
      identifySurfaces ? identity.withValues(alpha: normal.a) : normal;

  // One immutable boundary drives the crack, aperture and moving fragment.
  static const _boundary = [
    Offset(9, -108),
    Offset(34, -123),
    Offset(47, -109),
    Offset(72, -94),
    Offset(64, -71),
    Offset(78, -57),
    Offset(53, -36),
    Offset(32, -43),
    Offset(13, -34),
    Offset(4, -60),
    Offset(-7, -75),
    Offset(6, -88),
  ];

  // Fixed, small deviations from each structural edge. These are material
  // breaks, not frame-by-frame noise; the same points define crack and cut.
  static const _fractureSteps = [
    [Offset(.21, .7), Offset(.47, -.5), Offset(.79, 1.1)],
    [Offset(.3, -.6), Offset(.63, .8)],
    [Offset(.18, 1.1), Offset(.44, -.4), Offset(.76, .6)],
    [Offset(.26, -.8), Offset(.58, .4), Offset(.83, -.5)],
    [Offset(.34, .7), Offset(.71, -.9)],
    [Offset(.16, -.6), Offset(.39, .8), Offset(.74, -.4)],
    [Offset(.23, .5), Offset(.53, -1.1), Offset(.81, .3)],
    [Offset(.29, -.7), Offset(.67, .5)],
    [Offset(.2, .8), Offset(.49, -.4), Offset(.72, .9)],
    [Offset(.31, -.9), Offset(.62, .5)],
    [Offset(.17, .5), Offset(.45, -.7), Offset(.78, .4)],
    [Offset(.36, -.6), Offset(.7, .8)],
  ];
  static final _fractureEdges = _buildFractureEdges();
  static final _fractureBoundary = [
    for (final edge in _fractureEdges) ...edge.take(edge.length - 1),
  ];

  static List<List<Offset>> _buildFractureEdges() {
    return List.generate(_boundary.length, (i) {
      final a = _boundary[i];
      final b = _boundary[(i + 1) % _boundary.length];
      final direction = b - a;
      final length = direction.distance;
      final normal = Offset(-direction.dy / length, direction.dx / length);
      return [
        a,
        for (final step in _fractureSteps[i])
          a + direction * step.dx + normal * step.dy,
        b,
      ];
    });
  }

  static List<Offset> _buildSingleFractureEdge(
    Offset a,
    Offset b,
    List<Offset> steps,
  ) {
    final direction = b - a;
    final length = direction.distance;
    final normal = Offset(-direction.dy / length, direction.dx / length);
    return [
      a,
      for (final step in steps) a + direction * step.dx + normal * step.dy,
      b,
    ];
  }

  // Disconnected starts grow and pause independently; the last links close
  // only immediately before the plate can move. Each edge is still part of
  // the one contour shared by the hole and the rigid fragment.
  static const _crackAdvances = [
    _CrackAdvance(0, .15, .9),
    _CrackAdvance(3, .3, .95),
    _CrackAdvance(4, .25, .95),
    _CrackAdvance(5, .25, 1),
    _CrackAdvance(0, .35, 1),
    _CrackAdvance(2, .05, .9),
    _CrackAdvance(4, .35, 1),
    _CrackAdvance(5, .4, 1),
    _CrackAdvance(1, .1, .95),
    _CrackAdvance(3, .4, 1),
    _CrackAdvance(4, .05, .9),
    _CrackAdvance(5, .5, 1),
  ];
  static const _branchAdvances = [
    _CrackAdvance(1, .2, .9),
    _CrackAdvance(2, .1, .8),
    _CrackAdvance(3, .45, 1),
    _CrackAdvance(1, .35, 1),
    _CrackAdvance(2, .3, .9),
  ];
  static const _branches = [
    [
      Offset(72, -94),
      Offset(80, -91),
      Offset(83, -88),
      Offset(88, -86),
      Offset(95, -76),
    ],
    [
      Offset(53, -36),
      Offset(65, -31),
      Offset(68, -28),
      Offset(76, -23),
      Offset(83, -16),
    ],
    [
      Offset(-7, -75),
      Offset(-15, -68),
      Offset(-18, -66),
      Offset(-21, -61),
      Offset(-24, -53),
    ],
    [
      Offset(34, -123),
      Offset(43, -129),
      Offset(47, -128),
      Offset(51, -132),
      Offset(64, -125),
    ],
    [
      Offset(64, -71),
      Offset(76, -73),
      Offset(81, -70),
      Offset(83, -72),
      Offset(96, -62),
    ],
  ];
  static const _microAdvances = [
    _CrackAdvance(1, .55, 1),
    _CrackAdvance(2, .45, .95),
    _CrackAdvance(4, .35, .9),
  ];
  static const _microBranches = [
    [Offset(47, -128), Offset(46, -133), Offset(44, -136)],
    [Offset(83, -88), Offset(87, -94)],
    [Offset(68, -28), Offset(69, -23), Offset(72, -21)],
  ];
  // Broad, asymmetric shifts of internal mass. The gaps shorten as activity
  // grows, while amplitudes stay restrained. Local pressure uses shorter pulses.
  static const _bodyEpisodes = [
    _BodyEpisode(.105, .141, .19, .18, .11),
    _BodyEpisode(.225, .257, .299, -.22, .16),
    _BodyEpisode(.327, .352, .389, -.13, .21),
    _BodyEpisode(.403, .424, .459, .27, .2),
    _BodyEpisode(.471, .491, .523, .14, .24),
    _BodyEpisode(.536, .561, .594, -.3, .26),
    // Later efforts correspond to the broader head/front then upper-body push.
    _BodyEpisode(.64, .685, .735, .20, .22),
    _BodyEpisode(.77, .825, .89, -.24, .28),
    _BodyEpisode(.905, .94, .975, .16, .20),
  ];
  // P1..P4 pressure chronology. The mechanics now follow the chick's internal
  // effort directly: beak first, then head/front, then head + upper body.
  // These events also remain the deterministic references used by crack growth.
  static const _sharedPressurePoint = Offset(-8, -76);

  static const _pressureEvents = [
    // P2 — beak: small, localised impacts.
    _PressureEvent(.28, .03, .24, Offset(-2, -78), radius: 26),
    _PressureEvent(.34, .035, .32, Offset(-8, -76), radius: 30),
    _PressureEvent(.40, .04, .40, Offset(6, -82), radius: 34),
    // P3 — head/front: pressure broadens and connects neighbouring cracks.
    _PressureEvent(.47, .045, .48, Offset(-4, -74), radius: 42),
    _PressureEvent(.54, .05, .54, Offset(8, -80), radius: 50),
    _PressureEvent(.61, .055, .58, Offset(-10, -82), radius: 58),
    // P4 preparation — the upper shell is globally weakened but still held.
    _PressureEvent(.68, .06, .62, Offset(0, -78), radius: 66),
    _PressureEvent(.76, .07, .70, Offset(-4, -78), radius: 78),
    _PressureEvent(.84, .08, .78, _sharedPressurePoint, radius: 92),
  ];

  static const _clusterPressureEvents = [
    ..._pressureEvents,
    // P4 — head + upper body. One broad effort feeds every plate in the same
    // cluster; geometry and surviving ligaments decide the different pivots.
    _PressureEvent(.88, .07, .92, _sharedPressurePoint, radius: 104),
    _PressureEvent(.93, .06, 1.08, _sharedPressurePoint, radius: 116),
    _PressureEvent(.975, .035, 1.22, _sharedPressurePoint, radius: 126),
  ];

  static const _chickContacts = <_ChickContactEpisode>[
    // P2 — front-facing beak contact around the main pressure point.
    _ChickContactEpisode(
      start: .25,
      peak: .36,
      end: .50,
      startPoint: Offset(-4, -72),
      peakPoint: _sharedPressurePoint,
      endPoint: Offset(-6, -79),
      startRadius: 18,
      peakRadius: 28,
      endRadius: 36,
      strength: .34,
    ),
    // P3 — forehead/head contact expands around the same front-facing zone.
    _ChickContactEpisode(
      start: .45,
      peak: .61,
      end: .78,
      startPoint: Offset(-6, -76),
      peakPoint: Offset(-4, -82),
      endPoint: Offset(-2, -84),
      startRadius: 42,
      peakRadius: 68,
      endRadius: 82,
      strength: .74,
    ),
    // P4 — head + upper body. The contact area becomes broad rather than
    // turning into fragment-specific kicks.
    _ChickContactEpisode(
      start: .72,
      peak: .90,
      end: .995,
      startPoint: Offset(-4, -80),
      peakPoint: _sharedPressurePoint,
      endPoint: Offset(-6, -72),
      startRadius: 76,
      peakRadius: 108,
      endRadius: 126,
      strength: 1.08,
    ),
  ];

  // All principal plates now use accumulated cluster damage. No fragment owns
  // its own lift timer; pressure → damage → surviving hinge → release.
  static const _liftPushes = <_LiftPush>[];
  static const _attachments = [
    _ShellAttachment(
      10,
      1.05,
      1.08,
      Offset(-22, -77),
      damageStart: 4.2,
      damageEnd: 6.5,
    ),
    _ShellAttachment(
      8,
      1.10,
      1.13,
      Offset(15, -22),
      damageStart: 1.5,
      damageEnd: 2.4,
    ),
    _ShellAttachment(
      0,
      1.15,
      1.18,
      Offset(6, -120),
      damageStart: 2.6,
      damageEnd: 4.0,
    ),
  ];
  static final _grain = _makeGrain();

  static List<Offset> _makeGrain() {
    final random = math.Random(37);
    return List.generate(
      520,
      (_) => Offset(
        -_eggHalfWidth + 2 * _eggHalfWidth * random.nextDouble(),
        -_eggHalfHeight + 2 * _eggHalfHeight * random.nextDouble(),
      ),
    );
  }

  static _V _surface(Offset p) => _V(
    p.dx,
    p.dy,
    _eggDepth *
        math.sqrt(
          math.max(
            0,
            1 -
                math.pow(p.dx / _eggHalfWidth, 2) -
                math.pow(p.dy / _eggHalfHeight, 2),
          ),
        ),
  );

  static _V _surfaceNormal(Offset p) {
    final surface = _surface(p);
    final normal = _V(
      surface.x / (_eggHalfWidth * _eggHalfWidth),
      surface.y / (_eggHalfHeight * _eggHalfHeight),
      surface.z / (_eggDepth * _eggDepth),
    );
    final length = math.sqrt(
      normal.x * normal.x + normal.y * normal.y + normal.z * normal.z,
    );
    return _V(normal.x / length, normal.y / length, normal.z / length);
  }

  // Subdivision preserves the original polygon and its piecewise linear depth.
  static final _materialBoundary = <_V>[
    for (var i = 0; i < _fractureBoundary.length; i++)
      ..._edgeSamples(
        _fractureBoundary[i],
        _fractureBoundary[(i + 1) % _fractureBoundary.length],
      ),
  ];

  // First coupled neighbour. It shares reference edge 9 exactly, reversed,
  // and closes its remaining perimeter with new edges in the same cluster.
  // The plate stays attached for this topology-validation step: one fragment
  // detaches while its neighbour remains part of the shell.
  static final _neighborBoundary = <Offset>[
    _boundary[10],
    _boundary[9],
    // Fragment 2 is intentionally the smallest plate: a compact satellite
    // formed immediately beside the primary opening by the first head/neck
    // pressure. Its upper-left edge around the pressure point becomes the
    // literal shared seam with F3.
    const Offset(-2, -49),
    const Offset(-13, -44),
    const Offset(-25, -49),
    const Offset(-28, -61),
    const Offset(-19, -73),
  ];

  static const _neighborSteps = <List<Offset>>[
    [Offset(.31, .5), Offset(.67, -.6)],
    [Offset(.22, -.5), Offset(.54, .8), Offset(.81, -.4)],
    [Offset(.28, .7), Offset(.62, -.5)],
    [Offset(.2, -.6), Offset(.47, .5), Offset(.78, -.7)],
    [Offset(.3, .5), Offset(.66, -.6)],
    [Offset(.25, -.5), Offset(.57, .7), Offset(.82, -.4)],
  ];

  static final _neighborOuterEdges = <List<Offset>>[
    _buildSingleFractureEdge(
      _neighborBoundary[1],
      _neighborBoundary[2],
      _neighborSteps[0],
    ),
    _buildSingleFractureEdge(
      _neighborBoundary[2],
      _neighborBoundary[3],
      _neighborSteps[1],
    ),
    _buildSingleFractureEdge(
      _neighborBoundary[3],
      _neighborBoundary[4],
      _neighborSteps[2],
    ),
    _buildSingleFractureEdge(
      _neighborBoundary[4],
      _neighborBoundary[5],
      _neighborSteps[3],
    ),
    _buildSingleFractureEdge(
      _neighborBoundary[5],
      _neighborBoundary[6],
      _neighborSteps[4],
    ),
    _buildSingleFractureEdge(
      _neighborBoundary[6],
      _neighborBoundary[0],
      _neighborSteps[5],
    ),
  ];

  static const _neighborOuterAdvances = <_CrackAdvance>[
    _CrackAdvance(9, .05, .72),
    _CrackAdvance(9, .22, .9),
    _CrackAdvance(7, .35, .95),
    _CrackAdvance(8, .25, .9),
    _CrackAdvance(9, .42, 1),
    // This is also F3's shared seam. Let it become readable just before the
    // coupled opening instead of appearing only after the plate has started
    // moving.
    _CrackAdvance(8, .35, .95),
  ];

  static final _neighborFractureEdges = <List<Offset>>[
    _fractureEdges[9].reversed.toList(growable: false),
    ..._neighborOuterEdges,
  ];

  static final _neighborFractureBoundary = <Offset>[
    for (final edge in _neighborFractureEdges) ...edge.take(edge.length - 1),
  ];

  static final _neighborMaterialBoundary = <_V>[
    for (var i = 0; i < _neighborFractureBoundary.length; i++)
      ..._edgeSamples(
        _neighborFractureBoundary[i],
        _neighborFractureBoundary[(i + 1) % _neighborFractureBoundary.length],
      ),
  ];

  // Coupled ligaments use the same material-strength bands as F3. Spatial
  // pressure decides the small timing differences; there is no plate-by-plate
  // release schedule.
  static const _neighborAttachments = <_ShellAttachment>[
    _ShellAttachment(
      2,
      1.05,
      1.08,
      Offset(5, -42),
      damageStart: 2.2,
      damageEnd: 3.8,
    ),
    _ShellAttachment(
      4,
      1.10,
      1.13,
      Offset(-38, -43),
      damageStart: 1.8,
      damageEnd: 3.4,
    ),
    _ShellAttachment(
      6,
      1.15,
      1.18,
      Offset(-25, -84),
      damageStart: 3.4,
      damageEnd: 5.7,
    ),
  ];

  // Third plate in the SAME fracture cluster. It now shares neighbour outer
  // edge 5 exactly (reversed): the short seam beside the marked pressure point.
  // F3 therefore grows above-left of that point, matching the requested sketch
  // instead of occupying the lower-left region of the opening.
  static final _thirdBoundary = <Offset>[
    _neighborBoundary[0],
    _neighborBoundary[6],
    // F3 is the large upper/back cap from the target composition. It keeps
    // the small shared seam beside the beak-pressure zone, then wraps over the
    // crown instead of behaving like another small central chip.
    const Offset(-42, -92),
    const Offset(-58, -126),
    const Offset(-48, -160),
    const Offset(-20, -184),
    const Offset(10, -180),
    const Offset(34, -150),
    const Offset(38, -114),
    const Offset(20, -90),
  ];

  static const _thirdSteps = <List<Offset>>[
    [Offset(.24, -.5), Offset(.58, .7), Offset(.82, -.4)],
    [Offset(.31, .6), Offset(.69, -.7)],
    [Offset(.2, -.5), Offset(.49, .6), Offset(.78, -.5)],
    [Offset(.28, .7), Offset(.64, -.6)],
    [Offset(.22, -.6), Offset(.55, .7), Offset(.8, -.4)],
    [Offset(.34, .5), Offset(.7, -.6)],
    [Offset(.24, -.6), Offset(.56, .7), Offset(.82, -.4)],
    [Offset(.30, .6), Offset(.66, -.6)],
    [Offset(.22, -.5), Offset(.52, .7), Offset(.8, -.4)],
  ];

  static final _thirdOuterEdges = <List<Offset>>[
    for (var i = 1; i < _thirdBoundary.length; i++)
      _buildSingleFractureEdge(
        _thirdBoundary[i],
        _thirdBoundary[(i + 1) % _thirdBoundary.length],
        _thirdSteps[i - 1],
      ),
  ];

  static const _thirdOuterAdvances = <_CrackAdvance>[
    // The cap is progressively outlined by P3/P4. Its lower seam appears first;
    // the crown completes only as the head pressure broadens.
    _CrackAdvance(7, .18, .86),
    _CrackAdvance(7, .34, .94),
    _CrackAdvance(8, .12, .86),
    _CrackAdvance(8, .28, .94),
    _CrackAdvance(8, .42, 1),
    _CrackAdvance(9, .14, .86),
    _CrackAdvance(9, .30, .94),
    _CrackAdvance(9, .46, 1),
    _CrackAdvance(8, .52, 1),
  ];

  static final _thirdFractureEdges = <List<Offset>>[
    _neighborOuterEdges[5].reversed.toList(growable: false),
    ..._thirdOuterEdges,
  ];

  static final _thirdFractureBoundary = <Offset>[
    for (final edge in _thirdFractureEdges) ...edge.take(edge.length - 1),
  ];

  static final _thirdMaterialBoundary = <_V>[
    for (var i = 0; i < _thirdFractureBoundary.length; i++)
      ..._edgeSamples(
        _thirdFractureBoundary[i],
        _thirdFractureBoundary[(i + 1) % _thirdFractureBoundary.length],
      ),
  ];

  static const _thirdAttachments = <_ShellAttachment>[
    _ShellAttachment(
      2,
      1.05,
      1.08,
      Offset(-54, -88),
      damageStart: 1.4,
      damageEnd: 2.5,
    ),
    _ShellAttachment(
      8,
      1.10,
      1.13,
      Offset(44, -112),
      damageStart: 1.8,
      damageEnd: 3.2,
    ),
    _ShellAttachment(
      5,
      1.15,
      1.18,
      Offset(-18, -194),
      // Back/crown hinge deliberately survives the hatch. The cap can swing
      // behind the future chick's head instead of becoming another floor shard.
      damageStart: 50,
      damageEnd: 60,
    ),
  ];

  // F4 — left lateral bowl wall. It grows from F2's lower-left seam, releases
  // two ligaments under P4, then stays on one outer hinge instead of falling.
  static final _fourthBoundary = <Offset>[
    _neighborBoundary[4],
    _neighborBoundary[3],
    // Left rim of the persistent lower bowl. The inner edge drops toward the
    // future chick's chest; the outer edge follows the egg wall much lower.
    const Offset(-10, -12),
    const Offset(-20, 24),
    const Offset(-42, 56),
    const Offset(-72, 72),
    const Offset(-98, 44),
    const Offset(-96, 4),
    const Offset(-72, -34),
  ];

  static const _fourthSteps = <List<Offset>>[
    [Offset(.28, -.5), Offset(.62, .6)],
    [Offset(.22, .6), Offset(.52, -.5), Offset(.82, .4)],
    [Offset(.31, -.6), Offset(.68, .5)],
    [Offset(.2, .5), Offset(.47, -.7), Offset(.78, .5)],
    [Offset(.27, -.5), Offset(.61, .7)],
    [Offset(.24, .6), Offset(.56, -.5), Offset(.84, .4)],
    [Offset(.34, -.6), Offset(.71, .6)],
    [Offset(.25, .5), Offset(.58, -.6), Offset(.82, .4)],
  ];

  static final _fourthOuterEdges = <List<Offset>>[
    for (var i = 1; i < _fourthBoundary.length; i++)
      _buildSingleFractureEdge(
        _fourthBoundary[i],
        _fourthBoundary[(i + 1) % _fourthBoundary.length],
        _fourthSteps[i - 1],
      ),
  ];

  static const _fourthOuterAdvances = <_CrackAdvance>[
    _CrackAdvance(8, .35, .92),
    _CrackAdvance(8, .55, 1),
    _CrackAdvance(9, .18, .86),
    _CrackAdvance(9, .40, .98),
    _CrackAdvance(10, .20, .88),
    _CrackAdvance(10, .42, 1),
    _CrackAdvance(9, .58, 1),
    _CrackAdvance(10, .62, 1),
  ];

  static final _fourthFractureEdges = <List<Offset>>[
    _neighborOuterEdges[2].reversed.toList(growable: false),
    ..._fourthOuterEdges,
  ];

  static final _fourthFractureBoundary = <Offset>[
    for (final edge in _fourthFractureEdges) ...edge.take(edge.length - 1),
  ];

  static final _fourthMaterialBoundary = <_V>[
    for (var i = 0; i < _fourthFractureBoundary.length; i++)
      ..._edgeSamples(
        _fourthFractureBoundary[i],
        _fourthFractureBoundary[(i + 1) % _fourthFractureBoundary.length],
      ),
  ];

  static const _fourthAttachments = <_ShellAttachment>[
    _ShellAttachment(
      2,
      1.05,
      1.08,
      Offset(-8, -4),
      damageStart: .60,
      damageEnd: 1.80,
    ),
    _ShellAttachment(
      5,
      1.10,
      1.13,
      Offset(-82, 82),
      // Permanent lower-left hinge: this plate is a bowl wall, not debris.
      damageStart: 50,
      damageEnd: 60,
    ),
    _ShellAttachment(
      8,
      1.15,
      1.18,
      Offset(-76, -42),
      damageStart: 1.0,
      damageEnd: 2.5,
    ),
  ];

  // F5 — front/right bowl wall. It shares a real F1 edge, opens late and keeps
  // one lower-right hinge, preserving the jagged bowl around the chick.
  static final _fifthBoundary = <Offset>[
    _boundary[8],
    _boundary[7],
    // Right/front rim mirrors F4 only in role, not in silhouette.
    const Offset(62, -28),
    const Offset(90, -4),
    const Offset(102, 34),
    const Offset(82, 68),
    const Offset(48, 78),
    const Offset(18, 58),
    const Offset(2, 22),
  ];

  static const _fifthSteps = <List<Offset>>[
    [Offset(.26, .5), Offset(.61, -.6)],
    [Offset(.23, -.5), Offset(.55, .7), Offset(.82, -.4)],
    [Offset(.30, .6), Offset(.68, -.5)],
    [Offset(.2, -.6), Offset(.48, .5), Offset(.79, -.6)],
    [Offset(.29, .5), Offset(.64, -.6)],
    [Offset(.25, -.5), Offset(.57, .7), Offset(.83, -.4)],
    [Offset(.35, .6), Offset(.72, -.6)],
    [Offset(.24, -.5), Offset(.56, .7), Offset(.82, -.4)],
  ];

  static final _fifthOuterEdges = <List<Offset>>[
    for (var i = 1; i < _fifthBoundary.length; i++)
      _buildSingleFractureEdge(
        _fifthBoundary[i],
        _fifthBoundary[(i + 1) % _fifthBoundary.length],
        _fifthSteps[i - 1],
      ),
  ];

  static const _fifthOuterAdvances = <_CrackAdvance>[
    _CrackAdvance(8, .42, .95),
    _CrackAdvance(9, .20, .88),
    _CrackAdvance(9, .46, 1),
    _CrackAdvance(10, .24, .90),
    _CrackAdvance(10, .48, 1),
    _CrackAdvance(11, .18, .88),
    _CrackAdvance(11, .45, 1),
    _CrackAdvance(10, .62, 1),
  ];

  static final _fifthFractureEdges = <List<Offset>>[
    _fractureEdges[7].reversed.toList(growable: false),
    ..._fifthOuterEdges,
  ];

  static final _fifthFractureBoundary = <Offset>[
    for (final edge in _fifthFractureEdges) ...edge.take(edge.length - 1),
  ];

  static final _fifthMaterialBoundary = <_V>[
    for (var i = 0; i < _fifthFractureBoundary.length; i++)
      ..._edgeSamples(
        _fifthFractureBoundary[i],
        _fifthFractureBoundary[(i + 1) % _fifthFractureBoundary.length],
      ),
  ];

  static const _fifthAttachments = <_ShellAttachment>[
    _ShellAttachment(
      2,
      1.05,
      1.08,
      Offset(68, -34),
      damageStart: .40,
      damageEnd: .90,
    ),
    _ShellAttachment(
      5,
      1.10,
      1.13,
      Offset(88, 78),
      // Permanent lower-right hinge: opposite wall of the same bowl.
      damageStart: 50,
      damageEnd: 60,
    ),
    _ShellAttachment(
      8,
      1.15,
      1.18,
      Offset(-4, 32),
      damageStart: .70,
      damageEnd: 1.30,
    ),
  ];

  // Shared fracture topology. Fragments reference edge ids from this cluster;
  // edge 9 is therefore literally one crack used by both neighbouring plates.
  static final _fractureCluster = _FractureClusterSpec(
    seed: 1,
    pressureEvents: _clusterPressureEvents,
    chickContacts: _chickContacts,
    edges: [
      for (var i = 0; i < _fractureEdges.length; i++)
        _FractureEdgeSpec(
          id: i,
          points: _fractureEdges[i],
          advance: _crackAdvances[i],
        ),
      for (var i = 0; i < _neighborOuterEdges.length; i++)
        _FractureEdgeSpec(
          id: _fractureEdges.length + i,
          points: _neighborOuterEdges[i],
          advance: _neighborOuterAdvances[i],
        ),
      for (var i = 0; i < _thirdOuterEdges.length; i++)
        _FractureEdgeSpec(
          id: _fractureEdges.length + _neighborOuterEdges.length + i,
          points: _thirdOuterEdges[i],
          advance: _thirdOuterAdvances[i],
        ),
      for (var i = 0; i < _fourthOuterEdges.length; i++)
        _FractureEdgeSpec(
          id: _fractureEdges.length +
              _neighborOuterEdges.length +
              _thirdOuterEdges.length +
              i,
          points: _fourthOuterEdges[i],
          advance: _fourthOuterAdvances[i],
        ),
      for (var i = 0; i < _fifthOuterEdges.length; i++)
        _FractureEdgeSpec(
          id: _fractureEdges.length +
              _neighborOuterEdges.length +
              _thirdOuterEdges.length +
              _fourthOuterEdges.length +
              i,
          points: _fifthOuterEdges[i],
          advance: _fifthOuterAdvances[i],
        ),
    ],
    branches: [
      for (var i = 0; i < _branches.length; i++)
        _ClusterCrackSpec(_branches[i], _branchAdvances[i]),
    ],
    microBranches: [
      for (var i = 0; i < _microBranches.length; i++)
        _ClusterCrackSpec(_microBranches[i], _microAdvances[i]),
    ],
  );

  static final _referenceEdgeRefs = [
    for (var i = 0; i < _fractureEdges.length; i++)
      _FragmentEdgeRef(i, reversed: false),
  ];
  static final _neighborEdgeRefs = <_FragmentEdgeRef>[
    const _FragmentEdgeRef(9, reversed: true),
    for (var i = 0; i < _neighborOuterEdges.length; i++)
      _FragmentEdgeRef(_fractureEdges.length + i, reversed: false),
  ];
  static final _thirdEdgeRefs = <_FragmentEdgeRef>[
    _FragmentEdgeRef(_fractureEdges.length + 5, reversed: true),
    for (var i = 0; i < _thirdOuterEdges.length; i++)
      _FragmentEdgeRef(
        _fractureEdges.length + _neighborOuterEdges.length + i,
        reversed: false,
      ),
  ];

  static final _fourthEdgeRefs = <_FragmentEdgeRef>[
    _FragmentEdgeRef(_fractureEdges.length + 2, reversed: true),
    for (var i = 0; i < _fourthOuterEdges.length; i++)
      _FragmentEdgeRef(
        _fractureEdges.length +
            _neighborOuterEdges.length +
            _thirdOuterEdges.length +
            i,
        reversed: false,
      ),
  ];

  static final _fifthEdgeRefs = <_FragmentEdgeRef>[
    const _FragmentEdgeRef(7, reversed: true),
    for (var i = 0; i < _fifthOuterEdges.length; i++)
      _FragmentEdgeRef(
        _fractureEdges.length +
            _neighborOuterEdges.length +
            _thirdOuterEdges.length +
            _fourthOuterEdges.length +
            i,
        reversed: false,
      ),
  ];

  // Exact validated single-fragment reference, now expressed as data.
  // Future deterministic generation will create additional _FragmentSpec
  // instances; the mechanics below must not depend on these particular values.
  static final _referenceFragment = _FragmentSpec(
    seed: 1,
    cluster: _fractureCluster,
    edgeRefs: _referenceEdgeRefs,
    boundary: _boundary,
    fractureBoundary: _fractureBoundary,
    liftPushes: _liftPushes,
    attachments: _attachments,
    materialBoundary: _materialBoundary,
    centerOnShell: const Offset(35, -78),
    impactPitch: .55,
    impactYaw: .55,
    impactRoll: .35,
    flightShiftX: 55,
    settleShiftX: 4,
    pressureCoupling: .52,
  );

  static final _neighborFragment = _FragmentSpec(
    seed: 2,
    cluster: _fractureCluster,
    edgeRefs: _neighborEdgeRefs,
    boundary: _neighborBoundary,
    fractureBoundary: _neighborFractureBoundary,
    liftPushes: const [],
    attachments: _neighborAttachments,
    materialBoundary: _neighborMaterialBoundary,
    centerOnShell: const Offset(-13, -59),
    // Keep the detached neighbour on a broad face. The previous landing
    // orientation projected it almost edge-on and made the same plate look like
    // a thin sliver despite unchanged geometry.
    impactPitch: .25,
    impactYaw: .5,
    impactRoll: .25,
    flightShiftX: -40,
    settleShiftX: -3,
    pressureCoupling: .45,
  );

  static final _thirdFragment = _FragmentSpec(
    seed: 3,
    cluster: _fractureCluster,
    edgeRefs: _thirdEdgeRefs,
    boundary: _thirdBoundary,
    fractureBoundary: _thirdFractureBoundary,
    liftPushes: const [],
    attachments: _thirdAttachments,
    materialBoundary: _thirdMaterialBoundary,
    centerOnShell: const Offset(-14, -130),
    // Keep the same broad-face fallback used by the neighbour; no special
    // occlusion or shape correction is introduced for this third plate.
    impactPitch: .25,
    impactYaw: .5,
    impactRoll: .25,
    flightShiftX: -48,
    settleShiftX: -3,
    pressureCoupling: .42,
  );

  static final _fourthFragment = _FragmentSpec(
    seed: 4,
    cluster: _fractureCluster,
    edgeRefs: _fourthEdgeRefs,
    boundary: _fourthBoundary,
    fractureBoundary: _fourthFractureBoundary,
    liftPushes: const [],
    attachments: _fourthAttachments,
    materialBoundary: _fourthMaterialBoundary,
    centerOnShell: const Offset(-55, 18),
    impactPitch: .22,
    impactYaw: -.38,
    impactRoll: -.20,
    flightShiftX: -58,
    settleShiftX: -6,
    pressureCoupling: .22,
  );

  static final _fifthFragment = _FragmentSpec(
    seed: 5,
    cluster: _fractureCluster,
    edgeRefs: _fifthEdgeRefs,
    boundary: _fifthBoundary,
    fractureBoundary: _fifthFractureBoundary,
    liftPushes: const [],
    attachments: _fifthAttachments,
    materialBoundary: _fifthMaterialBoundary,
    centerOnShell: const Offset(55, 20),
    impactPitch: .20,
    impactYaw: .42,
    impactRoll: .18,
    flightShiftX: 52,
    settleShiftX: 6,
    pressureCoupling: .24,
  );

  static final List<_FragmentSpec> _fragments = [
    _referenceFragment,
    _neighborFragment,
    _thirdFragment,
    _fourthFragment,
    _fifthFragment,
  ];

  static List<_V> _edgeSamples(Offset a, Offset b) {
    final count = ((b - a).distance / 2).ceil();
    return [
      for (var i = 0; i < count; i++)
        _V.lerp(_surface(a), _surface(b), i / count),
    ];
  }

  static double _boundarySpan(List<Offset> boundary) {
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final point in boundary) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }
    return math.sqrt(math.pow(maxX - minX, 2) + math.pow(maxY - minY, 2));
  }

  static final double _referenceAttachmentSpan = _boundarySpan(_boundary);

  double _attachmentInfluenceScale(_FragmentSpec fragment) =>
      _boundarySpan(fragment.boundary) / _referenceAttachmentSpan;

  double _attachmentHold(
    _FragmentSpec fragment,
    _ShellAttachment attachment,
    double fragmentProgress,
  ) {
    final attachmentPoint = fragment.boundary[attachment.vertex];
    final damage = fragment.cluster.damageAt(fragmentProgress, attachmentPoint);
    return attachment.hold(fragmentProgress, damage: damage);
  }

  double _detachmentProgress(_FragmentSpec fragment) {
    final usesClusterDamage = fragment.attachments.any(
      (attachment) => attachment.damageStart != null,
    );
    if (!usesClusterDamage) {
      return fragment.attachments.fold(
        0.0,
        (latest, attachment) => math.max(latest, attachment.releaseEnd),
      );
    }

    bool fullyReleased(double t) => fragment.attachments.every(
      (attachment) => _attachmentHold(fragment, attachment, t) == 0,
    );

    if (!fullyReleased(1)) return 1.0;

    var low = 0.0;
    var high = 1.0;
    for (var i = 0; i < 22; i++) {
      final mid = (low + high) / 2;
      if (fullyReleased(mid)) {
        high = mid;
      } else {
        low = mid;
      }
    }
    return high;
  }

  double _retention(
    _FragmentSpec fragment,
    Offset point,
    double fragmentProgress,
  ) {
    var retained = 0.0;
    // The validated reference used a 4→40 unit attachment influence. Scale that
    // SAME material behavior with each fragment's own span so a small plate is
    // not deformed across nearly its entire surface by one surviving ligament.
    // The reference fragment evaluates to exactly scale=1.
    final influenceScale = _attachmentInfluenceScale(fragment);
    final pinnedCore = 4 * influenceScale;
    final influenceRadius = 40 * influenceScale;
    for (final attachment in fragment.attachments) {
      final distance = (point - fragment.boundary[attachment.vertex]).distance;
      // A surviving ligament pins its core until its actual rupture, including
      // during the release episode. On rupture its elastic deformation cannot
      // disappear instantaneously: relax it C1 over that ligament's loading
      // duration, without changing the free rigid pose or switching meshes.
      final responseDuration = attachment.releaseEnd - attachment.releaseStart;
      final attachmentHold = _attachmentHold(
        fragment,
        attachment,
        fragmentProgress,
      );
      final elasticMemory = attachment.damageStart != null
          ? attachmentHold
          : 1 -
                _smooth(
                  _part(
                    fragmentProgress,
                    attachment.releaseEnd,
                    attachment.releaseEnd + responseDuration,
                  ),
                );
      final weight = 1 - _smooth(_part(distance, pinnedCore, influenceRadius));
      retained = math.max(retained, elasticMemory * weight);
    }
    return retained;
  }

  _V _attachedRotationAt(_FragmentSpec fragment, double t) {
    final coupledReleasedShare = fragment.attachments.isEmpty
        ? 0.0
        : fragment.attachments.fold(
                0.0,
                (sum, attachment) =>
                    sum + (1 - _attachmentHold(fragment, attachment, t)),
              ) /
              fragment.attachments.length;

    var heldWeight = 0.0;
    var heldPoint = Offset.zero;
    for (final attachment in fragment.attachments) {
      final hold = _attachmentHold(fragment, attachment, t);
      heldWeight += hold;
      heldPoint += fragment.boundary[attachment.vertex] * hold;
    }
    final remainingPivot = heldWeight > 0
        ? heldPoint / heldWeight
        : fragment.centerOnShell;
    final attachmentBlend = _smooth(_part(coupledReleasedShare, .55, 1));
    final pivotOnShell = Offset.lerp(
      remainingPivot,
      fragment.centerOnShell,
      attachmentBlend,
    )!;

    if (fragment.pressureCoupling > 0) {
      // All coupled plates are driven by the SAME dominant pressure point. The
      // visible opening is the moment of that force around each surviving
      // ligament, so plates on opposite sides of the point naturally tip in
      // different directions without any fragment-specific lift.
      final sharedPressure = fragment.cluster.responseAt(
        t,
        _sharedPressurePoint,
      );
      final lever = _sharedPressurePoint - pivotOnShell;
      final torqueX =
          fragment.pressureCoupling * sharedPressure * lever.dy / 45;
      final torqueY =
          -fragment.pressureCoupling * sharedPressure * lever.dx / 45;
      final compliance = .42 + .58 * _smooth(coupledReleasedShare);
      return _V(compliance * torqueX, compliance * torqueY, 0);
    }

    // Validated reference fragment: keep the historical attached-pose model.
    final pressureLift =
        fragment.cluster.responseAt(t, fragment.centerOnShell) *
        (1 + .65 * coupledReleasedShare);
    final drivenLift =
        (fragment.liftPushes.fold(0.0, (sum, push) => sum + push.at(t)) +
                pressureLift -
                .025 * _pulse(t, .519, .005) -
                .02 * _pulse(t, .547, .005) -
                .015 * _pulse(t, .576, .006))
            .clamp(0.0, 1.0);
    final releaseLift = _smooth(_part(coupledReleasedShare, .72, 1));
    final lift = math.max(drivenLift, releaseLift);
    final center = _surface(fragment.centerOnShell);
    final pressureRoll = fragment.liftPushes.fold(
      0.0,
      (sum, push) => sum + push.at(t) * (push.point.dx - center.x) / 45,
    );
    final pressurePitch = fragment.liftPushes.fold(
      0.0,
      (sum, push) => sum + push.at(t) * (push.point.dy - center.y) / 45,
    );

    return _V(
      -.38 * lift + (.03 + .01 * coupledReleasedShare) * pressurePitch,
      .45 * lift,
      -(.14 + .025 * coupledReleasedShare) * pressureRoll,
    );
  }

  _V _coupledFlightRotation(
    _FragmentSpec fragment,
    double flightStart,
    double settleStart,
    double t,
  ) {
    final released = _attachedRotationAt(fragment, flightStart);
    const velocityWindow = .012;
    final beforeT = math.max(0.0, flightStart - velocityWindow);
    final before = _attachedRotationAt(fragment, beforeT);
    final dt = math.max(1e-6, flightStart - beforeT);
    final angularVelocity = _V(
      (released.x - before.x) / dt,
      (released.y - before.y) / dt,
      (released.z - before.z) / dt,
    );

    // Preserve the angular velocity carried through the last hinge rupture,
    // then damp it continuously. Once the plate reaches the floor, freeze the
    // resulting landing orientation rather than steering every plate toward
    // the same hand-authored impact angles.
    const damping = 7.5;
    final impactElapsed = math.max(0.0, settleStart - flightStart);
    final elapsed = math.min(math.max(0.0, t - flightStart), impactElapsed);
    final angularTravel = (1 - math.exp(-damping * elapsed)) / damping;
    return _V(
      released.x + angularVelocity.x * angularTravel,
      released.y + angularVelocity.y * angularTravel,
      released.z + angularVelocity.z * angularTravel,
    );
  }

  _FragmentGeometry _geometry(_FragmentSpec fragment) {
    final fragmentProgress = progress;
    // Local material constraints bend the region around its established pose.
    final coupledReleasedShare = fragment.attachments.isEmpty
        ? 0.0
        : fragment.attachments.fold(
                0.0,
                (sum, attachment) =>
                    sum +
                    (1 -
                        _attachmentHold(
                          fragment,
                          attachment,
                          fragmentProgress,
                        )),
              ) /
              fragment.attachments.length;
    final pressureLift =
        fragment.pressureCoupling *
        fragment.cluster.responseAt(fragmentProgress, fragment.centerOnShell) *
        (1 + .65 * coupledReleasedShare);
    final drivenLift =
        (fragment.liftPushes.fold(
                  0.0,
                  (sum, push) => sum + push.at(fragmentProgress),
                ) +
                pressureLift -
                .025 * _pulse(fragmentProgress, .519, .005) -
                .02 * _pulse(fragmentProgress, .547, .005) -
                .015 * _pulse(fragmentProgress, .576, .006))
            .clamp(0.0, 1.0);
    // Once a plate is almost free, its outward separation cannot collapse just
    // because the pressure impulse ended. Carry the release state into free
    // flight for every fragment. The validated reference already reaches lift=1
    // from its existing pushes, so this generic floor leaves it unchanged.
    final releaseLift = _smooth(_part(coupledReleasedShare, .72, 1));
    final lift = math.max(drivenLift, releaseLift);
    // Free flight begins only after all attachments have actually released.
    // For cluster-coupled fragments this instant is derived from accumulated
    // pressure damage; the validated reference keeps its original .60 start.
    final flightStart = _detachmentProgress(fragment);
    final flightEnd = flightStart + .28;
    final linearFlight = flightStart >= 1
        ? 0.0
        : _part(fragmentProgress, flightStart, math.min(1.0, flightEnd));
    // C1 departure; for the validated reference, flightStart=.60 and
    // flightEnd=.88, so its existing trajectory remains unchanged.
    final u = (linearFlight / .05).clamp(0.0, 1.0);
    final flight = linearFlight < .05 ? .05 * u * u * (2 - u) : linearFlight;
    final turn = flight * (1.12 - .12 * flight);
    final settleStart = math.min(1.0, flightEnd);
    final settle = settleStart >= 1
        ? 0.0
        : _smooth(_part(fragmentProgress, settleStart, 1));
    final recoil = math.sin(2 * math.pi * settle) * (1 - settle) * (1 - settle);
    final bounce = 4 * math.sin(math.pi * settle) * (1 - settle);
    final center = _surface(fragment.centerOnShell);
    var heldWeight = 0.0;
    var heldPoint = Offset.zero;
    for (final attachment in fragment.attachments) {
      final hold = _attachmentHold(fragment, attachment, fragmentProgress);
      heldWeight += hold;
      heldPoint += fragment.boundary[attachment.vertex] * hold;
    }
    final remainingPivot = heldWeight > 0
        ? heldPoint / heldWeight
        : fragment.centerOnShell;
    final releasedShare = 1 - heldWeight / fragment.attachments.length;
    final attachmentBlend = _smooth(_part(releasedShare, .55, 1));
    final pivotOnShell = Offset.lerp(
      remainingPivot,
      fragment.centerOnShell,
      attachmentBlend,
    )!;
    final pivot = _surface(pivotOnShell);
    // Off-center pressure changes only the early pose. Its small torque fades
    // during flight, leaving the established fall and landing unchanged.
    // For coupled fragments, measure the chick force around the CURRENT
    // surviving hinge, not around the fragment center. Internal pressure is
    // predominantly normal to the shell (+z), so r × Fz produces pitch/yaw
    // torque (x/y), not an arbitrary in-plane roll.
    final clusterMoment = fragment.pressureCoupling == 0
        ? Offset.zero
        : fragment.cluster.momentAt(fragmentProgress, pivotOnShell);
    final clusterTorqueX = fragment.pressureCoupling * clusterMoment.dy / 45;
    final clusterTorqueY = -fragment.pressureCoupling * clusterMoment.dx / 45;
    final pressureRoll = fragment.liftPushes.fold(
      0.0,
      (sum, push) =>
          sum + push.at(fragmentProgress) * (push.point.dx - center.x) / 45,
    );
    final pressurePitch = fragment.liftPushes.fold(
      0.0,
      (sum, push) =>
          sum + push.at(fragmentProgress) * (push.point.dy - center.y) / 45,
    );
    final initialTorqueFade = 1 - turn;
    final coupledFlight = fragment.pressureCoupling > 0;
    // The reference fragment keeps its validated target-based fall. Coupled
    // fragments instead inherit the angle and angular velocity present at the
    // exact rupture of their last ligament.
    final impactPitch = fragment.impactPitch;
    final impactYaw = fragment.impactYaw;
    final impactRoll = fragment.impactRoll;
    late final double rotationX, rotationY, rotationZ;
    if (coupledFlight && flight > 0) {
      final inertialRotation = _coupledFlightRotation(
        fragment,
        flightStart,
        settleStart,
        fragmentProgress,
      );
      rotationX = inertialRotation.x;
      rotationY = inertialRotation.y;
      rotationZ = inertialRotation.z;
    } else if (coupledFlight) {
      final attachedRotation = _attachedRotationAt(fragment, fragmentProgress);
      rotationX = attachedRotation.x;
      rotationY = attachedRotation.y;
      rotationZ = attachedRotation.z;
    } else {
      rotationX =
          -.38 * lift +
          (impactPitch + .38) * turn +
          .25 * settle +
          (.03 + .01 * releasedShare) * pressurePitch * initialTorqueFade +
          .14 * clusterTorqueX * initialTorqueFade;
      rotationY =
          .45 * lift +
          (impactYaw - .45) * turn -
          .4 * settle +
          .03 * recoil +
          .14 * clusterTorqueY * initialTorqueFade;
      rotationZ =
          impactRoll * turn -
          .5 * settle +
          .05 * recoil -
          (.14 + .025 * releasedShare) * pressureRoll * initialTorqueFade;
    }
    _V rotate(_V v) =>
        (v - pivot).rotate(rotationX, rotationY, rotationZ) + pivot - center;
    final outer = fragment.materialBoundary;
    final inner = outer.map((v) => _V(v.x, v.y, v.z - thickness)).toList();
    final rotated = [...outer, ...inner].map(rotate).toList();
    final bottom = rotated.map((v) => v.y).reduce(math.max);
    final landingRotation = coupledFlight
        ? _coupledFlightRotation(
            fragment,
            flightStart,
            settleStart,
            settleStart,
          )
        : _V(impactPitch, impactYaw, impactRoll);
    final impactBottom = [...outer, ...inner]
        .map(
          (v) => (v - center)
              .rotate(landingRotation.x, landingRotation.y, landingRotation.z)
              .y,
        )
        .reduce(math.max);
    final impactLandingY = 220 - center.y - impactBottom;
    final shellNormal = _surfaceNormal(fragment.centerOnShell);
    // Coupled plates share the same internal effort. Their local shell
    // curvature still differentiates the outward X/Z separation, but it must
    // not create a fragment-specific screen-vertical kick: an upper plate
    // should not shoot upward merely because its local normal points upward.
    // After the last ligament breaks, gravity owns Y immediately.
    // The reference fragment keeps its validated historical equations verbatim.
    const ejectionTravel = 65.0;
    late final double flightX, ballisticY, flightZ;
    if (coupledFlight) {
      final normalTravelX = shellNormal.x * ejectionTravel;
      final normalTravelZ = shellNormal.z * ejectionTravel;
      flightX = normalTravelX * flight;
      ballisticY = impactLandingY * flight * flight;
      flightZ = normalTravelZ * flight;
    } else {
      final initialFlightY = -20.0;
      flightX = fragment.flightShiftX * flight + fragment.settleShiftX * settle;
      ballisticY =
          -12 * lift * lift * (1 - flight) +
          initialFlightY * flight +
          (impactLandingY - initialFlightY) * flight * flight;
      flightZ = 22 * lift * lift;
    }
    final groundedY = 220 - center.y - bottom;
    final shift = _V(
      flightX,
      (settle > 0 ? groundedY : ballisticY) - bounce,
      flightZ,
    );
    // Express the pose as a displacement. A zero rotation/translation must
    // preserve material coordinates exactly, without pivot round-trip error.
    _V rigidTransform(_V v) {
      final relative = v - pivot;
      return v +
          (relative.rotate(rotationX, rotationY, rotationZ) - relative) +
          shift;
    }

    _V transform(_V v) => _V.lerp(
      rigidTransform(v),
      v,
      _retention(fragment, v.xy, fragmentProgress),
    );
    final projectedOuter = outer.map(transform).toList();
    final projectedInner = inner.map(transform).toList();
    return _FragmentGeometry(
      outer: outer,
      projectedOuter: projectedOuter,
      projectedInner: projectedInner,
      center: center,
      transform: transform,
      rigidTransform: rigidTransform,
      flight: flight,
      shift: shift,
      rotation: _V(rotationX, rotationY, rotationZ),
      bounce: bounce,
      lift: lift,
    );
  }

  @visibleForTesting
  List<double> debugOcclusionDepths() =>
      _geometry(_referenceFragment).occlusionDepths(_surface);

  // Growth is measured in material coordinates, never in the deformed pose.
  // Use the exact boundary vertices of the mobile mesh. A growing endpoint
  // interpolates on its current triangle edge, including pinned attachments.
  Path _mobileCrack(
    List<Offset> points,
    double growth,
    _FragmentGeometry geometry,
  ) {
    var length = 0.0;
    for (var i = 1; i < points.length; i++) {
      length += (points[i] - points[i - 1]).distance;
    }
    var remaining = length * growth;
    final start = geometry.transform(_surface(points.first)).xy;
    final path = Path()..moveTo(start.dx, start.dy);
    for (var i = 1; i < points.length && remaining > 0; i++) {
      final a = points[i - 1], b = points[i];
      final distance = (b - a).distance;
      final samples = [..._edgeSamples(a, b), _surface(b)];
      final stepLength = distance / (samples.length - 1);
      for (var j = 1; j < samples.length && remaining > 0; j++) {
        final p = _V
            .lerp(
              geometry.transform(samples[j - 1]),
              geometry.transform(samples[j]),
              math.min(1, remaining / stepLength),
            )
            .xy;
        path.lineTo(p.dx, p.dy);
        remaining -= stepLength;
      }
    }
    return path;
  }

  FragmentGeometrySnapshot _debugGeometryFor(_FragmentSpec fragment) {
    final g = _geometry(fragment);
    var minimumAreaRatio = double.infinity;
    for (var i = 0; i < g.mesh.length; i += 3) {
      double area(List<_V> points) {
        final a = points[1].xy - points[0].xy;
        final b = points[2].xy - points[0].xy;
        return a.dx * b.dy - a.dy * b.dx;
      }

      final triangle = g.mesh.sublist(i, i + 3);
      minimumAreaRatio = math.min(
        minimumAreaRatio,
        area(triangle.map(g.transform).toList()) / area(triangle),
      );
    }
    return FragmentGeometrySnapshot(
      g.outer.map((v) => (v.x, v.y, v.z)).toList(),
      g.projectedOuter.map((v) => (v.x, v.y, v.z)).toList(),
      g.outer.map((v) => _retention(fragment, v.xy, progress)).toList(),
      fragment.attachments
          .map((a) => _attachmentHold(fragment, a, progress))
          .toList(),
      g.outer.map((v) {
        final p = g.rigidTransform(v);
        return (p.x, p.y, p.z);
      }).toList(),
      minimumAreaRatio,
      g.projectedInner.map((v) => (v.x, v.y, v.z)).toList(),
    );
  }

  @visibleForTesting
  FragmentGeometrySnapshot debugGeometry() =>
      _debugGeometryFor(_referenceFragment);

  @visibleForTesting
  FragmentFlightSnapshot debugFragmentFlight(int index) {
    final fragment = _fragments[index];
    final g = _geometry(fragment);
    final normal = _surfaceNormal(fragment.centerOnShell);
    return FragmentFlightSnapshot(
      _debugGeometryFor(fragment),
      g.flight,
      g.lift,
      (g.shift.x, g.shift.y, g.shift.z),
      (g.rotation.x, g.rotation.y, g.rotation.z),
      _detachmentProgress(fragment),
      (normal.x, normal.y, normal.z),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final initialTransform = identifySurfaces && onDiagnostics != null
        ? Matrix4.fromFloat64List(canvas.getTransform())
        : null;
    // Uniform scale: changing the phone ratio reveals more vertical space.
    final scale = size.width / 390;
    final height = size.height / scale;
    canvas.save();
    canvas.scale(scale);
    final bounds = Rect.fromLTWH(0, 0, 390, height);
    canvas.drawRect(
      bounds,
      Paint()
        ..color = identifySurfaces
            ? FragmentSurfaceColors.background
            : Colors.white
        ..shader = identifySurfaces
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xff463a30),
                  Color(0xffa08562),
                  Color(0xffd4b985),
                ],
              ).createShader(bounds),
    );
    final base = height * .82;
    canvas.drawRect(
      Rect.fromLTWH(0, base, 390, height - base),
      Paint()
        ..color = _surfaceColor(
          const Color(0xffb99a68),
          FragmentSurfaceColors.background,
        ),
    );
    // Fixed seed and fixed coordinates: background never moves or flickers.
    final random = math.Random(14);
    for (var i = 0; i < 100; i++) {
      final x = random.nextDouble() * 390;
      final y = base + random.nextDouble() * (height - base);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + random.nextDouble() * 35 - 17, y - 5),
        Paint()
          ..color = _surfaceColor(
            const Color(0xffe1c58d),
            FragmentSurfaceColors.background,
          )
          ..strokeWidth = 1.5,
      );
    }
    final origin = Offset(186, base - 220);
    if (shadow) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(origin.dx, base + 3),
          width: 214,
          height: 22,
        ),
        Paint()
          ..color = _surfaceColor(
            const Color(0x55453221),
            FragmentSurfaceColors.shadow,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    // Whole-body motion has rounded acceleration and rests between episodes;
    // local shell pressure remains on its own, quicker schedule.
    final bodyTilt = _bodyEpisodes.fold(
      0.0,
      (sum, episode) => sum + episode.tilt * episode.weight(progress),
    );
    final bodyRise = _bodyEpisodes.fold(
      0.0,
      (sum, episode) => sum + episode.rise * episode.weight(progress),
    );
    final wobble = .01 * motion * bodyTilt;
    canvas.translate(0, -1.8 * motion * bodyRise);
    canvas.translate(0, 220);
    canvas.rotate(wobble);
    canvas.translate(0, -220);
    final egg = Path()
      ..moveTo(0, -_eggHalfHeight)
      // Reference-like egg profile: softer crown, fuller middle/lower body,
      // rounded base. Height and floor contact stay unchanged.
      ..cubicTo(56, -220, 100, -150, 122, -60)
      ..cubicTo(134, 0, 132, 105, 112, 168)
      ..cubicTo(94, 208, 58, 220, 0, 220)
      ..cubicTo(-58, 220, -94, 208, -112, 168)
      ..cubicTo(-132, 105, -134, 0, -122, -60)
      ..cubicTo(-100, -150, -56, -220, 0, -_eggHalfHeight)
      ..close();
    // Build all fragment frames first. Even with a single validated fragment
    // active today, shell ownership and openings are now aggregated from a
    // list so adding another fragment does not require changing those rules.
    final frames = <_FragmentFrame>[
      for (final fragment in _fragments)
        (() {
          final geometry = _geometry(fragment);
          final aperture = _polygon(geometry.outer.map((v) => v.xy));
          final silhouette = _polygon(geometry.projectedOuter.map((v) => v.xy));
          final gap = combineFragmentOcclusionPaths(
            PathOperation.difference,
            aperture,
            silhouette,
          );
          return _FragmentFrame(
            spec: fragment,
            geometry: geometry,
            aperture: aperture,
            silhouette: silhouette,
            gap: gap,
          );
        })(),
    ];

    final allApertures = _unionPaths(frames.map((frame) => frame.aperture));
    final allGaps = _unionPaths(frames.map((frame) => frame.gap));
    // Fixed ownership from rest: subtract every fragment aperture from the
    // shell exactly once. This is the seam needed by true multi-fragments.
    final shell = combineFragmentOcclusionPaths(
      PathOperation.difference,
      egg,
      allApertures,
    );
    // Fixed-shell details must also obey the live 3D occlusion of ALL mobile
    // plates. Only the fragment portions that are actually in front of the
    // shell mask fixed grain/cracks/scars; parts behind the shell do not.
    final allVisibleFragments = _unionPaths(
      frames.map((frame) => frame.geometry.visibility(shell, _surface)),
    );
    final globalFixedShellVisible = combineFragmentOcclusionPaths(
      PathOperation.difference,
      shell,
      allVisibleFragments,
    );

    // The cavity is one GLOBAL background surface of the egg. Paint the union
    // of all visible openings once, before any mobile plate. Previously every
    // fragment repainted its own cavity inside paintFrame(); a later fragment
    // could therefore paint its "hole" over an earlier plate and make that
    // plate appear to pass behind the opening.
    if (showEgg && frames.isNotEmpty) {
      canvas.save();
      canvas.clipPath(allGaps);
      canvas.drawVertices(
        frames.first.geometry.material.cavityMesh(thickness, identifySurfaces),
        BlendMode.modulate,
        Paint()..color = Colors.white,
      );
      if (!identifySurfaces) {
        canvas.drawPath(
          allGaps,
          Paint()
            ..color = const Color(0x2b2f1d14)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 11
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
      }
      canvas.restore();
    }

    FragmentPaintDiagnostics? diagnosticsForCallback;

    void paintFrame(_FragmentFrame frame, {required bool paintSharedShell}) {
      final fragment = frame.spec;
      final fragmentProgress = progress;
      final geometry = frame.geometry;
      final outer = geometry.outer;
      final projectedOuter = geometry.projectedOuter;
      final projectedInner = geometry.projectedInner;
      final flight = geometry.flight;
      final shift = geometry.shift;
      final bounce = geometry.bounce;
      final lift = geometry.lift;
      final aperture = frame.aperture;
      final silhouette = frame.silhouette;
      final gap = frame.gap;
      FragmentPaintDiagnostics? diagnostics;
      if (onDiagnostics != null) {
        var maxGap = 0.0;
        for (var i = 0; i < outer.length; i++) {
          maxGap = math.max(
            maxGap,
            (projectedOuter[i].xy - outer[i].xy).distance,
          );
        }
        diagnostics = FragmentPaintDiagnostics(
          progress,
          gap,
          aperture,
          lift,
          maxGap,
          fragment.attachments
              .map((a) => _attachmentHold(fragment, a, fragmentProgress))
              .toList(),
          size,
        );
        // The public diagnostic callback remains tied to the validated reference
        // fragment; render order is now spatial and can change every frame.
        if (identical(fragment, _referenceFragment)) {
          diagnosticsForCallback ??= diagnostics;
        }
        if (initialTransform != null) {
          // Remove parent widget transforms: the probe uses preview-local pixels.
          final eggToCanvas = Matrix4.inverted(initialTransform)
            ..multiply(Matrix4.fromFloat64List(canvas.getTransform()));
          diagnostics.probe = FragmentSurfaceProbe(
            egg: egg,
            aperture: aperture,
            opening: gap,
            outer: silhouette,
            inner: _polygon(projectedInner.map((v) => v.xy)),
            showEgg: showEgg,
            eggToCanvas: eggToCanvas,
            positions: geometry.projectedPositions,
            indices: geometry.material.indices,
            textureCoordinates: geometry.material.textureCoordinates,
            depthChanges: () => geometry.occlusionDepths(_surface),
            shellTriangles: geometry.shellMesh,
          );
          if (shadow) {
            final floorToEgg = Matrix4.inverted(eggToCanvas)
              ..scaleByDouble(scale, scale, 1, 1);
            diagnostics.probe!.shadows.add((
              (Path()..addOval(
                    Rect.fromCenter(
                      center: Offset(origin.dx, base + 3),
                      width: 195,
                      height: 22,
                    ),
                  ))
                  .transform(floorToEgg.storage),
              null,
              9,
            ));
          }
        }
        diagnostics.meshSummary = () {
          var longestTriangleEdge = 0.0, longestBoundaryEdge = 0.0;
          final indices = geometry.material.indices;
          for (var i = 0; i < indices.length; i += 3) {
            for (var j = 0; j < 3; j++) {
              final a = geometry.projectedPositions[indices[i + j]];
              final b = geometry.projectedPositions[indices[i + (j + 1) % 3]];
              longestTriangleEdge = math.max(
                longestTriangleEdge,
                (b - a).distance,
              );
            }
          }
          for (var i = 0; i < projectedOuter.length; i++) {
            longestBoundaryEdge = math.max(
              longestBoundaryEdge,
              (projectedOuter[(i + 1) % projectedOuter.length].xy -
                      projectedOuter[i].xy)
                  .distance,
            );
          }
          return {
            'longestTriangleEdge': longestTriangleEdge,
            'longestBoundaryEdge': longestBoundaryEdge,
          };
        };
      }
      final shellShader = const RadialGradient(
        center: Alignment(-.5, -.6),
        radius: 1.4,
        colors: [Color(0xffffd8a0), Color(0xffd69b62), Color(0xff956039)],
      ).createShader(const Rect.fromLTWH(-115, -220, 230, 440));
      final faces = <_Face>[];
      // Preserve the validated lighting samples despite boundary subdivision.
      final third = fragment.fractureBoundary.length ~/ 3;
      final lightSamples = [
        _surface(fragment.fractureBoundary[0]),
        _surface(fragment.fractureBoundary[third]),
        _surface(fragment.fractureBoundary[2 * third]),
      ];
      final outerLight = _diffuse(
        lightSamples.map(geometry.transform).toList(),
      );
      final restingLight = _diffuse(lightSamples);
      final lightChange = outerLight - restingLight;
      final outerFace = _Face(
        projectedOuter,
        Colors.white,
        shader: shellShader,
        shade: (-lightChange * .48).clamp(0.0, .22),
        highlight: (lightChange * .28).clamp(0.0, .15),
      );
      final innerFace = _Face(
        projectedInner.reversed.toList(),
        const Color(0xffe7c79e),
        shade:
            .06 +
            .2 *
                (1 -
                    _diffuse([
                      geometry.transform(
                        _V(
                          lightSamples[1].x,
                          lightSamples[1].y,
                          lightSamples[1].z - thickness,
                        ),
                      ),
                      geometry.transform(
                        _V(
                          lightSamples[0].x,
                          lightSamples[0].y,
                          lightSamples[0].z - thickness,
                        ),
                      ),
                      geometry.transform(
                        _V(
                          lightSamples[2].x,
                          lightSamples[2].y,
                          lightSamples[2].z - thickness,
                        ),
                      ),
                    ])),
      );
      faces.addAll([outerFace, innerFace]);
      diagnostics?.surfaces.addAll({
        'outerSignedArea': outerFace.screenArea / 2,
        'innerSignedArea': innerFace.screenArea / 2,
        'outerDiffuse': outerLight,
        'restingDiffuse': restingLight,
        'outerShade': outerFace.shade,
        'outerHighlight': outerFace.highlight,
        'fragmentSeed': fragment.seed.toDouble(),
        'clusterSeed': fragment.cluster.seed.toDouble(),
        'meshVertices': geometry.material.vertices.length.toDouble(),
        'meshTriangles': geometry.material.indices.length / 3,
      });
      for (var i = 0; i < outer.length; i++) {
        final j = (i + 1) % outer.length;
        final edgePoint = _V.lerp(outer[i], outer[j], .5);
        // Intact material has no free rim. Buried thickness is not visible.
        if (_retention(fragment, edgePoint.xy, fragmentProgress) == 1 ||
            lift == 0) {
          continue;
        }
        _V visibleInner(int index) {
          final top = projectedOuter[index];
          final bottom = projectedInner[index];
          final exposedDepth = (top.z - _surface(top.xy).z).clamp(
            0.0,
            thickness,
          );
          final fraction = shell.contains(top.xy)
              ? exposedDepth / thickness
              : 1.0;
          return _V.lerp(top, bottom, fraction);
        }

        final rimFace = [
          projectedOuter[i],
          visibleInner(i),
          visibleInner(j),
          projectedOuter[j],
        ];
        faces.add(
          _Face(
            rimFace,
            const Color(0xffbd875a),
            shade: .1 + .3 * (1 - _diffuse(rimFace)),
          ),
        );
      }
      faces.sort((a, b) => a.depth.compareTo(b.depth));
      final visibility = showEgg
          ? geometry.visibility(shell, _surface)
          : (Path()..addRect(const Rect.fromLTRB(-1000, -1000, 1000, 1000)));
      final materialVisibility = _MaterialVisibility(
        shell,
        visibility,
        faces,
        outerFace,
      );
      if (showEgg && paintSharedShell) {
        canvas.save();
        canvas.clipPath(shell);
        canvas.drawVertices(
          ui.Vertices(
            ui.VertexMode.triangles,
            geometry.shellMesh,
            textureCoordinates: geometry.shellMesh,
          ),
          BlendMode.srcOver,
          Paint()
            ..color = identifySurfaces
                ? FragmentSurfaceColors.shell
                : Colors.white
            ..shader = identifySurfaces ? null : shellShader,
        );
        canvas.restore();
      }
      void paintFixedGrain(Path visibleMaterial) {
        canvas.save();
        canvas.clipPath(visibleMaterial);
        final darkGrain = Paint()
          ..color = _surfaceColor(
            const Color(0x16825234),
            FragmentSurfaceColors.shell,
          );
        final lightGrain = Paint()
          ..color = _surfaceColor(
            const Color(0x14fff0d7),
            FragmentSurfaceColors.shell,
          );
        for (var i = 0; i < _grain.length; i++) {
          final spot = _grain[i];
          if (!shell.contains(spot)) continue;
          canvas.drawCircle(
            spot,
            .3 + .08 * (i % 5),
            i % 4 == 0 ? lightGrain : darkGrain,
          );
        }
        canvas.restore();
      }

      if (showEgg && paintSharedShell) {
        paintFixedGrain(globalFixedShellVisible);
      }
      if (shadow && flight > 0) {
        diagnostics?.probe?.shadows.add((
          Path()..addOval(
            Rect.fromCenter(
              center: Offset(geometry.center.x + shift.x, 222),
              width: 64,
              height: 10,
            ),
          ),
          null,
          6,
        ));
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(geometry.center.x + shift.x, 222),
            width: 64,
            height: 10,
          ),
          Paint()
            ..color = _surfaceColor(
              Color.fromRGBO(60, 40, 20, .08 + .2 * flight - .04 * bounce / 4),
              FragmentSurfaceColors.shadow,
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      if (shadow && showEgg) {
        // Project away from the existing upper-left light. Use displacement
        // relative to the SAME resting surface as depth clipping: mesh curvature
        // error must not create a contact shadow on an undeformed partition.
        var separation = 0.0;
        final projectedShadow = <Offset>[];
        for (var i = 0; i < outer.length; i++) {
          final rest = outer[i], moved = projectedOuter[i];
          final height = math.max(
            0.0,
            (moved.z - rest.z) - (_surface(moved.xy).z - _surface(rest.xy).z),
          );
          separation = math.max(separation, height);
          projectedShadow.add(
            moved.xy + const Offset(.35 / .82, .45 / .82) * height,
          );
        }
        // At contact the footprint coincides with the material and penumbra is
        // zero. The visible shadow therefore grows geometrically from the edge;
        // no time threshold or opacity ramp announces the mobile region.
        if (separation > 0) {
          // Keep the cast shadow readable while the fragment crosses in front
          // of the egg. The previous falloff became too faint at moderate
          // separation, making the detached fragment look pasted onto the shell.
          // Geometry still drives displacement and penumbra; only the optical
          // falloff is softened.
          final softness = .14 * separation;
          final opacity = .30 / (1 + separation / 28);
          // Only the footprint beyond the moving material reaches a visible
          // receiver. Subtract before rasterization: clipping coincident filled
          // silhouettes alone leaves an antialiased contact seam at zero gap.
          final exposedShadow = Path.combine(
            PathOperation.difference,
            _polygon(projectedShadow),
            silhouette,
          );
          diagnostics?.probe?.shadows.add((exposedShadow, shell, softness));
          canvas.save();
          canvas.clipPath(shell);
          canvas.drawPath(
            exposedShadow,
            Paint()
              ..color = _surfaceColor(
                Color.fromRGBO(48, 29, 16, opacity),
                FragmentSurfaceColors.shadow,
              )
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, softness),
          );
          canvas.restore();
        }
      }

      // One material partition from rest through flight, with constrained geometry.
      {
        canvas.save();
        if (showEgg) {
          canvas.clipPath(visibility);
          diagnostics?.fragmentVisibility = visibility;
          diagnostics?.probe?.visibility = visibility;
        }
        for (final face in faces) {
          // The inner face stays hidden until the fragment actually turns.
          if (face.screenArea <= 0) continue;
          final path = _polygon(face.vertices.map((v) => v.xy));
          diagnostics?.occludingFaces.add(path);
          final identity = identical(face, outerFace)
              ? FragmentSurfaceColors.outer
              : identical(face, innerFace)
              ? FragmentSurfaceColors.inner
              : FragmentSurfaceColors.rim;
          diagnostics?.probe?.faces.add((
            identical(face, outerFace)
                ? 'outer'
                : identical(face, innerFace)
                ? 'inner'
                : 'rim',
            path,
          ));
          final paint = Paint()
            ..color = _surfaceColor(face.color, identity)
            ..shader = identifySurfaces ? null : face.shader;
          if (identical(face, outerFace)) {
            // Carry the shell's original material coordinates through the pose.
            // At rest, this samples exactly the same spatial gradient as the egg.
            // No fragment-local gradient or lift-driven tint announces departure.
            canvas.drawVertices(
              ui.Vertices(
                ui.VertexMode.triangles,
                geometry.projectedPositions,
                textureCoordinates: geometry.material.textureCoordinates,
                indices: geometry.material.indices,
              ),
              BlendMode.srcOver,
              paint,
            );
          } else {
            canvas.drawPath(path, paint);
          }
          if (face.shade > 0) {
            canvas.drawPath(
              path,
              Paint()
                ..color = _surfaceColor(
                  Color.fromRGBO(38, 23, 12, face.shade),
                  identity,
                ),
            );
          }
          if (face.highlight > 0) {
            canvas.drawPath(
              path,
              Paint()
                ..color = _surfaceColor(
                  Color.fromRGBO(255, 238, 207, face.highlight),
                  identity,
                ),
            );
          }
        }
        final visibleSurface = outerFace.screenArea > 0
            ? outerFace
            : innerFace.screenArea > 0
            ? innerFace
            : null;
        if (visibleSurface != null) {
          if (identical(visibleSurface, outerFace)) {
            canvas.save();
            canvas.clipPath(materialVisibility.mobile);
            final darkGrain = Paint()
              ..color = _surfaceColor(
                const Color(0x16825234),
                FragmentSurfaceColors.outer,
              );
            final lightGrain = Paint()
              ..color = _surfaceColor(
                const Color(0x14fff0d7),
                FragmentSurfaceColors.outer,
              );
            for (var i = 0; i < _grain.length; i++) {
              final spot = _grain[i];
              if (!aperture.contains(spot)) continue;
              canvas.drawCircle(
                geometry.materialPoint(spot).xy,
                .3 + .08 * (i % 5),
                i % 4 == 0 ? lightGrain : darkGrain,
              );
            }
            canvas.restore();
          }
        }
        canvas.restore();
      }

      // The validated fixed lip uses the local shell normal. Geometry, exposure
      // and occlusion are shared by normal paint and surface identification.
      if (showEgg) {
        _V inset(_V p) {
          final normal = _V(
            p.x / (115 * 115),
            p.y / (220 * 220),
            p.z / (65 * 65),
          );
          final length = math.sqrt(
            normal.x * normal.x + normal.y * normal.y + normal.z * normal.z,
          );
          return p -
              _V(
                normal.x * thickness / length,
                normal.y * thickness / length,
                normal.z * thickness / length,
              );
        }

        final proposed = Path();
        final lipPositions = <Offset>[];
        final lipColors = <Color>[];
        for (var i = 0; i < outer.length; i++) {
          final a = outer[i], b = outer[(i + 1) % outer.length];
          final wall = [a, b, inset(b), inset(a)];
          if (_Face(wall, Colors.white).screenArea <= 0) continue;
          proposed.addPath(_polygon(wall.map((v) => v.xy)), Offset.zero);
          // The exposed shell cross-section is lighter than the cavity and
          // catches the same directional light as the other shell surfaces.
          // Reuse the inner-shell material instead of darkening it into the
          // cavity range: geometry, thickness and exposure stay unchanged.
          final shade = .06 + .18 * (1 - _diffuse(wall));
          final color = Color.alphaBlend(
            Color.fromRGBO(38, 23, 12, shade),
            const Color(0xffe7c79e),
          );
          for (final index in [0, 1, 2, 0, 2, 3]) {
            lipPositions.add(wall[index].xy);
            lipColors.add(color);
          }
          diagnostics?.fixedLipFaces.add(
            wall.map((v) => (v.x, v.y, v.z)).toList(),
          );
        }
        final covering = Path();
        for (final face in faces) {
          if (face.screenArea > 0) {
            covering.addPath(
              _polygon(face.vertices.map((v) => v.xy)),
              Offset.zero,
            );
          }
        }
        final localVisibleLip = combineFragmentOcclusionPaths(
          PathOperation.difference,
          combineFragmentOcclusionPaths(PathOperation.intersect, proposed, gap),
          combineFragmentOcclusionPaths(
            PathOperation.intersect,
            covering,
            visibility,
          ),
        );
        // A fixed shell lip belongs behind every mobile plate that is actually
        // in front of the shell. Without this final global subtraction, a thin
        // lip sliver can remain painted over F3 at shared-opening crossings.
        final visibleLip = combineFragmentOcclusionPaths(
          PathOperation.difference,
          localVisibleLip,
          allVisibleFragments,
        );
        diagnostics?.probe?.fixedLip = visibleLip;
        if (identifySurfaces) {
          canvas.drawPath(
            visibleLip,
            Paint()..color = FragmentSurfaceColors.fixedLip,
          );
        } else if (lipPositions.isNotEmpty) {
          canvas.save();
          canvas.clipPath(visibleLip);
          canvas.drawVertices(
            ui.Vertices(
              ui.VertexMode.triangles,
              lipPositions,
              colors: lipColors,
            ),
            BlendMode.modulate,
            Paint()..color = Colors.white,
          );
          canvas.restore();
        }
      }

      if (fragmentProgress > .25) {
        for (var i = 0; i < fragment.edgeRefs.length; i++) {
          final edgeRef = fragment.edgeRefs[i];
          final edge = fragment.cluster.edge(edgeRef);
          final growth = edge.advance.at(
            fragmentProgress,
            fragment.cluster.pressureEvents,
          );
          if (growth == 0) continue;
          final crackClip = materialVisibility.mobile;
          final crackPath = _mobileCrack(
            fragment.cluster.edgePoints(edgeRef),
            growth,
            geometry,
          );
          final crackPaint = Paint()
            ..color = const Color(0xff6c4430)
            ..style = PaintingStyle.stroke
            ..strokeWidth =
                (.45 + .25 * growth) * (1 - .8 * _smooth(_part(growth, .62, 1)))
            ..strokeCap = StrokeCap.round;
          diagnostics?.probe?.overlays.add(
            FragmentOverlayStroke(
              'mainCrack[$i]',
              crackPath,
              crackPaint,
              crackClip,
              owner: 'fragmentOuter',
            ),
          );
          canvas.save();
          canvas.clipPath(crackClip);
          canvas.drawPath(crackPath, crackPaint);
          canvas.restore();
        }
      }
      if (showEgg && paintSharedShell && fragmentProgress > .25) {
        canvas.save();
        canvas.clipPath(globalFixedShellVisible);
        for (var i = 0; i < fragment.cluster.branches.length; i++) {
          final crack = fragment.cluster.branches[i];
          final growth = crack.advance.at(
            fragmentProgress,
            fragment.cluster.pressureEvents,
          );
          if (growth == 0) continue;
          final branch = Path()..addPolygon(crack.points, false);
          final metric = branch.computeMetrics().first;
          final branchPath = metric.extractPath(0, metric.length * growth);
          final branchPaint = Paint()
            ..color = const Color(0xff765038)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .3 + .5 * growth
            ..strokeCap = StrokeCap.round;
          diagnostics?.probe?.overlays.add(
            FragmentOverlayStroke(
              'shellBranch[$i]',
              branchPath,
              branchPaint,
              globalFixedShellVisible,
            ),
          );
          canvas.drawPath(branchPath, branchPaint);
        }
        for (var i = 0; i < fragment.cluster.microBranches.length; i++) {
          final crack = fragment.cluster.microBranches[i];
          final growth = crack.advance.at(
            fragmentProgress,
            fragment.cluster.pressureEvents,
          );
          if (growth == 0) continue;
          final branch = Path()..addPolygon(crack.points, false);
          final metric = branch.computeMetrics().first;
          final branchPath = metric.extractPath(0, metric.length * growth);
          final branchPaint = Paint()
            ..color = const Color(0x88765038)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .32
            ..strokeCap = StrokeCap.round;
          diagnostics?.probe?.overlays.add(
            FragmentOverlayStroke(
              'microCrack[$i]',
              branchPath,
              branchPaint,
              globalFixedShellVisible,
            ),
          );
          canvas.drawPath(branchPath, branchPaint);
        }
        canvas.restore();
      }
      if (showEgg && lift > 0) {
        canvas.save();
        canvas.clipPath(globalFixedShellVisible);
        for (final attachment in fragment.attachments) {
          final broken =
              1 - _attachmentHold(fragment, attachment, fragmentProgress);
          if (broken <= 0) continue;
          final shellPoint = fragment.boundary[attachment.vertex];
          final scarEnd = Offset.lerp(shellPoint, attachment.scarEnd, broken)!;
          final scarPaint = Paint()
            ..color = const Color(0xff765038)
            ..strokeWidth = .75
            ..strokeCap = StrokeCap.round;
          diagnostics?.probe?.overlays.add(
            FragmentOverlayStroke(
              'attachmentScar[${attachment.vertex}]',
              Path()
                ..moveTo(shellPoint.dx, shellPoint.dy)
                ..lineTo(scarEnd.dx, scarEnd.dy),
              Paint()
                ..color = scarPaint.color
                ..strokeWidth = scarPaint.strokeWidth
                ..strokeCap = scarPaint.strokeCap
                ..style = PaintingStyle.stroke,
              globalFixedShellVisible,
            ),
          );
          canvas.drawLine(shellPoint, scarEnd, scarPaint);
        }
        canvas.restore();
      }
    }

    // Render back-to-front from CURRENT 3D depth. Fragment creation order,
    // fracture order and detachment order must never decide visual occlusion.
    // Seed is only a deterministic tie-breaker when two plate depths coincide.
    final paintFrames = [...frames]
      ..sort((a, b) {
        final depthOrder = a.paintDepth.compareTo(b.paintDepth);
        return depthOrder != 0
            ? depthOrder
            : a.spec.seed.compareTo(b.spec.seed);
      });
    for (var i = 0; i < paintFrames.length; i++) {
      paintFrame(paintFrames[i], paintSharedShell: i == 0);
    }

    canvas.restore();
    if (guides) {
      final p = Paint()
        ..color = const Color(0x55ffffff)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(195, 0), Offset(195, height), p);
      canvas.drawLine(Offset(0, base), Offset(390, base), p);
    }
    final text = TextPainter(
      text: const TextSpan(
        text: 'ÉCLOSION\nÉtude de fragment · matière provisoire',
        style: TextStyle(color: Color(0xfff9e9cc), fontSize: 14, height: 1.8),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 350);
    text.paint(canvas, Offset((390 - text.width) / 2, 32));
    canvas.restore();
    if (diagnosticsForCallback != null) {
      onDiagnostics!(diagnosticsForCallback!);
    }
  }

  @override
  bool shouldRepaint(covariant FragmentScene old) =>
      progress != old.progress ||
      thickness != old.thickness ||
      motion != old.motion ||
      guides != old.guides ||
      showEgg != old.showEgg ||
      identifySurfaces != old.identifySurfaces ||
      shadow != old.shadow;
}
