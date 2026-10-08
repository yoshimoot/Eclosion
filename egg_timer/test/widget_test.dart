import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:egg_timer/main.dart';
import 'package:egg_timer/lab/egg_shell_model.dart';
import 'package:egg_timer/lab/fragment_scene.dart';
import 'package:egg_timer/lab/fragment_playback.dart';

import 'fragment_lab_continuity.dart';
import 'fragment_occlusion.dart';

void main() {
  fragmentLabContinuityTests();
  fragmentOcclusionTests();
  testWidgets('Sans ombres le vide reste dans le balayage local des bords', (
    tester,
  ) async {
    List<int>? restingPixels;
    double triangleArea(Offset a, Offset b, Offset c) =>
        ((b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx)) / 2;
    for (final t in [.495, .499, .500, .501, .505, .510, .514, .524]) {
      FragmentPaintDiagnostics? painted;
      final scene = FragmentScene(
        progress: t,
        thickness: 2.5,
        motion: 1.5,
        guides: false,
        showEgg: true,
        shadow: false,
        onDiagnostics: (value) => painted = value,
      );
      final geometry = scene.debugGeometry();
      final fixed = geometry.material.map((v) => Offset(v.$1, v.$2)).toList();
      final moved = geometry.positions.map((v) => Offset(v.$1, v.$2)).toList();
      final swept = Path();
      var sweptAreaBound = 0.0, weightedGap = 0.0, perimeter = 0.0;
      var maxGap = 0.0, footprintArea = 0.0;
      for (var i = 0; i < fixed.length; i++) {
        final j = (i + 1) % fixed.length;
        final a = fixed[i], b = fixed[j], c = moved[j], d = moved[i];
        final length = (b - a).distance;
        final distance = (d - a).distance;
        perimeter += length;
        weightedGap += length * (distance + (c - b).distance) / 2;
        maxGap = math.max(maxGap, distance);
        footprintArea += a.dx * b.dy - b.dx * a.dy;
        if (geometry.retention[i] == 1) expect(moved[i], fixed[i]);
        // Each old edge and its displaced counterpart bound the only strip
        // that can become uncovered. Normalize winding so overlap forms a
        // union, not a cancellation between neighboring swept triangles.
        for (final points in [
          [a, b, c],
          [a, c, d],
        ]) {
          final area = triangleArea(points[0], points[1], points[2]);
          sweptAreaBound += area.abs();
          if (area != 0) {
            swept.addPolygon(
              area > 0 ? points : points.reversed.toList(),
              true,
            );
          }
        }
      }
      footprintArea = footprintArea.abs() / 2;
      final measurement = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        scene.paint(Canvas(recorder), const Size(390, 693));
        final picture = recorder.endRecording();
        final image = await picture.toImage(390, 693);
        final outside = Path.combine(
          PathOperation.difference,
          painted!.opening,
          swept,
        );
        Future<double> rasterArea(Path path) async {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)
            ..scale(4)
            ..translate(16, 136);
          canvas.drawPath(path, Paint()..color = Colors.white);
          final picture = recorder.endRecording();
          final image = await picture.toImage(432, 464);
          try {
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            var coverage = 0;
            for (var i = 3; i < data.lengthInBytes; i += 4) {
              coverage += data.getUint8(i);
            }
            return coverage / 255 / 16;
          } finally {
            image.dispose();
            picture.dispose();
          }
        }

        try {
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          restingPixels ??= data.buffer.asUint8List().toList();
          var interiorPixels = 0, darkPixels = 0;
          for (var y = 210; y < 335; y++) {
            for (var x = 165; x < 280; x++) {
              final i = (y * 390 + x) * 4;
              var loss = 0;
              for (var c = 0; c < 3; c++) {
                loss += restingPixels![i + c] - data.getUint8(i + c);
              }
              if (loss > 3 * 24) darkPixels++;
              // Full interior fill, not a shell shadow or the lighter rim.
              if ((data.getUint8(i) - 105).abs() <= 1 &&
                  (data.getUint8(i + 1) - 68).abs() <= 1 &&
                  (data.getUint8(i + 2) - 46).abs() <= 1) {
                interiorPixels++;
              }
            }
          }
          return (
            await rasterArea(painted!.opening),
            await rasterArea(outside),
            interiorPixels,
            darkPixels,
          );
        } finally {
          image.dispose();
          picture.dispose();
        }
      });
      final (opening, outside, pixels, darkPixels) = measurement!;
      // At most one 4x mask pixel of numerical path-operation residue. This
      // local invariant is stricter than perimeter * GLOBAL maximum gap.
      expect(
        outside,
        lessThanOrEqualTo(1 / 16),
        reason: 'Void beyond separated edges at $t',
      );
      expect(opening, lessThanOrEqualTo(sweptAreaBound + perimeter / 4));
      expect(pixels, lessThanOrEqualTo(opening + perimeter / 2));
      // Also catch an exposed background or a wrong face whose dark color is
      // different from the interior fill. Allow one pixel along each edge for
      // crack antialiasing and whole-egg motion, not a full interior region.
      expect(darkPixels, lessThanOrEqualTo(sweptAreaBound + perimeter));
      if (t == .495) {
        expect(opening, 0);
        expect(pixels, 0);
      }
      debugPrint(
        'No shadow $t: opening=$opening, meanGap=${weightedGap / perimeter}, '
        'maxGap=$maxGap, footprint=$footprintArea, sweptBound=$sweptAreaBound, '
        'outside=$outside, interiorPixels=$pixels, darkPixels=$darkPixels',
      );
    }
  });

  testWidgets('Le vide reste local et continu autour de .495', (tester) async {
    const values = [
      .48,
      .49,
      .494,
      .494999,
      .495,
      .495001,
      .496,
      .499,
      .499999,
      .50,
      .500001,
      .501,
      .505,
      .506,
      .51,
      .524,
    ];
    final raster = <double, List<int>>{};
    final gaps = <double, double>{};
    final displacements = <double, double>{};
    final snapshots = <double, FragmentGeometrySnapshot>{};
    final rimBounds = <double, double>{};
    final angles = <double, double>{};
    double area(List<(double, double, double)> points) {
      var sum = 0.0;
      for (var i = 0; i < points.length; i++) {
        final a = points[i], b = points[(i + 1) % points.length];
        sum += a.$1 * b.$2 - b.$1 * a.$2;
      }
      return sum / 2;
    }

    for (final t in values) {
      FragmentPaintDiagnostics? painted;
      final scene = FragmentScene(
        progress: t,
        thickness: 2.5,
        motion: 1.5,
        guides: false,
        showEgg: true,
        shadow: true,
        onDiagnostics: (diagnostics) => painted = diagnostics,
      );
      final geometry = scene.debugGeometry();
      snapshots[t] = geometry;
      expect(geometry.holds, everyElement(1.0));
      expect(
        area(geometry.innerPositions.reversed.toList()),
        lessThan(0),
        reason: 'No inner face exposed at $t',
      );
      expect(
        area(geometry.material),
        area(snapshots[.48]!.material),
        reason: 'Fixed shell ownership at $t',
      );
      // Upper bound before exposure/depth clipping: even drawing every full
      // thickness quad must not produce a macroscopic surface at first lift.
      var rimBound = 0.0;
      for (var i = 0; i < geometry.positions.length; i++) {
        final j = (i + 1) % geometry.positions.length;
        rimBound += area([
          geometry.positions[i],
          geometry.innerPositions[i],
          geometry.innerPositions[j],
          geometry.positions[j],
        ]).abs();
      }
      rimBounds[t] = rimBound;
      List<double> normal(List<(double, double, double)> points) {
        final a = points[0],
            b = points[points.length ~/ 3],
            c = points[2 * points.length ~/ 3];
        final ux = b.$1 - a.$1, uy = b.$2 - a.$2, uz = b.$3 - a.$3;
        final vx = c.$1 - a.$1, vy = c.$2 - a.$2, vz = c.$3 - a.$3;
        final n = [uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx];
        final length = math.sqrt(n.fold(0.0, (s, v) => s + v * v));
        return n.map((v) => v / length).toList();
      }

      final restNormal = normal(geometry.material),
          movedNormal = normal(geometry.rigid);
      final dot = List.generate(
        3,
        (i) => restNormal[i] * movedNormal[i],
      ).reduce((a, b) => a + b);
      angles[t] = math.acos(dot.clamp(-1.0, 1.0)) * 180 / math.pi;
      final fixed = geometry.material.map((v) => Offset(v.$1, v.$2)).toList();
      final moved = geometry.positions.map((v) => Offset(v.$1, v.$2)).toList();
      var maximumDisplacement = 0.0;
      var perimeter = 0.0;
      for (var i = 0; i < fixed.length; i++) {
        maximumDisplacement = math.max(
          maximumDisplacement,
          (moved[i] - fixed[i]).distance,
        );
        perimeter += (fixed[(i + 1) % fixed.length] - fixed[i]).distance;
        if (geometry.retention[i] == 1) {
          expect(moved[i], fixed[i], reason: 'Closed attachment at $t');
        }
      }
      displacements[t] = maximumDisplacement;
      final outcome = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        scene.paint(Canvas(recorder), const Size(390, 693));
        expect(painted?.progress, t);
        final picture = recorder.endRecording();
        final image = await picture.toImage(390, 693);
        final maskRecorder = ui.PictureRecorder();
        final maskCanvas = Canvas(maskRecorder)
          ..scale(4)
          ..translate(16, 136);
        maskCanvas.drawPath(painted!.opening, Paint()..color = Colors.white);
        final maskPicture = maskRecorder.endRecording();
        final mask = await maskPicture.toImage(432, 464);
        try {
          final pixels = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List().toList();
          final coverage = (await mask.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          var alphaSum = 0;
          for (var i = 3; i < coverage.lengthInBytes; i += 4) {
            alphaSum += coverage.getUint8(i);
          }
          return (pixels, alphaSum / 255 / 16);
        } finally {
          image.dispose();
          picture.dispose();
          mask.dispose();
          maskPicture.dispose();
        }
      });
      raster[t] = outcome!.$1;
      gaps[t] = outcome.$2;
      final report = painted!.toMap();
      expect(report['paintedProgress'], t);
      expect(report['holds'], everyElement(1.0));
      expect(report['openingAreaSampled'], closeTo(outcome.$2, perimeter / 4));
      // Displacing a contour by d cannot uncover its whole footprint: the
      // opening is bounded by a strip along the perimeter (pixel tolerance 1).
      expect(
        outcome.$2,
        lessThanOrEqualTo(
          perimeter * maximumDisplacement +
              math.pi * maximumDisplacement * maximumDisplacement +
              1,
        ),
      );
      if (t <= .495) expect(outcome.$2, 0);
    }
    final baseline = raster[.495]!;
    final darkPixels = <double, int>{};
    for (final t in values) {
      var dark = 0;
      final pixels = raster[t]!;
      for (var y = 210; y < 335; y++) {
        for (var x = 165; x < 280; x++) {
          final i = (y * 390 + x) * 4;
          final loss =
              (baseline[i] - pixels[i]) +
              (baseline[i + 1] - pixels[i + 1]) +
              (baseline[i + 2] - pixels[i + 2]);
          if (loss > 3 * 24) dark++;
        }
      }
      darkPixels[t] = dark;
      if (t >= .494 && t <= .496) {
        expect(dark, lessThanOrEqualTo(10), reason: 'No mass darkening at $t');
        expect(gaps[t], lessThan(1), reason: 'Only a subpixel gap at $t');
      }
      if (t >= .495) {
        // Raster darkness remains proportional to the actual narrow opening;
        // reserve edge pixels for antialiasing, cracks, and the cast shadow.
        expect(
          dark,
          lessThanOrEqualTo(gaps[t]! * 4 + 30),
          reason: 'Darkness without separation at $t',
        );
      }
    }
    debugPrint('Opening areas: $gaps');
    debugPrint('Maximum border displacement: $displacements');
    debugPrint('New dark pixels (>24 RGB levels): $darkPixels');
    debugPrint(
      'Removed shell area (constant): ${area(snapshots[.48]!.material)}',
    );
    debugPrint('Full rim area upper bounds: $rimBounds');
    debugPrint('Rigid normal rotation (degrees): $angles');
    for (final pair in [(.499, .500), (.500, .501)]) {
      final a = snapshots[pair.$1]!, b = snapshots[pair.$2]!;
      var maxStep = 0.0;
      var maxProjectedStep = 0.0, perimeter = 0.0;
      for (var i = 0; i < a.positions.length; i++) {
        final p = a.positions[i], q = b.positions[i];
        final next = a.positions[(i + 1) % a.positions.length];
        perimeter += (Offset(p.$1, p.$2) - Offset(next.$1, next.$2)).distance;
        maxProjectedStep = math.max(
          maxProjectedStep,
          (Offset(p.$1, p.$2) - Offset(q.$1, q.$2)).distance,
        );
        maxStep = math.max(
          maxStep,
          math.sqrt(
            math.pow(p.$1 - q.$1, 2) +
                math.pow(p.$2 - q.$2, 2) +
                math.pow(p.$3 - q.$3, 2),
          ),
        );
      }
      // A millistep cannot displace an entire plate or reveal a large cavity.
      expect(maxStep, lessThan(.5));
      expect((rimBounds[pair.$2]! - rimBounds[pair.$1]!).abs(), lessThan(5));
      expect((angles[pair.$2]! - angles[pair.$1]!).abs(), lessThan(.5));
      // The changed opening lies in a swept boundary strip of width d.
      // Add half a mask pixel per boundary on BOTH rasterized areas: the
      // 4x coverage measurement must not dictate an artistic area threshold.
      final areaChangeBound =
          perimeter * maxProjectedStep +
          math.pi * maxProjectedStep * maxProjectedStep +
          perimeter / 4;
      expect(
        (gaps[pair.$2]! - gaps[pair.$1]!).abs(),
        lessThanOrEqualTo(areaChangeBound),
      );
      var changed = 0;
      final before = raster[pair.$1]!, after = raster[pair.$2]!;
      for (var y = 210; y < 335; y++) {
        for (var x = 165; x < 280; x++) {
          final i = (y * 390 + x) * 4;
          if ([0, 1, 2].any((c) => (before[i + c] - after[i + c]).abs() > 24)) {
            changed++;
          }
        }
      }
      expect(changed, lessThan(100), reason: 'Macroscopic raster jump $pair');
      debugPrint('$pair: max 3D step=$maxStep, changed pixels=$changed');
    }
    for (final pair in [
      (.494999, .495),
      (.495, .495001),
      (.499999, .500),
      (.500, .500001),
    ]) {
      var changed = 0;
      final a = raster[pair.$1]!, b = raster[pair.$2]!;
      for (var y = 210; y < 335; y++) {
        for (var x = 165; x < 280; x++) {
          final i = (y * 390 + x) * 4;
          if ([0, 1, 2].any((c) => (a[i + c] - b[i + c]).abs() > 3)) changed++;
        }
      }
      expect(changed, lessThan(20));
    }
  });

  testWidgets('La partition au repos est indetectable sur toute sa surface', (
    tester,
  ) async {
    const episodes = [
      (.105, .141, .19, .18, .11),
      (.225, .257, .299, -.22, .16),
      (.327, .352, .389, -.13, .21),
      (.403, .424, .459, .27, .2),
      (.471, .491, .523, .14, .24),
    ];
    final failures = <String>[];
    for (final size in [
      const Size(390, 693),
      const Size(312, 693.333333),
      const Size(468, 832),
    ]) {
      for (final t in [0.0, .10, .16, .25, .255999, .35, .494999]) {
        final scene = FragmentScene(
          progress: t,
          thickness: 2.5,
          motion: 1.5,
          guides: false,
          showEgg: true,
          shadow: true,
        );
        final depths = scene.debugOcclusionDepths();
        expect(
          depths,
          everyElement(0.0),
          reason: 'Resting material must not occlude itself at $t',
        );
        final geometry = scene.debugGeometry();
        expect(
          geometry.positions,
          geometry.material,
          reason: 'Identity pose must cover the exact material footprint at $t',
        );
        final boundary = geometry.material
            .map((p) => Offset(p.$1, p.$2))
            .toList();
        final aperture = Path()..addPolygon(boundary, true);
        final outcome = await tester.runAsync(() async {
          final actualRecorder = ui.PictureRecorder();
          scene.paint(Canvas(actualRecorder), size);
          final actualPicture = actualRecorder.endRecording();
          final referenceRecorder = ui.PictureRecorder();
          final canvas = Canvas(referenceRecorder);
          final scale = size.width / 390;
          canvas.scale(scale);
          canvas.translate(186, size.height / scale * .82 - 220);
          var tilt = 0.0, rise = 0.0;
          for (final (start, peak, end, angle, lift) in episodes) {
            if (t <= start || t >= end) continue;
            final x = t < peak
                ? (t - start) / (peak - start)
                : (t - peak) / (end - peak);
            final smooth = x * x * x * (x * (x * 6 - 15) + 10);
            final weight = t < peak ? smooth : 1 - smooth;
            tilt += angle * weight;
            rise += lift * weight;
          }
          canvas.translate(0, -1.8 * 1.5 * rise);
          canvas.translate(0, 220);
          canvas.rotate(.01 * 1.5 * tilt);
          canvas.translate(0, -220);
          final matrix = Matrix4.fromList(canvas.getTransform());
          // Continuous reference material: no aperture, mesh, depth clipping,
          // second face or fragment-local shading.
          const bounds = Rect.fromLTWH(-115, -220, 230, 440);
          canvas.drawRect(
            bounds,
            Paint()
              ..shader = const RadialGradient(
                center: Alignment(-.5, -.6),
                radius: 1.4,
                colors: [
                  Color(0xffffd8a0),
                  Color(0xffd69b62),
                  Color(0xff956039),
                ],
              ).createShader(bounds),
          );
          final random = math.Random(37);
          for (var i = 0; i < 520; i++) {
            final spot = Offset(
              -115 + 230 * random.nextDouble(),
              -220 + 440 * random.nextDouble(),
            );
            canvas.drawCircle(
              spot,
              .3 + .08 * (i % 5),
              Paint()
                ..color = i % 4 == 0
                    ? const Color(0x14fff0d7)
                    : const Color(0x16825234),
            );
          }
          final referencePicture = referenceRecorder.endRecording();
          final actual = await actualPicture.toImage(
            size.width.ceil(),
            size.height.ceil(),
          );
          final reference = await referencePicture.toImage(
            size.width.ceil(),
            size.height.ceil(),
          );
          try {
            final a = (await actual.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final b = (await reference.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            var differences = 0, darkest = 0, samples = 0;
            for (var y = -130; y <= -29; y++) {
              for (var x = -12; x <= 83; x++) {
                final point = Offset(x.toDouble(), y.toDouble());
                // Stay on the egg: the rectangular reference intentionally
                // has no outer silhouette. Include a ring around the seam.
                if (!aperture.contains(point) &&
                    !boundary.any((p) => (p - point).distance < 4)) {
                  continue;
                }
                if (t > .256) {
                  // Existing cracks are legitimate; test the full interior,
                  // beyond the crack stroke and its antialiasing footprint.
                  if (!aperture.contains(point)) continue;
                  if (boundary.any((p) => (p - point).distance < 4)) continue;
                }
                final screen = MatrixUtils.transformPoint(matrix, point);
                final index =
                    (screen.dy.round() * actual.width + screen.dx.round()) * 4;
                samples++;
                var differs = false;
                for (var c = 0; c < 3; c++) {
                  final delta = b.getUint8(index + c) - a.getUint8(index + c);
                  darkest = math.max(darkest, delta);
                  // Split grain coverage can round by four 8-bit levels on
                  // one edge pixel; a flat dark region cannot pass this bound.
                  differs |= delta.abs() > 4;
                }
                if (differs) differences++;
              }
            }
            return (differences, darkest, samples);
          } finally {
            actual.dispose();
            reference.dispose();
            actualPicture.dispose();
            referencePicture.dispose();
          }
        });
        expect(outcome!.$3, greaterThan(3500));
        expect(
          outcome.$2,
          lessThanOrEqualTo(4),
          reason: 'No exposed dark interior at $size, $t',
        );
        if (outcome.$1 != 0) failures.add('$size t=$t: $outcome');
      }
    }
    expect(failures, isEmpty);
  });

  testWidgets('Lecture continue et meme parcours au ralenti x4', (
    tester,
  ) async {
    final clock = FragmentPlayback(vsync: tester);
    addTearDown(clock.dispose);
    Future<List<double>> sequence(bool slow) async {
      clock.reset();
      clock.slow = slow;
      clock.forward();
      await tester.pump();
      final values = [clock.value];
      for (var i = 0; i < 375; i++) {
        for (var sub = 0; sub < (slow ? 4 : 1); sub++) {
          final previous = clock.value;
          await tester.pump(const Duration(milliseconds: 16));
          expect(clock.value, greaterThanOrEqualTo(previous));
          expect(clock.value - previous, lessThanOrEqualTo(.016 / 6 + 1e-12));
        }
        values.add(clock.value);
      }
      return values;
    }

    final normal = await sequence(false);
    final slow = await sequence(true);
    expect(normal.last, closeTo(1, 1e-10));
    expect(slow.last, closeTo(1, 1e-10));
    for (var i = 0; i < normal.length; i++) {
      expect(slow[i], closeTo(normal[i], 1e-10));
    }
    for (final target in [
      .38,
      .495,
      .514,
      .524,
      .542,
      .552,
      .57,
      .583,
      .6,
      .62,
      .72,
    ]) {
      expect(
        normal.any((v) => (v - target).abs() <= .016 / 6),
        isTrue,
        reason: 'Must display a frame near $target',
      );
    }
    expect(normal.where((v) => v >= .495 && v <= .6).length, greaterThan(35));
  });

  testWidgets('Une frame tardive ne saute pas la phase attachee', (
    tester,
  ) async {
    final clock = FragmentPlayback(vsync: tester);
    addTearDown(clock.dispose);
    for (final slow in [false, true]) {
      clock.slow = slow;
      clock.forward(from: .49);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1140));
      final delta =
          FragmentPlayback.maxFrameTime.inMicroseconds /
          6000000 /
          (slow ? 4 : 1);
      expect(clock.value, closeTo(.49 + delta, 1e-12));
      final delayed = clock.value;
      await tester.pump(const Duration(milliseconds: 16));
      expect(clock.value, closeTo(delayed + .016 / 6 / (slow ? 4 : 1), 1e-12));
      // No retained debt is paid after resuming, changing speed, or seeking.
      clock.stop();
      final paused = clock.value;
      await tester.pump(const Duration(seconds: 2));
      expect(clock.value, paused);
      clock.slow = !slow;
      clock.forward();
      await tester.pump();
      expect(clock.value, paused);
      await tester.pump(const Duration(milliseconds: 16));
      expect(clock.value, closeTo(paused + .016 / 6 / (!slow ? 4 : 1), 1e-12));
    }
    clock.stop();
  });

  testWidgets('Atelier unifié : ouverture F1 et œuf intact', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());

    EggShellF1PreviewPainter f1Painter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<EggShellF1PreviewPainter>()
        .single;

    expect(find.text('Valider le modèle 3D unifié'), findsNothing);
    expect(find.text('Ralenti ×4'), findsNothing);
    expect(find.text('Format 9:20 (sinon 9:16)'), findsNothing);
    expect(find.text('Afficher l’œuf'), findsNothing);
    expect(find.text('Afficher les ombres'), findsNothing);
    expect(find.byType(FragmentScene), findsNothing);
    expect(f1Painter().thickness, 2.5);

    for (final opening in [0.0, .25, .50, .75, 1.0]) {
      tester.widget<Slider>(find.byType(Slider)).onChanged!(opening);
      await tester.pump();
      expect(f1Painter().openAmount, opening);
      expect(f1Painter().identifySurfaces, isFalse);
    }

    await tester.tap(find.text('Identifier les surfaces'));
    await tester.pump();
    expect(f1Painter().identifySurfaces, isTrue);
    await tester.tap(find.text('Afficher F1 3D seul'));
    await tester.pump();
    expect(
      tester.widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.painter)
          .whereType<EggShellModelPainter>()
          .length,
      1,
    );
    expect(find.byType(Slider), findsNothing);
    await tester.tap(find.text('Afficher F1 3D seul'));
    await tester.pump();
    expect(f1Painter().identifySurfaces, isTrue);
    expect(f1Painter().openAmount, 1);
  });

  FragmentScene frame(double progress) => FragmentScene(
    progress: progress,
    thickness: 2.5,
    motion: 0,
    guides: false,
    showEgg: true,
    shadow: false,
  );

  double distance((double, double, double) a, (double, double, double) b) =>
      (a.$1 - b.$1).abs() + (a.$2 - b.$2).abs() + (a.$3 - b.$3).abs();

  double distance3d((double, double, double) a, (double, double, double) b) {
    final dx = a.$1 - b.$1;
    final dy = a.$2 - b.$2;
    final dz = a.$3 - b.$3;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  test('Vol couple: le depart suit la normale locale en XZ', () {
    final lateral = <double>[];
    for (final index in [1, 2]) {
      final start = frame(0).debugFragmentFlight(index).detachmentProgress;
      final at = frame(start).debugFragmentFlight(index);
      final after = frame(start + .01).debugFragmentFlight(index);
      final dx = after.shift.$1 - at.shift.$1;
      final dz = after.shift.$3 - at.shift.$3;
      final nx = at.shellNormal.$1;
      final nz = at.shellNormal.$3;
      final dot = dx * nx + dz * nz;
      final cross = dx * nz - dz * nx;
      expect(dot, greaterThan(0), reason: 'Fragment ${index + 1}');
      expect(
        cross.abs(),
        lessThan(1e-8 + dot.abs() * 1e-8),
        reason: 'XZ launch must follow shell normal for fragment ${index + 1}',
      );
      expect(dz, greaterThan(0), reason: 'Outward Z for fragment ${index + 1}');
      lateral.add(dx.abs());
    }
    expect(
      lateral[1],
      greaterThan(lateral[0]),
      reason: 'The farther-left third plate inherits more lateral curvature',
    );
  });

  test('Vol couple: la gravite accelere progressivement la chute', () {
    for (final index in [1, 2]) {
      final start = frame(0).debugFragmentFlight(index).detachmentProgress;
      final a = frame(start + .06).debugFragmentFlight(index).shift.$2;
      final b = frame(start + .09).debugFragmentFlight(index).shift.$2;
      final c = frame(start + .12).debugFragmentFlight(index).shift.$2;
      expect(
        c - 2 * b + a,
        greaterThan(0),
        reason: 'Downward acceleration for fragment ${index + 1}',
      );
    }
  });

  test('Vol couple: aucun fragment ne recoit de coup vertical local', () {
    for (final index in [1, 2]) {
      final start = frame(0).debugFragmentFlight(index).detachmentProgress;
      final at = frame(start).debugFragmentFlight(index).shift.$2;
      final after = frame(start + .01).debugFragmentFlight(index).shift.$2;
      expect(
        after - at,
        greaterThanOrEqualTo(-1e-9),
        reason:
            'Gravity must take over Y immediately after release for '
            'fragment ${index + 1}',
      );
    }
  });

  test('Vol couple: avant rupture les voisins pivotent sans translation', () {
    final d2 = frame(0).debugFragmentFlight(1).detachmentProgress;
    final d3 = frame(0).debugFragmentFlight(2).detachmentProgress;
    final probe = math.min(d2, d3) - .01;

    for (final index in [1, 2]) {
      final snapshot = frame(probe).debugFragmentFlight(index);
      expect(
        distance3d(snapshot.shift, (0.0, 0.0, 0.0)),
        lessThan(1e-9),
        reason:
            'Attached fragment ${index + 1} must open by hinge rotation, '
            'not by rigid translation',
      );
    }
  });

  test('Vol couple: F2 et F3 basculent de part et autre de la pression', () {
    final d2 = frame(0).debugFragmentFlight(1).detachmentProgress;
    final d3 = frame(0).debugFragmentFlight(2).detachmentProgress;
    final probe = math.min(d2, d3) - .01;
    final r2 = frame(probe).debugFragmentFlight(1).rotation;
    final r3 = frame(probe).debugFragmentFlight(2).rotation;

    expect(r2.$1.abs(), greaterThan(.005));
    expect(r3.$1.abs(), greaterThan(.005));
    expect(
      r2.$1 * r3.$1,
      lessThan(0),
      reason:
          'The common pressure point lies between F2 and F3: their surviving '
          'hinges must therefore produce opposite pitch directions',
    );
  });

  test('Vol couple: position continue au passage de la derniere attache', () {
    const epsilon = 1e-6;
    for (final index in [1, 2]) {
      final start = frame(0).debugFragmentFlight(index).detachmentProgress;
      final before = frame(start - epsilon).debugFragmentFlight(index);
      final at = frame(start).debugFragmentFlight(index);
      final after = frame(start + epsilon).debugFragmentFlight(index);
      expect(
        distance(before.shift, after.shift),
        lessThan(.01),
        reason: 'Flight origin shift for fragment ${index + 1}',
      );
      expect(before.geometry.positions.length, at.geometry.positions.length);
      expect(at.geometry.positions.length, after.geometry.positions.length);
      for (var i = 0; i < at.geometry.positions.length; i++) {
        expect(
          distance(before.geometry.positions[i], after.geometry.positions[i]),
          lessThan(.02),
          reason: 'Release continuity fragment ${index + 1}, vertex $i',
        );
      }
    }
  });

  test('Vol couple: forme et epaisseur restent rigides apres rupture', () {
    for (final index in [1, 2]) {
      final start = frame(0).debugFragmentFlight(index).detachmentProgress;
      for (final offset in [.04, .10, .16]) {
        final snapshot = frame(start + offset).debugFragmentFlight(index);
        final g = snapshot.geometry;
        expect(g.retention, everyElement(0.0));
        expect(g.positions.length, g.innerPositions.length);
        for (var i = 0; i < g.positions.length; i++) {
          expect(
            distance3d(g.positions[i], g.innerPositions[i]),
            closeTo(2.5, 1e-8),
            reason: 'Thickness fragment ${index + 1}, vertex $i',
          );
          final j = (i + 1) % g.positions.length;
          expect(
            distance3d(g.positions[i], g.positions[j]),
            closeTo(distance3d(g.material[i], g.material[j]), 1e-8),
            reason: 'Rigid outline fragment ${index + 1}, edge $i',
          );
        }
      }
    }
  });

  test('Vol couple: rotation continue au passage en vol libre', () {
    const epsilon = 1e-6;
    for (final index in [1, 2]) {
      final start = frame(0).debugFragmentFlight(index).detachmentProgress;
      final before = frame(start - epsilon).debugFragmentFlight(index).rotation;
      final after = frame(start + epsilon).debugFragmentFlight(index).rotation;
      expect(
        distance3d(before, after),
        lessThan(.01),
        reason: 'Angular continuity fragment ${index + 1}',
      );
    }
  });

  test('Vol couple: les plaques gardent des rotations distinctes en chute', () {
    final starts = [
      frame(0).debugFragmentFlight(1).detachmentProgress,
      frame(0).debugFragmentFlight(2).detachmentProgress,
    ];
    final release2 = frame(starts[0]).debugFragmentFlight(1).rotation;
    final release3 = frame(starts[1]).debugFragmentFlight(2).rotation;
    final falling2 = frame(starts[0] + .12).debugFragmentFlight(1).rotation;
    final falling3 = frame(starts[1] + .12).debugFragmentFlight(2).rotation;

    expect(distance3d(release2, falling2), greaterThan(1e-4));
    expect(distance3d(release3, falling3), greaterThan(1e-4));
    expect(
      distance3d(falling2, falling3),
      greaterThan(.02),
      reason: 'Coupled plates must not converge to one shared fall angle',
    );
  });

  test('Vol couple: les voisins se liberent dans la meme poussee', () {
    final reference = frame(0).debugFragmentFlight(0).detachmentProgress;
    final neighbor = frame(0).debugFragmentFlight(1).detachmentProgress;
    final third = frame(0).debugFragmentFlight(2).detachmentProgress;
    final coupledSpread = (neighbor - third).abs();
    final latestCoupled = math.max(neighbor, third);

    expect(
      coupledSpread,
      lessThan(.035),
      reason:
          'F2 and F3 must overlap under the same chick pressure: '
          'F2=$neighbor F3=$third',
    );
    expect(
      latestCoupled - reference,
      lessThan(.07),
      reason:
          'Coupled plates must release close to F1, not as a later sequence: '
          'F1=$reference F2=$neighbor F3=$third',
    );
  });

  test(
    'Les zones intactes restent soudees; les ruptures liberent la meme matiere',
    () {
      final rest = frame(0).debugGeometry();
      const samples = [
        .494999,
        .495001,
        .51,
        .533,
        .543,
        .561,
        .571,
        .591,
        .599999,
        .600001,
        .62,
      ];
      const expectedHeld = [3, 3, 3, 3, 2, 2, 1, 1, 1, 0, 0];
      for (var s = 0; s < samples.length; s++) {
        final g = frame(samples[s]).debugGeometry();
        expect(
          g.minimumAreaRatio,
          greaterThan(0),
          reason: 'No folded or overlapping material at ${samples[s]}',
        );
        expect(
          g.material,
          rest.material,
          reason: 'Immutable fracture at ${samples[s]}',
        );
        expect(g.holds.where((h) => h > 0).length, expectedHeld[s]);
        const anchors = [Offset(-7, -75), Offset(13, -34), Offset(9, -108)];
        for (var a = 0; a < anchors.length; a++) {
          if (g.holds[a] <= 0) continue;
          final index = g.material.indexWhere(
            (p) => (Offset(p.$1, p.$2) - anchors[a]).distance < 1e-8,
          );
          expect(index, greaterThanOrEqualTo(0));
          expect(
            distance(g.material[index], g.positions[index]),
            lessThan(1e-10),
            reason:
                'Surviving ligament $a must remain connected at ${samples[s]}',
          );
        }
        var welded = 0;
        for (var i = 0; i < g.material.length; i++) {
          if (g.retention[i] == 1) {
            welded++;
            expect(
              distance(g.material[i], g.positions[i]),
              lessThan(1e-10),
              reason: 'Welded boundary at ${samples[s]}, vertex $i',
            );
          }
          if (samples[s] >= .617) {
            expect(distance(g.positions[i], g.rigid[i]), lessThan(1e-10));
          }
        }
        if (expectedHeld[s] > 0) expect(welded, greaterThan(expectedHeld[s]));
      }
      final moving = frame(.51).debugGeometry();
      expect(
        List.generate(
          moving.material.length,
          (i) => distance(moving.material[i], moving.positions[i]),
        ).reduce((a, b) => a > b ? a : b),
        greaterThan(1),
      );
    },
  );

  test('Position et vitesse continues aux seuils et aux fins de rupture', () {
    const epsilon = 1e-7;
    for (final t in [
      .495,
      .524,
      .542,
      .552,
      .56,
      .57,
      .583,
      .588,
      .6,
      .614,
      .617,
    ]) {
      final before = frame(t - epsilon).debugGeometry();
      final at = frame(t).debugGeometry();
      final after = frame(t + epsilon).debugGeometry();
      for (var i = 0; i < at.positions.length; i++) {
        final a = before.positions[i],
            b = at.positions[i],
            c = after.positions[i];
        expect(
          distance(a, c),
          lessThan(.001),
          reason: 'Position t=$t, vertex $i',
        );
        final left = (
          (b.$1 - a.$1) / epsilon,
          (b.$2 - a.$2) / epsilon,
          (b.$3 - a.$3) / epsilon,
        );
        final right = (
          (c.$1 - b.$1) / epsilon,
          (c.$2 - b.$2) / epsilon,
          (c.$3 - b.$3) / epsilon,
        );
        expect(
          distance(left, right),
          lessThan(2),
          reason: 'Velocity t=$t, vertex $i',
        );
      }
    }
  });

  testWidgets('Aucun basculement raster de toute la plaque a .495 ou .6', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 693));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Future<List<int>> pixels(double t) async {
      await tester.pumpWidget(
        RepaintBoundary(
          child: CustomPaint(painter: frame(t), child: const SizedBox.expand()),
        ),
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      return (await tester.runAsync(() async {
        final image = await boundary.toImage();
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          return bytes.buffer.asUint8List().toList();
        } finally {
          image.dispose();
        }
      }))!;
    }

    for (final t in [.495, .542, .57, .6]) {
      final a = await pixels(t - .000001);
      final b = await pixels(t + .000001);
      var changed = 0;
      // Full fragment and border, not just one interior sample.
      for (var y = 210; y < 340; y++) {
        for (var x = 165; x < 280; x++) {
          final i = (y * 390 + x) * 4;
          if (List.generate(
            3,
            (c) => (a[i + c] - b[i + c]).abs(),
          ).any((d) => d > 3)) {
            changed++;
          }
        }
      }
      expect(changed, lessThan(20), reason: 'Surface jump at $t');
    }
    for (final t in [.51, .543, .571, .599999, .600001]) {
      await pixels(t);
      expect(tester.takeException(), isNull);
    }

    // Independent intact-surface reference: no aperture and no fragment mesh.
    // This detects a permanent seam that comparisons across .495 would miss.
    final intact = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..translate(186, 693 * .82 - 220);
      const bounds = Rect.fromLTWH(-115, -220, 230, 440);
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-.5, -.6),
            radius: 1.4,
            colors: [Color(0xffffd8a0), Color(0xffd69b62), Color(0xff956039)],
          ).createShader(bounds),
      );
      final random = math.Random(37);
      for (var i = 0; i < 520; i++) {
        final point = Offset(
          -115 + 230 * random.nextDouble(),
          -220 + 440 * random.nextDouble(),
        );
        canvas.drawCircle(
          point,
          .3 + .08 * (i % 5),
          Paint()
            ..color = i % 4 == 0
                ? const Color(0x14fff0d7)
                : const Color(0x16825234),
        );
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(390, 693);
      try {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        return bytes.buffer.asUint8List().toList();
      } finally {
        image.dispose();
        picture.dispose();
      }
    });
    final resting = await pixels(0);
    var seamPixels = 0;
    for (final point in frame(0).debugGeometry().material) {
      final x = (186 + point.$1).round(),
          y = (693 * .82 - 220 + point.$2).round();
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final i = ((y + dy) * 390 + x + dx) * 4;
          if (List.generate(
            3,
            (c) => (resting[i + c] - intact![i + c]).abs(),
          ).any((d) => d > 3)) {
            seamPixels++;
          }
        }
      }
    }
    expect(
      seamPixels,
      0,
      reason: 'Resting partition must not announce its perimeter',
    );
  });

  testWidgets('La surface garde sa couleur au début du détachement', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 693));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    Future<List<int>> sample(double progress) async {
      await tester.pumpWidget(
        RepaintBoundary(
          child: CustomPaint(
            painter: FragmentScene(
              progress: progress,
              thickness: 2.5,
              motion: 0,
              guides: false,
              showEgg: true,
              shadow: false,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      final rgba = await tester.runAsync(() async {
        final image = await boundary.toImage();
        try {
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final offset = (265 * image.width + 240) * 4;
          return List<int>.generate(4, (i) => bytes!.getUint8(offset + i));
        } finally {
          image.dispose();
        }
      });
      return rgba!;
    }

    final resting = await sample(0);
    // Pressure peaks, former transition and actual moving-face handoff.
    for (final progress in [.43, .45, .482, .495, .495001, .496]) {
      final surface = await sample(progress);
      for (var channel = 0; channel < 3; channel++) {
        expect(
          (resting[channel] - surface[channel]).abs(),
          lessThanOrEqualTo(1),
          reason: 'Material continuity at progress $progress, channel $channel',
        );
      }
    }
  });
}
