import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'fragment_surface_probe.dart';
export 'fragment_surface_probe.dart' show FragmentSurfaceColors;

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
  const _PressureEvent(this.center, this.halfWidth, this.strength, this.point);
  final double center, halfWidth, strength;
  final Offset point;
  double at(double t) => strength * _pulse(t, center, halfWidth);
  double advance(double t) => _part(t, center - halfWidth, center + halfWidth);
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
    ? 'Coquille intacte'
    : t < .495
    ? 'Propagation de la fissure'
    : t < .6
    ? 'Soulèvement du fragment'
    : t < 1
    ? 'Chute du fragment'
    : 'Fragment au sol';

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
  ui.Vertices cavityMesh(double thickness, bool identify) =>
      _cavityMeshes.putIfAbsent((thickness, identify), () {
        final rx = 115 - thickness, ry = 220 - thickness, rz = 65 - thickness;

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
            final radialSquared =
                x * x / (rx * rx) + y * y / (ry * ry);
            final inside = radialSquared <= 1.0;
            final z = inside
                ? -rz * math.sqrt(math.max(0.0, 1 - radialSquared))
                : 0.0;

            final perspective = cameraDistance / (cameraDistance - z);
            positions.add(Offset(x * perspective, y * perspective));

            if (!inside) {
              colors.add(
                identify
                    ? FragmentSurfaceColors.cavity
                    : const Color(0xff9b7060),
              );
              continue;
            }

            final nx = -x / (rx * rx),
                ny = -y / (ry * ry),
                nz = -z / (rz * rz);
            final normalLength = math.sqrt(nx * nx + ny * ny + nz * nz);
            final diffuse =
                ((-.35 * nx - .45 * ny + .82 * nz) / normalLength).clamp(
                  0.0,
                  1.0,
                );

            // Optical depth through the hollow egg: at this screen point,
            // the ray travels from the front inner shell to the rear inner
            // wall. That chord length is a GLOBAL property of the egg and is
            // independent of every fragment/opening. Longer travel means less
            // light reaches the far wall; nearer side regions remain lighter.
            final opticalDepth = (-z / rz).clamp(0.0, 1.0);
            final sideExposure =
                math.pow((1 - opticalDepth).clamp(0.0, 1.0), .22);
            final directionalRelief = .035 * (diffuse - .5);
            final exposure =
                (.22 +
                        .46 * sideExposure -
                        .08 * opticalDepth +
                        directionalRelief)
                    .clamp(.20, .56);

            final innerShell = Color.lerp(
              const Color(0xff9b7060),
              const Color(0xfff0d8c0),
              exposure,
            )!;
            colors.add(
              identify ? FragmentSurfaceColors.cavity : innerShell,
            );
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
    required this.bounce,
    required this.lift,
  }) : material = _materials[outer] ??= _MaterialMesh(outer, center);

  // The immutable boundary is shared across frames; the pose is not cached.
  static final _materials = Expando<_MaterialMesh>();
  final _MaterialMesh material;
  final List<_V> outer, projectedOuter, projectedInner;
  final _V center, shift;
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
    required this.edges,
    required this.branches,
    required this.microBranches,
  });

  final int seed;
  final List<_PressureEvent> pressureEvents;
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
          event.at(t) * _spatialWeight(event.point, point, radius: 70);
    }
    return pressure;
  }

  // Shell response keeps a short mechanical tail after each internal impulse.
  // This is not a fragment timer: it is the relaxation of the same shared
  // pressure event after the chick stops pushing.
  double responseAt(double t, Offset point) {
    var response = 0.0;
    for (final event in pressureEvents) {
      final weight = _spatialWeight(event.point, point, radius: 70);
      final end = event.center + event.halfWidth;
      final relaxation =
          t <= end
              ? 0.0
              : .35 *
                    event.strength *
                    (1 - _smoother(_part(t, end, end + .055)));
      response += (event.at(t) + relaxation) * weight;
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
          _spatialWeight(event.point, point);
    }
    return damage;
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
      for (final step in steps)
        a + direction * step.dx + normal * step.dy,
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
  ];
  // Pressure has a location independent of the fragment's geometric center.
  // More events or pressure zones can use the same data without changing the
  // rigid fragment representation.
  static const _pressureEvents = [
    _PressureEvent(.27, .02, .3, Offset(62, -87)),
    _PressureEvent(.327, .016, .42, Offset(14, -72)),
    _PressureEvent(.378, .014, .52, Offset(66, -62)),
    _PressureEvent(.43, .013, .68, Offset(25, -48)),
    _PressureEvent(.448, .013, .42, Offset(70, -71)),
    _PressureEvent(.482, .013, .34, Offset(63, -81)),
    _PressureEvent(.51, .015, .48, Offset(66, -62)),
    _PressureEvent(.554, .013, .66, Offset(28, -48)),
    _PressureEvent(.59, .01, .9, Offset(70, -70)),
  ];
  static const _clusterPressureEvents = [
    ..._pressureEvents,
    // Common local push close to the shared seam. Existing reference edges keep
    // their original pressure indices; neighbouring edges can react to this
    // same physical impulse without owning an independent timer.
    _PressureEvent(.515, .022, .7, Offset(-4, -67)),
    // After the first plate opens, the chick pushes again through the enlarged
    // weak zone. This shared impulse transfers load toward the neighbour's last
    // hinge and can finish its release through accumulated cluster damage.
    _PressureEvent(.665, .024, .95, Offset(-34, -52)),
  ];
  static const _liftPushes = [
    _LiftPush(.495, .514, .16, Offset(63, -81)),
    _LiftPush(.524, .542, .25, Offset(66, -62)),
    _LiftPush(.552, .57, .27, Offset(28, -48)),
    _LiftPush(.583, .6, .32, Offset(70, -70)),
  ];
  // The left and upper edge resists pressure applied mostly on the right.
  // Each connection gives way during a different lift episode.
  static const _attachments = [
    _ShellAttachment(10, .524, .542, Offset(-22, -77)),
    _ShellAttachment(8, .552, .57, Offset(15, -22)),
    _ShellAttachment(0, .583, .6, Offset(6, -120)),
  ];
  static final _grain = _makeGrain();

  static List<Offset> _makeGrain() {
    final random = math.Random(37);
    return List.generate(
      520,
      (_) => Offset(
        -115 + 230 * random.nextDouble(),
        -220 + 440 * random.nextDouble(),
      ),
    );
  }

  static _V _surface(Offset p) => _V(
    p.dx,
    p.dy,
    65 *
        math.sqrt(
          math.max(0, 1 - math.pow(p.dx / 115, 2) - math.pow(p.dy / 220, 2)),
        ),
  );

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
    const Offset(-9, -43),
    const Offset(-28, -35),
    const Offset(-43, -47),
    const Offset(-39, -66),
    const Offset(-24, -80),
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
    _CrackAdvance(8, .55, 1),
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
        _neighborFractureBoundary[
            (i + 1) % _neighborFractureBoundary.length],
      ),
  ];

  // These attachments intentionally survive beyond this diagnostic animation.
  // They model a neighbouring plate that cracks under the common pressure but
  // has not yet accumulated enough damage to detach.
  static const _neighborAttachments = <_ShellAttachment>[
    // Close to the shared pressure zone: these ligaments accumulate enough
    // damage to release first.
    _ShellAttachment(
      2,
      1.05,
      1.08,
      Offset(-8, -31),
      damageStart: .45,
      damageEnd: .75,
    ),
    // Farther from the pressure source: this remains the local hinge.
    _ShellAttachment(
      4,
      1.10,
      1.13,
      Offset(-49, -45),
      damageStart: .55,
      damageEnd: .85,
    ),
    _ShellAttachment(
      6,
      1.15,
      1.18,
      Offset(-27, -87),
      damageStart: .35,
      damageEnd: .60,
    ),
  ];

  // Shared fracture topology. Fragments reference edge ids from this cluster;
  // edge 9 is therefore literally one crack used by both neighbouring plates.
  static final _fractureCluster = _FractureClusterSpec(
    seed: 1,
    pressureEvents: _clusterPressureEvents,
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
    centerOnShell: const Offset(-22, -58),
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

  static final List<_FragmentSpec> _fragments = [
    _referenceFragment,
    _neighborFragment,
  ];

  static List<_V> _edgeSamples(Offset a, Offset b) {
    final count = ((b - a).distance / 2).ceil();
    return [
      for (var i = 0; i < count; i++)
        _V.lerp(_surface(a), _surface(b), i / count),
    ];
  }

  double _attachmentHold(
    _FragmentSpec fragment,
    _ShellAttachment attachment,
    double fragmentProgress,
  ) {
    final attachmentPoint = fragment.boundary[attachment.vertex];
    final damage = fragment.cluster.damageAt(
      fragmentProgress,
      attachmentPoint,
    );
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
      (attachment) => _attachmentHold(fragment, attachment, t) <= .001,
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
    for (final attachment in fragment.attachments) {
      final distance =
          (point - fragment.boundary[attachment.vertex]).distance;
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
      final weight = 1 - _smooth(_part(distance, 4, 40));
      retained = math.max(retained, elasticMemory * weight);
    }
    return retained;
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
        fragment.cluster.responseAt(
          fragmentProgress,
          fragment.centerOnShell,
        ) *
        (1 + .65 * coupledReleasedShare);
    final lift =
        (fragment.liftPushes.fold(
              0.0,
              (sum, push) => sum + push.at(fragmentProgress),
            ) +
                pressureLift -
                .025 * _pulse(fragmentProgress, .519, .005) -
                .02 * _pulse(fragmentProgress, .547, .005) -
                .015 * _pulse(fragmentProgress, .576, .006))
            .clamp(0.0, 1.0);
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
    final pressureRoll = fragment.liftPushes.fold(
      0.0,
      (sum, push) => sum + push.at(fragmentProgress) * (push.point.dx - center.x) / 45,
    );
    final pressurePitch = fragment.liftPushes.fold(
      0.0,
      (sum, push) => sum + push.at(fragmentProgress) * (push.point.dy - center.y) / 45,
    );
    final initialTorqueFade = 1 - turn;
    // Rotation never reaches an edge-on projection. The small damped roll and
    // lift after impact let the light shell settle on a broad face.
    final impactPitch = fragment.impactPitch;
    final impactYaw = fragment.impactYaw;
    final impactRoll = fragment.impactRoll;
    final rotationX =
        -.38 * lift +
        (impactPitch + .38) * turn +
        .25 * settle +
        (.03 + .01 * releasedShare) * pressurePitch * initialTorqueFade;
    final rotationY =
        .45 * lift + (impactYaw - .45) * turn - .4 * settle + .03 * recoil;
    final rotationZ =
        impactRoll * turn -
        .5 * settle +
        .05 * recoil -
        (.14 + .025 * releasedShare) * pressureRoll * initialTorqueFade;
    _V rotate(_V v) =>
        (v - pivot).rotate(rotationX, rotationY, rotationZ) + pivot - center;
    final outer = fragment.materialBoundary;
    final inner = outer.map((v) => _V(v.x, v.y, v.z - thickness)).toList();
    final rotated = [...outer, ...inner].map(rotate).toList();
    final bottom = rotated.map((v) => v.y).reduce(math.max);
    final impactBottom = [...outer, ...inner]
        .map((v) => (v - center).rotate(impactPitch, impactYaw, impactRoll).y)
        .reduce(math.max);
    final impactLandingY = 220 - center.y - impactBottom;
    // A fixed landing target gives the airborne piece a quadratic gravity arc.
    // After impact, the lowest vertex remains on the floor as the shell rocks.
    final ballisticY =
        -12 * lift * lift * (1 - flight) -
        20 * flight +
        (impactLandingY + 20) * flight * flight;
    final groundedY = 220 - center.y - bottom;
    final shift = _V(
      fragment.flightShiftX * flight + fragment.settleShiftX * settle,
      (settle > 0 ? groundedY : ballisticY) - bounce,
      22 * lift * lift,
    );
    // Express the pose as a displacement. A zero rotation/translation must
    // preserve material coordinates exactly, without pivot round-trip error.
    _V rigidTransform(_V v) {
      final relative = v - pivot;
      return v +
          (relative.rotate(rotationX, rotationY, rotationZ) - relative) +
          shift;
    }

    _V transform(_V v) =>
        _V.lerp(rigidTransform(v), v, _retention(fragment, v.xy, fragmentProgress));
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
      bounce: bounce,
      lift: lift,
    );
  }

  @visibleForTesting
  List<double> debugOcclusionDepths() => _geometry(_referenceFragment).occlusionDepths(_surface);

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

  @visibleForTesting
  FragmentGeometrySnapshot debugGeometry() {
    final fragment = _referenceFragment;
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
      g.outer
          .map((v) => _retention(fragment, v.xy, progress))
          .toList(),
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
          width: 195,
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
      ..moveTo(0, -220)
      ..cubicTo(69, -220, 115, -52, 115, 75)
      ..cubicTo(115, 181, 75, 220, 0, 220)
      ..cubicTo(-75, 220, -115, 181, -115, 75)
      ..cubicTo(-115, -52, -69, -220, 0, -220)
      ..close();
    // Build all fragment frames first. Even with a single validated fragment
    // active today, shell ownership and openings are now aggregated from a
    // list so adding another fragment does not require changing those rules.
    final frames = <_FragmentFrame>[
      for (final fragment in _fragments)
        (() {
          final geometry = _geometry(fragment);
          final aperture = _polygon(geometry.outer.map((v) => v.xy));
          final silhouette = _polygon(
            geometry.projectedOuter.map((v) => v.xy),
          );
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
    // Fixed ownership from rest: subtract every fragment aperture from the
    // shell exactly once. This is the seam needed by true multi-fragments.
    final shell = combineFragmentOcclusionPaths(
      PathOperation.difference,
      egg,
      allApertures,
    );

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
      // The public diagnostic callback is still singular. Keep the first frame
      // as the reference diagnostic while every frame is nevertheless painted.
      diagnosticsForCallback ??= diagnostics;
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
    final outerLight = _diffuse(lightSamples.map(geometry.transform).toList());
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
        final exposedDepth = (top.z - _surface(top.xy).z).clamp(0.0, thickness);
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
    if (showEgg) {
      canvas.save();
      // The existing uncovered geometry alone reveals the inner wall. Its
      // shading is fixed in egg coordinates and does not depend on progress.
      canvas.clipPath(gap);
      canvas.drawVertices(
        geometry.material.cavityMesh(thickness, identifySurfaces),
        BlendMode.modulate,
        Paint()..color = Colors.white,
      );

      // Soft inner-rim occlusion: the shell edge blocks part of the light
      // entering the egg, so the far inner wall is slightly darker close to
      // the visible opening boundary. This is an OPENING-lighting effect, not
      // fragment geometry; future multi-fragment rendering can apply the same
      // treatment to the union of all visible openings.
      if (!identifySurfaces) {
        canvas.drawPath(
          gap,
          Paint()
            ..color = const Color(0x2b2f1d14)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 11
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
      }
      canvas.restore();
      if (paintSharedShell) {
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
      paintFixedGrain(materialVisibility.fixed);
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
      final visibleLip = combineFragmentOcclusionPaths(
        PathOperation.difference,
        combineFragmentOcclusionPaths(PathOperation.intersect, proposed, gap),
        combineFragmentOcclusionPaths(
          PathOperation.intersect,
          covering,
          visibility,
        ),
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
          ui.Vertices(ui.VertexMode.triangles, lipPositions, colors: lipColors),
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
      canvas.clipPath(materialVisibility.fixed);
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
            materialVisibility.fixed,
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
            materialVisibility.fixed,
          ),
        );
        canvas.drawPath(branchPath, branchPaint);
      }
      canvas.restore();
    }
    if (showEgg && lift > 0) {
      canvas.save();
      canvas.clipPath(materialVisibility.fixed);
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
            materialVisibility.fixed,
          ),
        );
        canvas.drawLine(shellPoint, scarEnd, scarPaint);
      }
      canvas.restore();
    }

    }

    for (var i = 0; i < frames.length; i++) {
      paintFrame(frames[i], paintSharedShell: i == 0);
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
