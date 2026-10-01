import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// Surface colors, including the fixed fracture lip.
abstract final class FragmentSurfaceColors {
  static const shell = Color(0xffffd700);
  static const outer = Color(0xff00dcdc);
  static const inner = Color(0xffff00c8);
  static const rim = Color(0xffff7800);
  static const fixedLip = Color(0xff00e050);
  static const cavity = Color(0xff2850ff);
  static const background = Color(0xff606060);
  static const shadow = Color(0xff8000ff);
  static const palette = {
    'shell': shell,
    'outer': outer,
    'inner': inner,
    'rim': rim,
    'fixedLip': fixedLip,
    'cavity': cavity,
    'background': background,
    'shadow': shadow,
  };

  static String classify(List<int> rgb, {bool nearShadow = false}) {
    for (final entry in palette.entries) {
      final value = entry.value.toARGB32();
      final channels = [(value >> 16) & 255, (value >> 8) & 255, value & 255];
      if (List.generate(
        3,
        (i) => (channels[i] - rgb[i]).abs() <= 1,
      ).every((matches) => matches)) {
        return entry.key;
      }
    }
    // Shadows retain their real alpha and blur in false-color mode. Recognize
    // a blend only near a recorded shadow, never assign arbitrary dark pixels.
    if (nearShadow) {
      const violet = [128, 0, 255];
      for (final color in palette.values) {
        if (color == shadow) continue;
        final value = color.toARGB32();
        final base = [(value >> 16) & 255, (value >> 8) & 255, value & 255];
        var dot = 0.0, length = 0.0;
        for (var i = 0; i < 3; i++) {
          dot += (rgb[i] - base[i]) * (violet[i] - base[i]);
          length += (violet[i] - base[i]) * (violet[i] - base[i]);
        }
        final alpha = dot / length;
        if (alpha <= 0 || alpha > 1) continue;
        if (List.generate(
          3,
          (i) =>
              (rgb[i] - base[i] - alpha * (violet[i] - base[i])).abs() <= 1.5,
        ).every((matches) => matches)) {
          return 'shadow';
        }
      }
    }
    return 'mixedOrCrack';
  }
}

class _Triangle {
  _Triangle(this.a, this.b, this.c)
    : bounds = Rect.fromLTRB(
        [a.dx, b.dx, c.dx].reduce((a, b) => a < b ? a : b),
        [a.dy, b.dy, c.dy].reduce((a, b) => a < b ? a : b),
        [a.dx, b.dx, c.dx].reduce((a, b) => a > b ? a : b),
        [a.dy, b.dy, c.dy].reduce((a, b) => a > b ? a : b),
      );
  final Offset a, b, c;
  final Rect bounds;
  double get area =>
      (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
  bool contains(Offset p) {
    if (!bounds.inflate(1e-8).contains(p) || area.abs() < 1e-10) return false;
    final u =
        ((p.dx - a.dx) * (c.dy - a.dy) - (p.dy - a.dy) * (c.dx - a.dx)) / area;
    final v =
        ((b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx)) / area;
    return u >= -1e-8 && v >= -1e-8 && u + v <= 1 + 1e-8;
  }

  double interpolate(Offset p, double za, double zb, double zc) {
    final u =
        ((p.dx - a.dx) * (c.dy - a.dy) - (p.dy - a.dy) * (c.dx - a.dx)) / area;
    final v =
        ((b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx)) / area;
    return za + u * (zb - za) + v * (zc - za);
  }
}

/// Exact late stroke and its clip, recorded without changing production paint.
class FragmentOverlayStroke {
  FragmentOverlayStroke(
    this.primitive,
    this.path,
    this.paint,
    this.clip, {
    this.owner = 'fixedShell',
  });
  final String primitive;
  final String owner;
  final Path path, clip;
  final Paint paint;

  void replay(Canvas canvas) {
    canvas.save();
    canvas.clipPath(clip);
    canvas.drawPath(path, paint);
    canvas.restore();
  }
}

/// On-demand ownership of the very geometry submitted to Canvas. Geometric
/// ownership, draw coverage and captured pixel identity remain separate facts.
class FragmentSurfaceProbe {
  FragmentSurfaceProbe({
    required this.egg,
    required this.aperture,
    required this.opening,
    required this.outer,
    required this.inner,
    required this.showEgg,
    required this.eggToCanvas,
    required this.positions,
    required this.indices,
    required this.textureCoordinates,
    required this.depthChanges,
    required List<Offset> shellTriangles,
  }) : _shellPositions = shellTriangles;
  final Path egg, aperture, opening, outer, inner;
  final bool showEgg;
  final Matrix4 eggToCanvas;
  final List<Offset> positions, _shellPositions;
  final List<Offset> textureCoordinates;
  final List<int> indices;
  final List<double> Function() depthChanges;
  late final _depths = depthChanges();
  late final _triangles = [
    for (var i = 0; i < indices.length; i += 3)
      _Triangle(
        positions[indices[i]],
        positions[indices[i + 1]],
        positions[indices[i + 2]],
      ),
  ];
  late final _shellTriangles = [
    for (var i = 0; i < _shellPositions.length; i += 3)
      _Triangle(
        _shellPositions[i],
        _shellPositions[i + 1],
        _shellPositions[i + 2],
      ),
  ];
  late final _canvasToEgg = Matrix4.inverted(eggToCanvas);
  final faces = <(String, Path)>[]; // Accepted faces, in actual paint order.
  final shadows = <(Path, Path?, double)>[]; // Footprint, receiver clip, sigma.
  final overlays = <FragmentOverlayStroke>[];
  Path? visibility;
  Path? fixedLip;

  Offset toEgg(Offset p) => MatrixUtils.transformPoint(_canvasToEgg, p);
  Offset toCanvas(Offset p) => MatrixUtils.transformPoint(eggToCanvas, p);

  Map<String, Object> at(Offset p) {
    final inEgg = egg.contains(p), inAperture = aperture.contains(p);
    final inOuter = outer.contains(p), inInner = inner.contains(p);
    final inClip = visibility?.contains(p) ?? true;
    final triangles = [
      for (var i = 0; i < _triangles.length; i++)
        if (_triangles[i].contains(p)) i,
    ];
    final inFixedMesh = _shellTriangles.any((t) => t.contains(p));
    // Independent of the boolean clip path: interpolate the same per-vertex
    // depth changes used to construct its zero-depth crossings.
    final depthsAtPoint = [
      for (final i in triangles)
        _triangles[i].interpolate(
          p,
          _depths[indices[3 * i]],
          _depths[indices[3 * i + 1]],
          _depths[indices[3 * i + 2]],
        ),
    ];
    final behindFixedShell =
        inEgg &&
        !inAperture &&
        depthsAtPoint.isNotEmpty &&
        depthsAtPoint.every((depth) => depth < 0);
    final expectedVisible = !showEgg || !behindFixedShell;
    // Logical set difference is independent of Path.combine and of rasterization.
    final cavity = inEgg && inAperture && !inOuter;
    var expected = showEgg && inEgg
        ? (inAperture ? (cavity ? 'cavity' : 'uncovered') : 'shell')
        : 'background';
    var coverage = showEgg && opening.contains(p) ? 'cavity' : 'background';
    if (showEgg && inEgg && inFixedMesh) coverage = 'shell';
    var inRim = false;
    for (final (owner, path) in faces) {
      final inside = path.contains(p);
      if (owner == 'rim' && inside) inRim = true;
      // A depth clip against fixed shell cannot remove material IN the aperture.
      if (inside && expectedVisible) {
        expected = owner;
      }
      if (inClip && (owner == 'outer' ? triangles.isNotEmpty : inside)) {
        coverage = owner;
      }
    }
    final inFixedLip = fixedLip?.contains(p) ?? false;
    if (inFixedLip) {
      expected = 'fixedLip';
      coverage = 'fixedLip';
    }
    final inShadow = shadows.any(
      (s) => s.$1.contains(p) && (s.$2?.contains(p) ?? true),
    );
    final nearShadow = shadows.any(
      (s) =>
          s.$1.getBounds().inflate(3 * s.$3).contains(p) &&
          (s.$2?.contains(p) ?? true),
    );
    return {
      'eggPoint': [p.dx, p.dy],
      'insideEgg': inEgg,
      'insideFragmentOuterFace': inOuter,
      'insideOuterTriangles': triangles.isNotEmpty,
      'coveringTriangles': triangles,
      'coveringTriangleDepths': [
        for (final i in triangles)
          [for (var j = 0; j < 3; j++) _depths[indices[3 * i + j]]],
      ],
      'interpolatedOuterDepths': depthsAtPoint,
      'behindFixedShell': behindFixedShell,
      'expectedOuterVisibility': expectedVisible,
      'clipDisagreesWithDepth':
          triangles.isNotEmpty && inClip != expectedVisible,
      'invertedCoveringTriangles': [
        for (final i in triangles)
          if (_triangles[i].area < 0) i,
      ],
      'insideFragmentInnerFace': inInner,
      'insideAperture': inAperture,
      'insideInteriorEgg': cavity,
      'insidePaintedOpening': opening.contains(p),
      'insideEdge': inRim,
      'insideFixedLip': inFixedLip,
      'insideShadow': inShadow,
      'nearShadow': nearShadow,
      'insideFragmentClip': inClip,
      'insideFixedShellTriangles': inFixedMesh,
      'expectedSurface': expected,
      'paintCoverageSurface': coverage,
    };
  }

  /// Rasterize only recorded late primitives at the selected physical pixel.
  /// This identifies translucent/antialiased brown strokes as well as solid
  /// pixels. No new overlay is painted into the scene itself.
  Future<Map<String, Object>> tracePixel(
    Offset selected,
    double pixelRatio,
  ) async {
    final x = (selected.dx * pixelRatio).floor(),
        y = (selected.dy * pixelRatio).floor();
    final eggPoint = toEgg(
      Offset((x + .5) / pixelRatio, (y + .5) / pixelRatio),
    );
    final contributions = <Map<String, Object>>[];
    Future<int> coverage(void Function(Canvas) draw) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..translate(-x.toDouble(), -y.toDouble())
        ..scale(pixelRatio)
        ..transform(eggToCanvas.storage);
      draw(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(1, 1);
      try {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        return bytes.getUint8(3);
      } finally {
        image.dispose();
        picture.dispose();
      }
    }

    final white = Paint()..color = Colors.white;
    final maskCoverage = <String, int>{};
    maskCoverage['fragmentDepthClip'] = await coverage((canvas) {
      if (visibility != null) canvas.clipPath(visibility!);
      canvas.drawRect(const Rect.fromLTRB(-1000, -1000, 1000, 1000), white);
    });
    maskCoverage['outerTrianglesBeforeClip'] = await coverage((canvas) {
      if (faces.any((face) => face.$1 == 'outer')) {
        canvas.drawVertices(
          ui.Vertices(
            ui.VertexMode.triangles,
            positions,
            indices: indices,
            textureCoordinates: textureCoordinates,
          ),
          BlendMode.srcOver,
          white,
        );
      }
    });
    maskCoverage['outerTrianglesAfterClip'] = await coverage((canvas) {
      if (visibility != null) canvas.clipPath(visibility!);
      if (faces.any((face) => face.$1 == 'outer')) {
        canvas.drawVertices(
          ui.Vertices(
            ui.VertexMode.triangles,
            positions,
            indices: indices,
            textureCoordinates: textureCoordinates,
          ),
          BlendMode.srcOver,
          white,
        );
      }
    });
    maskCoverage['fixedShellTriangles'] = await coverage((canvas) {
      if (showEgg) {
        canvas.clipPath(egg);
        canvas.drawVertices(
          ui.Vertices(
            ui.VertexMode.triangles,
            _shellPositions,
            textureCoordinates: _shellPositions,
          ),
          BlendMode.srcOver,
          white,
        );
      }
    });
    maskCoverage['cavity'] = await coverage((canvas) {
      if (showEgg) canvas.drawPath(opening, white);
    });
    if (fixedLip != null) {
      maskCoverage['fixedLip'] = await coverage((canvas) {
        canvas.drawPath(fixedLip!, white);
      });
    }
    for (final stroke in overlays) {
      if (!stroke.path
          .getBounds()
          .inflate(stroke.paint.strokeWidth / 2 + 2)
          .contains(eggPoint)) {
        continue;
      }
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..translate(-x.toDouble(), -y.toDouble())
        ..scale(pixelRatio)
        ..transform(eggToCanvas.storage);
      stroke.replay(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(1, 1);
      try {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!;
        if (bytes.getUint8(3) > 0) {
          contributions.add({
            'primitive': stroke.primitive,
            'owner': stroke.owner,
            'coordinateSpace': stroke.owner == 'fragmentOuter'
                ? 'projectedMaterial'
                : 'fixedEgg',
            'rgba': [for (var c = 0; c < 4; c++) bytes.getUint8(c)],
            'clipContainsCenter': stroke.clip.contains(eggPoint),
          });
        }
      } finally {
        image.dispose();
        picture.dispose();
      }
    }
    return {
      'primitiveCoverageAlpha': maskCoverage,
      'coverageMeaning': 'Isolated raster replay at the captured physical pixel (0..255); no change to scene paint.',
      'lateStrokeContributions': contributions,
      if (contributions.isNotEmpty)
        'lastLateStroke': contributions.last['primitive']!,
    };
  }

  /// Pixel centers and ROI are in preview coordinates; actual DPR is retained.
  /// Mixed/antialiased/crack pixels are reported separately, never forced to gray.
  Map<String, Object> rasterReport(
    ByteData data,
    int width,
    int height,
    double pixelRatio,
    Offset selected, {
    double radius = 8,
  }) {
    final roi = Rect.fromCenter(
      center: selected,
      width: 2 * radius,
      height: 2 * radius,
    ).intersect(Rect.fromLTWH(0, 0, width / pixelRatio, height / pixelRatio));
    final expected = <String, int>{}, rendered = <String, int>{};
    var total = 0, missing = 0;
    final examples = <Map<String, Object>>[];
    Map<String, Object> pixel(int x, int y) {
      final offset = 4 * (y * width + x);
      final rgb = [for (var c = 0; c < 3; c++) data.getUint8(offset + c)];
      final canvasPoint = Offset((x + .5) / pixelRatio, (y + .5) / pixelRatio);
      final geometric = at(toEgg(canvasPoint));
      return {
        ...geometric,
        'canvasPoint': [canvasPoint.dx, canvasPoint.dy],
        'rgb': rgb,
        'finalRenderedSurface': FragmentSurfaceColors.classify(
          rgb,
          nearShadow: geometric['nearShadow'] == true,
        ),
      };
    }

    for (
      var y = (roi.top * pixelRatio - .5).ceil();
      y < (roi.bottom * pixelRatio - .5).ceil();
      y++
    ) {
      for (
        var x = (roi.left * pixelRatio - .5).ceil();
        x < (roi.right * pixelRatio - .5).ceil();
        x++
      ) {
        final point = pixel(x, y);
        final a = point['expectedSurface'] as String,
            b = point['finalRenderedSurface'] as String;
        expected[a] = (expected[a] ?? 0) + 1;
        rendered[b] = (rendered[b] ?? 0) + 1;
        total++;
        if (b == 'background' && a != 'background') {
          missing++;
          if (examples.length < 5) examples.add(point);
        }
      }
    }
    Map<String, double> percentages(Map<String, int> counts) => counts.map(
      (key, value) => MapEntry(key, total == 0 ? 0.0 : 100 * value / total),
    );
    return {
      'selectedCanvasPoint': [selected.dx, selected.dy],
      'point': pixel(
        (selected.dx * pixelRatio).floor().clamp(0, width - 1),
        (selected.dy * pixelRatio).floor().clamp(0, height - 1),
      ),
      'roiCanvas': [roi.left, roi.top, roi.right, roi.bottom],
      'roiPixels': total,
      'pixelRatio': pixelRatio,
      'expectedPercent': percentages(expected),
      'renderedPercent': percentages(rendered),
      'backgroundWhereSurfaceExpected': missing,
      'missingSurfaceExamples': examples,
      'shadowMeaning': 'Footprint membership; nearShadow bounds use 3 sigma. Geometry excludes translucent shadow overlays.',
    };
  }
}
