import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'egg_shell_crack_network.dart';

class EggShellPoint3 {
  const EggShellPoint3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  EggShellPoint3 operator +(EggShellPoint3 other) =>
      EggShellPoint3(x + other.x, y + other.y, z + other.z);

  EggShellPoint3 operator -(EggShellPoint3 other) =>
      EggShellPoint3(x - other.x, y - other.y, z - other.z);

  EggShellPoint3 operator *(double factor) =>
      EggShellPoint3(x * factor, y * factor, z * factor);

  double get length => math.sqrt(x * x + y * y + z * z);

  EggShellPoint3 get normalized {
    final value = length;
    if (value == 0) return const EggShellPoint3(0, 0, 1);
    return EggShellPoint3(x / value, y / value, z / value);
  }

  Offset get xy => Offset(x, y);
}

class _EggProfileKnot {
  const _EggProfileKnot(this.v, this.radius);

  final double v;
  final double radius;
}

/// One geometric source of truth for the egg.
///
/// The 2D outline is the orthographic silhouette of this surface of revolution.
/// Fragments can later use [surfaceAt] and [normalAt] directly instead of being
/// authored on an unrelated 2D ellipse.
class EggShellModel {
  const EggShellModel({
    required this.halfHeight,
    required this.maxRadius,
    this.depthRatio = 1,
  });

  static const reference = EggShellModel(
    halfHeight: 220,
    maxRadius: 150,
    depthRatio: .92,
  );

  final double halfHeight;
  final double maxRadius;

  /// Depth radius / visible horizontal radius for each latitude.
  ///
  /// A value close to 1 keeps the shell volumetric while retaining the current
  /// 2.5D camera feel.
  final double depthRatio;

  // Measured from the validated white egg silhouette. The endpoints are closed
  // to zero so the surface itself, not a separate 2D path, owns crown and base.
  static const _profile = <_EggProfileKnot>[
    _EggProfileKnot(-1.00, 0.0000),
    _EggProfileKnot(-.98, .1811),
    _EggProfileKnot(-.95, .2652),
    _EggProfileKnot(-.90, .3703),
    _EggProfileKnot(-.80, .5052),
    _EggProfileKnot(-.70, .6065),
    _EggProfileKnot(-.60, .6912),
    _EggProfileKnot(-.50, .7603),
    _EggProfileKnot(-.40, .8198),
    _EggProfileKnot(-.30, .8689),
    _EggProfileKnot(-.20, .9111),
    _EggProfileKnot(-.10, .9439),
    _EggProfileKnot(0.00, .9721),
    _EggProfileKnot(.10, .9895),
    _EggProfileKnot(.20, .9980),
    _EggProfileKnot(.30, .9989),
    _EggProfileKnot(.40, .9917),
    _EggProfileKnot(.50, .9683),
    _EggProfileKnot(.60, .9305),
    _EggProfileKnot(.70, .8680),
    _EggProfileKnot(.80, .7721),
    _EggProfileKnot(.85, .7040),
    _EggProfileKnot(.90, .6131),
    _EggProfileKnot(.95, .4590),
    _EggProfileKnot(.98, .3238),
    _EggProfileKnot(1.00, 0.0000),
  ];

  double _profileSlope(int index) {
    if (index == 0) {
      final a = _profile[0];
      final b = _profile[1];
      return (b.radius - a.radius) / (b.v - a.v);
    }
    if (index == _profile.length - 1) {
      final a = _profile[index - 1];
      final b = _profile[index];
      return (b.radius - a.radius) / (b.v - a.v);
    }
    final a = _profile[index - 1];
    final b = _profile[index + 1];
    return (b.radius - a.radius) / (b.v - a.v);
  }

  double _normalizedRadius(double v) {
    final value = v.clamp(-1.0, 1.0).toDouble();
    if (value <= -1 || value >= 1) return 0;

    var segment = 0;
    while (segment < _profile.length - 2 &&
        value > _profile[segment + 1].v) {
      segment++;
    }

    final a = _profile[segment];
    final b = _profile[segment + 1];
    final span = b.v - a.v;
    final t = ((value - a.v) / span).clamp(0.0, 1.0).toDouble();

    final t2 = t * t;
    final t3 = t2 * t;
    final h00 = 2 * t3 - 3 * t2 + 1;
    final h10 = t3 - 2 * t2 + t;
    final h01 = -2 * t3 + 3 * t2;
    final h11 = t3 - t2;

    final radius =
        h00 * a.radius +
        h10 * span * _profileSlope(segment) +
        h01 * b.radius +
        h11 * span * _profileSlope(segment + 1);

    return radius.clamp(0.0, 1.01).toDouble();
  }

  double radiusAt(double y) =>
      maxRadius * _normalizedRadius(y / halfHeight);

  double depthRadiusAt(double y) => radiusAt(y) * depthRatio;

  double radiusDerivativeAt(double y) {
    const step = .5;
    final y0 = math.max(-halfHeight, y - step);
    final y1 = math.min(halfHeight, y + step);
    if (y1 == y0) return 0;
    return (radiusAt(y1) - radiusAt(y0)) / (y1 - y0);
  }

  EggShellPoint3 surfaceAt(double x, double y, {bool back = false}) {
    final radius = radiusAt(y);
    if (radius <= 1e-6) return EggShellPoint3(0, y, 0);

    final clampedX = x.clamp(-radius, radius).toDouble();
    final normalizedX = clampedX / radius;
    final depthRadius = depthRadiusAt(y);
    final z =
        depthRadius *
        math.sqrt(math.max(0.0, 1 - normalizedX * normalizedX)) *
        (back ? -1 : 1);
    return EggShellPoint3(clampedX, y, z);
  }

  EggShellPoint3 pointAt(double y, double angle) {
    final radius = radiusAt(y);
    final depthRadius = depthRadiusAt(y);
    return EggShellPoint3(
      radius * math.sin(angle),
      y,
      depthRadius * math.cos(angle),
    );
  }

  EggShellPoint3 normalAt(EggShellPoint3 point) {
    final radius = radiusAt(point.y);
    if (radius <= 1e-6) {
      return EggShellPoint3(0, point.y.sign, 0).normalized;
    }

    final derivative = radiusDerivativeAt(point.y);
    final depthScaleSquared = depthRatio * depthRatio;
    return EggShellPoint3(
      point.x,
      -radius * derivative,
      point.z / depthScaleSquared,
    ).normalized;
  }

  EggShellPoint3 inset(EggShellPoint3 point, double thickness) =>
      point - normalAt(point) * thickness;

  Path silhouettePath({int samples = 160}) {
    final path = Path()..moveTo(0, -halfHeight);
    for (var i = 1; i <= samples; i++) {
      final y = -halfHeight + 2 * halfHeight * i / samples;
      path.lineTo(radiusAt(y), y);
    }
    for (var i = samples - 1; i >= 0; i--) {
      final y = -halfHeight + 2 * halfHeight * i / samples;
      path.lineTo(-radiusAt(y), y);
    }
    return path..close();
  }
}

class EggShellModelPainter extends CustomPainter {
  const EggShellModelPainter({
    this.model = EggShellModel.reference,
    this.guides = false,
    this.shadow = true,
  });

  final EggShellModel model;
  final bool guides;
  final bool shadow;

  static const _shellLight = Color(0xffffd59b);
  static const _shellBase = Color(0xffe7ab70);
  static const _shellDark = Color(0xff9c633d);

  Color _shade(EggShellPoint3 normal) {
    const light = EggShellPoint3(-.38, -.48, .79);
    final diffuse =
        (normal.x * light.x + normal.y * light.y + normal.z * light.z)
            .clamp(-1.0, 1.0);
    final amount = ((diffuse + 1) * .5).clamp(0.0, 1.0).toDouble();
    if (amount < .48) {
      return Color.lerp(_shellDark, _shellBase, amount / .48)!;
    }
    return Color.lerp(
      _shellBase,
      _shellLight,
      (amount - .48) / .52,
    )!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff6f5b49), Color(0xffcbb07d)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final usableWidth = size.width * .76;
    final usableHeight = size.height * .80;
    final scale = math.min(
      usableWidth / (2 * model.maxRadius),
      usableHeight / (2 * model.halfHeight),
    );
    final origin = Offset(size.width / 2, size.height * .51);

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);

    if (shadow) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, model.halfHeight + 7),
          width: model.maxRadius * 1.55,
          height: 18,
        ),
        Paint()
          ..color = const Color(0x3d3e2a1c)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    const rows = 72;
    const columns = 44;
    final positions = <Offset>[];
    final colors = <Color>[];
    final indices = <int>[];

    for (var row = 0; row <= rows; row++) {
      final y = -model.halfHeight + 2 * model.halfHeight * row / rows;
      for (var column = 0; column <= columns; column++) {
        final angle = -math.pi / 2 + math.pi * column / columns;
        final point = model.pointAt(y, angle);
        positions.add(point.xy);
        colors.add(_shade(model.normalAt(point)));
      }
    }

    final stride = columns + 1;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final a = row * stride + column;
        final b = a + 1;
        final c = a + stride;
        final d = c + 1;
        indices.addAll([a, c, b, b, c, d]);
      }
    }

    canvas.drawVertices(
      ui.Vertices(
        ui.VertexMode.triangles,
        positions,
        colors: colors,
        indices: indices,
      ),
      BlendMode.srcOver,
      Paint()..color = Colors.white,
    );

    canvas.drawPath(
      model.silhouettePath(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .85 / scale
        ..color = const Color(0x554f301d),
    );

    if (guides) {
      final guidePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .65 / scale
        ..color = const Color(0x55ffffff);

      for (final fraction in const [-.75, -.5, -.25, 0.0, .25, .5, .75]) {
        final path = Path();
        var started = false;
        for (var i = 0; i <= 96; i++) {
          final y = -model.halfHeight + 2 * model.halfHeight * i / 96;
          final x = model.radiusAt(y) * fraction;
          if (!started) {
            path.moveTo(x, y);
            started = true;
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path, guidePaint);
      }

      for (final fraction in const [-.75, -.5, -.25, 0.0, .25, .5, .75]) {
        final y = model.halfHeight * fraction;
        final radius = model.radiusAt(y);
        canvas.drawLine(Offset(-radius, y), Offset(radius, y), guidePaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(EggShellModelPainter oldDelegate) =>
      oldDelegate.model != model ||
      oldDelegate.guides != guides ||
      oldDelegate.shadow != shadow;
}


class EggShellF1PreviewPainter extends CustomPainter {
  EggShellF1PreviewPainter({
    this.model = EggShellModel.reference,
    this.guides = false,
    this.shadow = true,
    this.thickness = 2.5,
    this.openAmount = .55,
    required this.seed,
  }) : _network = EggShellCrackNetwork(seed);

  final EggShellModel model;
  final bool guides;
  final bool shadow;
  final double thickness;
  final double openAmount;
  final int seed;
  final EggShellCrackNetwork _network;

  static const _shellLight = Color(0xffffd59b);
  static const _shellBase = Color(0xffe7ab70);
  static const _shellDark = Color(0xff9c633d);
  static const _cavity = Color(0xff8f6656);
  static const _innerShell = Color(0xffe4c1a0);
  static const _edgeShell = Color(0xffcf9b72);

  Color _shade(EggShellPoint3 normal) {
    const light = EggShellPoint3(-.38, -.48, .79);
    final diffuse =
        (normal.x * light.x + normal.y * light.y + normal.z * light.z)
            .clamp(-1.0, 1.0);
    final amount = ((diffuse + 1) * .5).clamp(0.0, 1.0).toDouble();
    if (amount < .48) {
      return Color.lerp(_shellDark, _shellBase, amount / .48)!;
    }
    return Color.lerp(
      _shellBase,
      _shellLight,
      (amount - .48) / .52,
    )!;
  }

  double _boundaryY(double angle) => _network.f1BoundaryY(angle);

  EggShellPoint3 _rotateX(EggShellPoint3 point, double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return EggShellPoint3(
      point.x,
      point.y * c - point.z * s,
      point.y * s + point.z * c,
    );
  }

  EggShellPoint3 _rotateZ(EggShellPoint3 point, double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return EggShellPoint3(
      point.x * c - point.y * s,
      point.x * s + point.y * c,
      point.z,
    );
  }

  EggShellPoint3 _transformPoint(EggShellPoint3 point) {
    final amount = openAmount.clamp(0.0, 1.0).toDouble();
    // The cap pivots from a rear crown hinge, so opening exposes a true curved
    // shell volume instead of translating a frontal plate.
    final hingeY = _boundaryY(math.pi);
    final hinge = model.pointAt(hingeY, math.pi);
    var local = point - hinge;
    local = _rotateX(local, .25 * amount);
    local = _rotateZ(local, -.035 * amount);
    return local +
        hinge +
        EggShellPoint3(-4 * amount, -2 * amount, -5 * amount);
  }

  EggShellPoint3 _transformNormal(EggShellPoint3 normal) {
    final amount = openAmount.clamp(0.0, 1.0).toDouble();
    var result = _rotateX(normal, .25 * amount);
    result = _rotateZ(result, -.035 * amount);
    return result.normalized;
  }

  Path _aperturePath() {
    const samples = 72;
    final path = Path();
    for (var i = 0; i <= samples; i++) {
      final angle = -math.pi / 2 + math.pi * i / samples;
      final point = model.pointAt(_boundaryY(angle), angle).xy;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    final rightBoundaryY = _boundaryY(math.pi / 2);
    for (var i = 0; i <= 48; i++) {
      final y = rightBoundaryY +
          (-model.halfHeight - rightBoundaryY) * i / 48;
      path.lineTo(model.radiusAt(y), y);
    }

    final leftBoundaryY = _boundaryY(-math.pi / 2);
    for (var i = 0; i <= 48; i++) {
      final y = -model.halfHeight +
          (leftBoundaryY + model.halfHeight) * i / 48;
      path.lineTo(-model.radiusAt(y), y);
    }
    return path..close();
  }

  void _drawCrackNetwork(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .68
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter
      ..color = const Color(0x5f76503a);

    for (final branch in _network.branches) {
      final path = Path();
      for (var i = 0; i < branch.points.length; i++) {
        final point = branch.points[i];
        final projected = model.pointAt(point.y, point.angle).xy;
        if (i == 0) {
          path.moveTo(projected.dx, projected.dy);
        } else {
          path.lineTo(projected.dx, projected.dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawCavity(Canvas canvas) {
    final aperture = _aperturePath();

    // Dark base prevents any pinholes at the tessellation boundary.
    canvas.drawPath(aperture, Paint()..color = const Color(0xff795448));

    const rows = 32;
    const columns = 52;
    const cameraDistance = 900.0;
    final top = -model.halfHeight;
    const bottom = -78.0;
    final positions = <Offset>[];
    final colors = <Color>[];
    final valid = <bool>[];
    final indices = <int>[];

    for (var row = 0; row <= rows; row++) {
      final y = top + (bottom - top) * row / rows;
      final radius = model.radiusAt(y);
      for (var column = 0; column <= columns; column++) {
        final x =
            -model.maxRadius + 2 * model.maxRadius * column / columns;
        final inside = radius > 1e-6 && x.abs() <= radius;
        valid.add(inside);

        if (!inside) {
          positions.add(Offset.zero);
          colors.add(const Color(0x00000000));
          continue;
        }

        // The visible cavity is the FAR INNER wall of the same 3D shell model.
        // Using the rear surface and a small perspective projection makes the
        // opening read as concave volume instead of a flat brown ribbon.
        final rearOuter = model.surfaceAt(x, y, back: true);
        final rearInner = model.inset(rearOuter, thickness);
        final perspective =
            cameraDistance / (cameraDistance - rearInner.z);
        positions.add(
          Offset(rearInner.x * perspective, rearInner.y * perspective),
        );

        final depthRadius = math.max(1.0, model.depthRadiusAt(y));
        final opticalDepth =
            (-rearInner.z / depthRadius).clamp(0.0, 1.0).toDouble();
        final sideLight =
            math.pow((1 - opticalDepth).clamp(0.0, 1.0), .30).toDouble();
        final exposure =
            (.18 + .48 * sideLight - .07 * opticalDepth)
                .clamp(.16, .58)
                .toDouble();
        colors.add(
          Color.lerp(
            const Color(0xff765044),
            const Color(0xffe8c8aa),
            exposure,
          )!,
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
        if (!(valid[a] && valid[b] && valid[c] && valid[d])) continue;
        indices.addAll([a, c, b, b, c, d]);
      }
    }

    canvas.save();
    canvas.clipPath(aperture, doAntiAlias: true);
    canvas.drawVertices(
      ui.Vertices(
        ui.VertexMode.triangles,
        positions,
        colors: colors,
        indices: indices,
      ),
      BlendMode.srcOver,
      Paint()..color = Colors.white,
    );
    canvas.restore();
  }

  void _drawBody(Canvas canvas) {
    const rows = 72;
    const columns = 48;
    final positions = <Offset>[];
    final colors = <Color>[];
    final indices = <int>[];

    for (var row = 0; row <= rows; row++) {
      final y = -model.halfHeight + 2 * model.halfHeight * row / rows;
      for (var column = 0; column <= columns; column++) {
        final angle = -math.pi / 2 + math.pi * column / columns;
        final point = model.pointAt(y, angle);
        positions.add(point.xy);
        colors.add(_shade(model.normalAt(point)));
      }
    }

    final stride = columns + 1;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final a = row * stride + column;
        final b = a + 1;
        final c = a + stride;
        final d = c + 1;
        indices.addAll([a, c, b, b, c, d]);
      }
    }

    // Clip the continuous body mesh by the exact fracture aperture instead of
    // dropping whole mesh cells. The former cell test created the rectangular
    // staircase visible below F1 and made the shell edge disagree with the
    // actual crack network.
    final visibleBody = Path.combine(
      PathOperation.difference,
      model.silhouettePath(),
      _aperturePath(),
    )..fillType = PathFillType.evenOdd;

    canvas.save();
    canvas.clipPath(visibleBody, doAntiAlias: true);
    canvas.drawVertices(
      ui.Vertices(
        ui.VertexMode.triangles,
        positions,
        colors: colors,
        indices: indices,
      ),
      BlendMode.srcOver,
      Paint()..color = Colors.white,
    );
    canvas.restore();
  }

  void _drawCap(Canvas canvas) {
    const rows = 34;
    const columns = 96;
    final vertexCount = (rows + 1) * (columns + 1);

    final outer3 = List<EggShellPoint3?>.filled(vertexCount, null);
    final inner3 = List<EggShellPoint3?>.filled(vertexCount, null);
    final normals = List<EggShellPoint3?>.filled(vertexCount, null);
    final outerPositions = List<Offset>.filled(vertexCount, Offset.zero);
    final innerPositions = List<Offset>.filled(vertexCount, Offset.zero);
    final outerColors = List<Color>.filled(vertexCount, _shellBase);
    final innerColors = List<Color>.filled(vertexCount, _innerShell);

    for (var row = 0; row <= rows; row++) {
      final t = row / rows;
      for (var column = 0; column <= columns; column++) {
        final angle = -math.pi + 2 * math.pi * column / columns;
        final bottomY = _boundaryY(angle);
        final y = -model.halfHeight + (bottomY + model.halfHeight) * t;
        final outer = model.pointAt(y, angle);
        final normal = model.normalAt(outer);
        final inner = model.inset(outer, thickness);
        final movedOuter = _transformPoint(outer);
        final movedInner = _transformPoint(inner);
        final movedNormal = _transformNormal(normal);
        final index = row * (columns + 1) + column;
        outer3[index] = movedOuter;
        inner3[index] = movedInner;
        normals[index] = movedNormal;
        outerPositions[index] = movedOuter.xy;
        innerPositions[index] = movedInner.xy;
        outerColors[index] = _shade(movedNormal);
      }
    }

    final outerIndices = <int>[];
    final innerIndices = <int>[];
    final stride = columns + 1;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final a = row * stride + column;
        final b = a + 1;
        final c = a + stride;
        final d = c + 1;
        final nz =
            (normals[a]!.z + normals[b]!.z + normals[c]!.z + normals[d]!.z) /
            4;

        // Orthographic camera looks along +Z. Culling on the transformed shell
        // normal makes F1 a true 360° cap: rear material stays hidden while
        // closed and can become visible naturally when the cap tilts.
        if (nz >= -.015) {
          outerIndices.addAll([a, c, b, b, c, d]);
        } else if (openAmount > .02) {
          // A thin eggshell does not reveal its whole inner hemisphere as soon
          // as the cap starts to lift. Near the closed pose, the body of the egg
          // occludes almost all of that concave surface; only the broken rim is
          // readable. Reveal deeper inner material progressively as the cap
          // rotates farther away.
          final rowT = row / rows;
          final innerRevealDepth =
              (.025 + .14 * openAmount).clamp(.025, .17).toDouble();
          final visibleFromRow = 1 - innerRevealDepth;
          if (rowT >= visibleFromRow) {
            innerIndices.addAll([a, b, c, b, d, c]);
          }
        }
      }
    }

    if (innerIndices.isNotEmpty) {
      canvas.drawVertices(
        ui.Vertices(
          ui.VertexMode.triangles,
          innerPositions,
          colors: innerColors,
          indices: innerIndices,
        ),
        BlendMode.srcOver,
        Paint()..color = Colors.white,
      );
    }

    if (openAmount > .02) {
      final edgePositions = <Offset>[];
      final edgeColors = <Color>[];
      final edgeIndices = <int>[];
      for (var column = 0; column <= columns; column++) {
        final angle = -math.pi + 2 * math.pi * column / columns;
        final outer = _transformPoint(
          model.pointAt(_boundaryY(angle), angle),
        );
        final inner = _transformPoint(
          model.inset(model.pointAt(_boundaryY(angle), angle), thickness),
        );
        edgePositions
          ..add(outer.xy)
          ..add(inner.xy);
        edgeColors
          ..add(_edgeShell)
          ..add(_innerShell);
      }
      for (var column = 0; column < columns; column++) {
        final angle =
            -math.pi + 2 * math.pi * (column + .5) / columns;
        final shellNormal = _transformNormal(
          model.normalAt(model.pointAt(_boundaryY(angle), angle)),
        );
        // Keep the visible front and side portions of the cut rim. Rear strips
        // remain hidden by the cap/body unless the tilt brings them around.
        if (shellNormal.z < -.35) continue;
        final a = column * 2;
        final b = a + 1;
        final c = a + 2;
        final d = a + 3;
        edgeIndices.addAll([a, b, c, c, b, d]);
      }

      canvas.drawVertices(
        ui.Vertices(
          ui.VertexMode.triangles,
          edgePositions,
          colors: edgeColors,
          indices: edgeIndices,
        ),
        BlendMode.srcOver,
        Paint()..color = Colors.white,
      );
    }

    if (outerIndices.isNotEmpty) {
      canvas.drawVertices(
        ui.Vertices(
          ui.VertexMode.triangles,
          outerPositions,
          colors: outerColors,
          indices: outerIndices,
        ),
        BlendMode.srcOver,
        Paint()..color = Colors.white,
      );
    }

    // Visible front half of the fracture line.
    final crack = Path();
    const crackColumns = 72;
    for (var column = 0; column <= crackColumns; column++) {
      final angle = -math.pi / 2 + math.pi * column / crackColumns;
      final point = _transformPoint(
        model.pointAt(_boundaryY(angle), angle),
      ).xy;
      if (column == 0) {
        crack.moveTo(point.dx, point.dy);
      } else {
        crack.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      crack,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .72
        ..strokeCap = StrokeCap.square
        ..color = const Color(0x6676503a),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff6f5b49), Color(0xffcbb07d)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final usableWidth = size.width * .76;
    final usableHeight = size.height * .80;
    final scale = math.min(
      usableWidth / (2 * model.maxRadius),
      usableHeight / (2 * model.halfHeight),
    );
    final origin = Offset(size.width / 2, size.height * .51);

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);

    if (shadow) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, model.halfHeight + 7),
          width: model.maxRadius * 1.55,
          height: 18,
        ),
        Paint()
          ..color = const Color(0x3d3e2a1c)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    _drawCavity(canvas);
    _drawBody(canvas);
    _drawCrackNetwork(canvas);
    _drawCap(canvas);

    canvas.drawPath(
      model.silhouettePath(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .85 / scale
        ..color = const Color(0x554f301d),
    );

    if (guides) {
      final guidePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .65 / scale
        ..color = const Color(0x55ffffff);
      canvas.drawLine(
        Offset(0, -model.halfHeight),
        Offset(0, model.halfHeight),
        guidePaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(EggShellF1PreviewPainter oldDelegate) =>
      oldDelegate.model != model ||
      oldDelegate.guides != guides ||
      oldDelegate.shadow != shadow ||
      oldDelegate.thickness != thickness ||
      oldDelegate.openAmount != openAmount ||
      oldDelegate.seed != seed;
}
