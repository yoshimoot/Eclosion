import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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

  /// Crown cut currently shared by the F1 preview and the static fracture
  /// graph. Moving this boundary requires a dedicated geometric validation.
  double crownFractureY(double angle) {
    final u = ((angle + math.pi) / (2 * math.pi)) % 1.0;
    final frontBack = 9 * math.cos(angle);
    final irregular =
        6 * math.sin(u * math.pi * 6 + .45) +
        3.5 * math.sin(u * math.pi * 14 + 1.15);
    final lateralBias = 4 * math.sin(angle - .35);
    return (-114 + frontBack + irregular + lateralBias)
        .clamp(-132.0, -94.0)
        .toDouble();
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



class _DepthMesh {
  _DepthMesh(this.points, this.colors, this.indices,
      {required this.diagnosticColor, this.fracture = false});
  final List<EggShellPoint3> points;
  final List<Color> colors;
  final List<int> indices;
  final bool fracture;
  final Color diagnosticColor;

  void draw(Canvas canvas, {required bool identifySurfaces}) => canvas.drawVertices(
    ui.Vertices(ui.VertexMode.triangles,
      points.map((point) => point.xy).toList(),
      colors: identifySurfaces
          ? List<Color>.filled(points.length, diagnosticColor)
          : colors,
      indices: indices),
    BlendMode.srcOver, Paint()..color = Colors.white);
}

/// F1-only diagnostic Z-buffer. Resolve each projected triangle at pixel
/// centres, then clip the original interpolated-colour meshes to their visible
/// pixels. Unlike a painter/group sort, this handles crossing surface depths.
class _DepthScene {
  final meshes = <_DepthMesh>[];

  void add(List<EggShellPoint3> points, List<Color> colors,
      List<int> indices, {bool fracture = false,
      required Color diagnosticColor}) {
    if (indices.isNotEmpty) {
      meshes.add(_DepthMesh(points, colors, indices,
          fracture: fracture, diagnosticColor: diagnosticColor));
    }
  }

  void paint(Canvas canvas, Path crack, {required bool identifySurfaces}) {
    if (meshes.isEmpty) return;
    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final mesh in meshes) {
      for (final p in mesh.points) {
        minX = math.min(minX, p.x);
        maxX = math.max(maxX, p.x);
        minY = math.min(minY, p.y);
        maxY = math.max(maxY, p.y);
      }
    }
    // Approximately one model unit per screen pixel in the F1 preview.
    final left = minX.floor() - 2, top = minY.floor() - 2;
    final width = maxX.ceil() - left + 3;
    final height = maxY.ceil() - top + 3;
    final count = width * height;
    final depth = Float64List(count)
      ..fillRange(0, count, double.negativeInfinity);
    final owner = Uint8List(count);

    for (var surface = 0; surface < meshes.length; surface++) {
      final mesh = meshes[surface];
      for (var i = 0; i < mesh.indices.length; i += 3) {
        final p0 = mesh.points[mesh.indices[i]];
        final p1 = mesh.points[mesh.indices[i + 1]];
        final p2 = mesh.points[mesh.indices[i + 2]];
        final signedArea = (p1.x-p0.x)*(p2.y-p0.y) -
            (p1.y-p0.y)*(p2.x-p0.x);
        if (signedArea.abs() < 1e-9) continue;
        final x0 = (math.min(p0.x, math.min(p1.x,p2.x))-left-.5)
            .ceil().clamp(0,width-1).toInt();
        final x1 = (math.max(p0.x, math.max(p1.x,p2.x))-left-.5)
            .floor().clamp(0,width-1).toInt();
        final y0 = (math.min(p0.y, math.min(p1.y,p2.y))-top-.5)
            .ceil().clamp(0,height-1).toInt();
        final y1 = (math.max(p0.y, math.max(p1.y,p2.y))-top-.5)
            .floor().clamp(0,height-1).toInt();
        if (x0>x1 || y0>y1) continue;
        final inverse = 1/signedArea;
        final da = (p1.y-p2.y)*inverse;
        final db = (p2.y-p0.y)*inverse;
        for (var y=y0;y<=y1;y++) {
          final py=top+y+.5, px=left+x0+.5;
          var a=((p1.y-p2.y)*(px-p2.x)+(p2.x-p1.x)*(py-p2.y))*inverse;
          var b=((p2.y-p0.y)*(px-p2.x)+(p0.x-p2.x)*(py-p2.y))*inverse;
          for (var x=x0;x<=x1;x++) {
            final c=1-a-b;
            if(a>=-1e-8 && b>=-1e-8 && c>=-1e-8) {
              final z=a*p0.z+b*p1.z+c*p2.z;
              final pixel=y*width+x;
              if(z>depth[pixel]+1e-7) {
                depth[pixel]=z;
                owner[pixel]=surface+1;
              }
            }
            a+=da; b+=db;
          }
        }
      }
    }

    // Disjoint run-length masks preserve the vertex colours and material.
    final paths=List<Path>.generate(meshes.length,(_)=>Path());
    final crackPath=Path();
    for(var y=0;y<height;y++) {
      var x=0;
      while(x<width) {
        final id=owner[y*width+x], start=x;
        while(x<width && owner[y*width+x]==id) { x++; }
        if(id==0) continue;
        final rect=Rect.fromLTWH((left+start).toDouble(),
            (top+y).toDouble(),(x-start).toDouble(),1);
        paths[id-1].addRect(rect);
        if(meshes[id-1].fracture) crackPath.addRect(rect);
      }
    }
    for(var i=0;i<meshes.length;i++) {
      canvas.save();
      canvas.clipPath(paths[i],doAntiAlias:true);
      meshes[i].draw(canvas, identifySurfaces: identifySurfaces);
      canvas.restore();
    }
    if (!identifySurfaces) {
      canvas.save();
      canvas.clipPath(crackPath, doAntiAlias: true);
      canvas.drawPath(crack, Paint()
          ..style=PaintingStyle.stroke
          ..strokeWidth=1.2
          ..strokeCap=StrokeCap.round
          ..color=const Color(0x8a76503a));
      canvas.restore();
    }
  }
}

class EggShellF1PreviewPainter extends CustomPainter {
  const EggShellF1PreviewPainter({
    this.model = EggShellModel.reference,
    this.guides = false,
    this.shadow = true,
    this.thickness = 2.5,
    this.openAmount = .55,
    this.identifySurfaces = false,
  });

  final EggShellModel model;
  final bool guides;
  final bool shadow;
  final double thickness;
  final double openAmount;
  final bool identifySurfaces;

  static const _shellLight = Color(0xffffd59b);
  static const _shellBase = Color(0xffe7ab70);
  static const _shellDark = Color(0xff9c633d);
  static const _innerShell = Color(0xffd5aa86);
  static const _edgeShell = Color(0xffbd8257);

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

  // Delegated to the shared shell model: no second copy of the crown cut.
  double _boundaryY(double angle) => model.crownFractureY(angle);

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
    local = _rotateX(local, .34 * amount);
    local = _rotateZ(local, -.045 * amount);
    return local +
        hinge +
        EggShellPoint3(-5 * amount, -3 * amount, -7 * amount);
  }

  EggShellPoint3 _transformNormal(EggShellPoint3 normal) {
    final amount = openAmount.clamp(0.0, 1.0).toDouble();
    // Normals must use the exact rotation applied to the shell vertices.
    var result = _rotateX(normal, .34 * amount);
    result = _rotateZ(result, -.045 * amount);
    return result.normalized;
  }

  Color _shadeInner(EggShellPoint3 outwardNormal) {
    // The visible reverse side is concave shell material, not a flat patch.
    // Shade its inward-facing normal under the same light as the exterior.
    const light = EggShellPoint3(-.38, -.48, .79);
    final diffuse = (-outwardNormal.x * light.x -
            outwardNormal.y * light.y -
            outwardNormal.z * light.z)
        .clamp(-1.0, 1.0)
        .toDouble();
    final amount = ((diffuse + 1) * .5).clamp(0.0, 1.0).toDouble();
    return Color.lerp(
      const Color(0xff9f735f),
      const Color(0xffdfb89b),
      amount,
    )!;
  }

  void _drawRearInnerBowl(_DepthScene scene) {
    // The true rear inner wall is revealed through F1's opening.
    // Geometry comes from the shared 3D shell, not a 2D cavity overlay.
    const rows = 64;
    const columns = 96;
    final points = <EggShellPoint3>[];
    final colors = <Color>[];
    final indices = <int>[];

    for (var row = 0; row <= rows; row++) {
      final t = row / rows;
      for (var column = 0; column <= columns; column++) {
        final angle = math.pi / 2 + math.pi * column / columns;
        final topY = _boundaryY(angle);
        final y = topY + (model.halfHeight - topY) * t;
        final outer = model.pointAt(y, angle);
        final inner = model.inset(outer, thickness);
        points.add(inner);
        colors.add(_shadeInner(model.normalAt(outer)));
      }
    }

    final stride = columns + 1;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final a = row * stride + column;
        final b = a + 1;
        final c = a + stride;
        final d = c + 1;
        indices.addAll([a, b, c, b, d, c]);
      }
    }

    scene.add(points, colors, indices,
        diagnosticColor: const Color(0xff3366dd)); // Rear bowl interior
  }

  void _drawBody(_DepthScene scene) {
    const rows = 72;
    const columns = 48;
    final points = <EggShellPoint3>[];
    final colors = <Color>[];
    final indices = <int>[];

    // The first mesh row follows the exact shared fracture boundary.
    // Dropping complete triangles at a sampled row would produce square steps.
    for (var row = 0; row <= rows; row++) {
      final t = row / rows;
      for (var column = 0; column <= columns; column++) {
        final angle = -math.pi / 2 + math.pi * column / columns;
        final topY = _boundaryY(angle);
        final y = topY + (model.halfHeight - topY) * t;
        final point = model.pointAt(y, angle);
        points.add(point);
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

    scene.add(points, colors, indices,
        diagnosticColor: const Color(0xff40c8ed)); // Fixed bowl exterior
  }

  Path _drawCap(_DepthScene scene) {
    const rows = 34;
    const columns = 96;
    final vertexCount = (rows + 1) * (columns + 1);

    final outer3 = List<EggShellPoint3>.filled(vertexCount, const EggShellPoint3(0, 0, 0));
    final inner3 = List<EggShellPoint3>.filled(vertexCount, const EggShellPoint3(0, 0, 0));
    final normals = List<EggShellPoint3>.filled(vertexCount, const EggShellPoint3(0, 0, 0));
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
        outerColors[index] = _shade(movedNormal);
        innerColors[index] = _shadeInner(movedNormal);
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
            (normals[a].z + normals[b].z + normals[c].z + normals[d].z) /
            4;

        // Orthographic camera looks along +Z. Culling on the transformed shell
        // normal makes F1 a true 360° cap: rear material stays hidden while
        // closed and can become visible naturally when the cap tilts.
        if (nz >= -.015) {
          outerIndices.addAll([a, c, b, b, c, d]);
        } else if (openAmount > .02) {
          innerIndices.addAll([a, b, c, b, d, c]);
        }
      }
    }

    scene.add(inner3, innerColors, innerIndices,
        diagnosticColor: const Color(0xffff3db8)); // F1 inner

    if (openAmount > .02) {
      final edgePoints = <EggShellPoint3>[];
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
        edgePoints
          ..add(outer)
          ..add(inner);
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

      scene.add(edgePoints, edgeColors, edgeIndices,
          fracture: true, diagnosticColor: const Color(0xffff8c2e)); // Rim
    }

    scene.add(outer3, outerColors, outerIndices,
        fracture: true, diagnosticColor: const Color(0xff87c961)); // F1 outer

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
    return crack;
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

    final scene = _DepthScene();
    _drawRearInnerBowl(scene);
    _drawBody(scene);
    final crack = _drawCap(scene);
    scene.paint(canvas, crack, identifySurfaces: identifySurfaces);

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
      oldDelegate.identifySurfaces != identifySurfaces;
}
