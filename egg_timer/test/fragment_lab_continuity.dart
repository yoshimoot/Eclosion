import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:egg_timer/lab/fragment_scene.dart';
import 'package:egg_timer/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object> _poseMetrics(FragmentGeometrySnapshot geometry) {
  List<double> normal(List<(double, double, double)> points) {
    final a = points[0],
        b = points[points.length ~/ 3],
        c = points[2 * points.length ~/ 3];
    final u = [b.$1 - a.$1, b.$2 - a.$2, b.$3 - a.$3],
        v = [c.$1 - a.$1, c.$2 - a.$2, c.$3 - a.$3];
    final n = [
      u[1] * v[2] - u[2] * v[1],
      u[2] * v[0] - u[0] * v[2],
      u[0] * v[1] - u[1] * v[0],
    ];
    final length = math.sqrt(n.fold(0.0, (s, x) => s + x * x));
    return n.map((x) => x / length).toList();
  }

  final restNormal = normal(geometry.material),
      movedNormal = normal(geometry.rigid);
  final dot = List.generate(
    3,
    (i) => restNormal[i] * movedNormal[i],
  ).reduce((a, b) => a + b);
  var weightedGap = 0.0, perimeter = 0.0;
  final centroid = [0.0, 0.0, 0.0];
  for (var i = 0; i < geometry.material.length; i++) {
    final j = (i + 1) % geometry.material.length;
    final a = geometry.material[i],
        b = geometry.material[j],
        p = geometry.positions[i],
        q = geometry.positions[j];
    final length = (Offset(b.$1, b.$2) - Offset(a.$1, a.$2)).distance;
    weightedGap +=
        length *
        ((Offset(p.$1, p.$2) - Offset(a.$1, a.$2)).distance +
            (Offset(q.$1, q.$2) - Offset(b.$1, b.$2)).distance) /
        2;
    perimeter += length;
    centroid[0] += p.$1;
    centroid[1] += p.$2;
    centroid[2] += p.$3;
  }
  return {
    'boundaryCentroid': centroid
        .map((v) => v / geometry.positions.length)
        .toList(),
    'rigidNormalRotationDegrees':
        math.acos(dot.clamp(-1.0, 1.0)) * 180 / math.pi,
    'meanProjectedBorderGap': weightedGap / perimeter,
  };
}

// Registered by widget_test.dart so the repository's required command includes it.
void fragmentLabContinuityTests() {
  testWidgets('Appartenance: contours, triangles et pixels de la partition', (
    tester,
  ) async {
    final reports = <Map<String, Object>>[];
    for (final height in [390 * 16 / 9, 390 * 20 / 9]) {
      for (final t in [
        .495,
        .499,
        .500,
        .501,
        .510,
        .524,
        .552,
        .583,
        .600,
        .620,
        .720,
      ]) {
        await tester.runAsync(() async {
          FragmentPaintDiagnostics? painted;
          final recorder = ui.PictureRecorder();
          FragmentScene(
            progress: t,
            thickness: 2.5,
            motion: 1.5,
            guides: false,
            showEgg: true,
            shadow: false,
            identifySurfaces: true,
            onDiagnostics: (value) => painted = value,
          ).paint(Canvas(recorder), Size(390, height));
          final picture = recorder.endRecording();
          final image = await picture.toImage(390, height.ceil());
          try {
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final probe = painted!.probe!;
            var grayInsideEgg = 0,
                contourWithoutTriangles = 0,
                boundaryPixels = 0;
            // Whole aperture plus a margin, including background outside egg.
            // Evaluate membership at the SAME pixel center as the raster sample.
            final observed = <String, int>{};
            for (var y = -136.0; y < -13; y += 2) {
              for (var x = -20.0; x < 104; x += 2) {
                final canvasPoint = probe.toCanvas(Offset(x, y));
                final px = canvasPoint.dx.floor(), py = canvasPoint.dy.floor();
                final point = probe.at(probe.toEgg(Offset(px + .5, py + .5)));
                final pixel = 4 * (py * image.width + px);
                final surface = FragmentSurfaceColors.classify([
                  data.getUint8(pixel),
                  data.getUint8(pixel + 1),
                  data.getUint8(pixel + 2),
                ]);
                observed[surface] = (observed[surface] ?? 0) + 1;
                if (point['insideFragmentOuterFace'] == true &&
                    point['insideOuterTriangles'] == false) {
                  contourWithoutTriangles++;
                }
                if (surface == 'background' && point['insideEgg'] == true) {
                  grayInsideEgg++;
                }
                expect(
                  surface == 'background' &&
                      point['expectedSurface'] != 'background',
                  isFalse,
                  reason: 'Missing surface p=$t height=$height: $point',
                );
                expect(
                  point['paintCoverageSurface'],
                  point['expectedSurface'],
                  reason: 'Geometry/paint coverage p=$t: $point',
                );
                if (surface != 'mixedOrCrack' &&
                    surface != point['expectedSurface']) {
                  // A pixel integrates an area, and shell grain circles can
                  // cross a material edge by <= .62 scene units. Accept an
                  // owner only if it exists within ONE pixel of this center.
                  final neighborOwners = <Object?>{};
                  for (final dx in [-1.0, 0.0, 1.0]) {
                    for (final dy in [-1.0, 0.0, 1.0]) {
                      neighborOwners.add(
                        probe.at(
                          probe.toEgg(Offset(px + .5 + dx, py + .5 + dy)),
                        )['expectedSurface'],
                      );
                    }
                  }
                  expect(
                    neighborOwners,
                    contains(surface),
                    reason:
                        'Raster owner absent from pixel neighborhood p=$t: $point',
                  );
                  boundaryPixels++;
                }
              }
            }
            expect(contourWithoutTriangles, 0);
            expect(grayInsideEgg, 0);
            final roi = probe.rasterReport(
              data,
              image.width,
              image.height,
              1,
              probe.toCanvas(const Offset(32, -76)),
            );
            if (t <= .600) {
              expect((roi['point'] as Map)['insideFragmentOuterFace'], isTrue);
              expect((roi['point'] as Map)['insideOuterTriangles'], isTrue);
              expect((roi['point'] as Map)['finalRenderedSurface'], 'outer');
            }
            expect(roi['backgroundWhereSurfaceExpected'], 0);
            if (t == .500) {
              // Sensitivity check for case A: erase a real cyan pixel only in
              // this test's captured bytes. The probe must detect the missing
              // raster coverage despite intact contours, triangles and clips.
              final selected = probe.toCanvas(const Offset(32, -76));
              final offset =
                  4 * (selected.dy.floor() * image.width + selected.dx.floor());
              final channels = [
                for (var c = 0; c < 3; c++) data.getUint8(offset + c),
              ];
              for (var c = 0; c < 3; c++) {
                data.setUint8(offset + c, 96);
              }
              final erased = probe.rasterReport(
                data,
                image.width,
                image.height,
                1,
                selected,
              );
              expect((erased['point'] as Map)['expectedSurface'], 'outer');
              expect(
                (erased['point'] as Map)['finalRenderedSurface'],
                'background',
              );
              expect(erased['backgroundWhereSurfaceExpected'], 1);
              for (var c = 0; c < 3; c++) {
                data.setUint8(offset + c, channels[c]);
              }
            }
            final row = <String, Object>{
              'progress': t,
              'height': height,
              'roi': roi,
              'wholeFootprintSamples': observed,
              'grayInsideEgg': grayInsideEgg,
              'contourWithoutTriangles': contourWithoutTriangles,
              'boundaryPixels': boundaryPixels,
            };
            reports.add(row);
            debugPrint(
              'OWNERSHIP p=$t height=$height: grayInsideEgg=$grayInsideEgg, '
              'missingTriangles=$contourWithoutTriangles, ROI=${roi['renderedPercent']}',
            );
          } finally {
            image.dispose();
            picture.dispose();
          }
        });
      }
    }
    if (Platform.environment['ECLOSION_EXPORT_CAPTURES'] == '1') {
      await tester.runAsync(() async {
        final file = File('build/fragment_lab_diagnostics/ownership.json');
        await file.parent.create(recursive: true);
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(reports),
        );
      });
    }
  });

  testWidgets('Sonde: clic, pixels DPR 2 et copie de la meme frame', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() async {
      tester.view.resetDevicePixelRatio();
      await tester.binding.setSurfaceSize(null);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    for (final (label, value) in [
      ('Repères de cadrage', false),
      ('Afficher les ombres', false),
      ('Identifier les surfaces', true),
    ]) {
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, label),
          )
          .onChanged!(value);
      await tester.pump();
    }
    tester.widget<Slider>(find.byType(Slider)).onChanged!(.524);
    await tester.pump();
    final sceneFinder = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is FragmentScene,
    );
    final rect = tester.getRect(sceneFinder),
        scale = tester.getSize(sceneFinder).width / 390;
    for (final (local, owner) in [
      (
        Offset(218 * scale, (rect.height / scale * .82 - 220 - 76) * scale),
        'outer',
      ),
      (Offset(20 * scale, 180 * scale), 'background'),
    ]) {
      await tester.tapAt(rect.topLeft + local);
      // toImage completes outside the fake clock. Bound the wait and fail if
      // the UI never receives a captured report instead of trusting geometry.
      for (var i = 0; i < 100; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        if (find.textContaining('Sonde figée').evaluate().isNotEmpty) break;
      }
      await tester.pump();
      expect(find.textContaining('Sonde figée'), findsOneWidget);
      final copy = find
          .ancestor(
            of: find.text('Copier les réglages'),
            matching: find.byWidgetPredicate((w) => w is OutlinedButton),
          )
          .first;
      tester.widget<OutlinedButton>(copy).onPressed!();
      await tester.pump();
      final report =
          jsonDecode(copied!.split('\n').last) as Map<String, dynamic>;
      final capture = report['surfaceProbeCapture'] as Map<String, dynamic>;
      expect(capture['paintedProgress'], .524);
      expect(capture['pixelRatio'], 2);
      expect(capture['roiPixels'], 1024);
      expect(capture['backgroundWhereSurfaceExpected'], 0);
      final point = capture['point'] as Map;
      expect(point['expectedSurface'], owner);
      expect(point['paintCoverageSurface'], owner);
      expect(point['finalRenderedSurface'], owner);
      expect(capture['renderedPercent'], {owner: 100.0});
      expect(tester.widget<Slider>(find.byType(Slider)).value, .524);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('FragmentLab: meme image en lecture et en reglage direct', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async {
      tester.view.resetDevicePixelRatio();
      await tester.binding.setSurfaceSize(null);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    final captureKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: captureKey, child: const MyApp()),
    );
    await tester.pumpAndSettle();
    final sceneFinder = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is FragmentScene,
    );
    FragmentScene scene() =>
        tester.widget<CustomPaint>(sceneFinder).painter! as FragmentScene;
    Future<void> seek(double t) async {
      tester.widget<Slider>(find.byType(Slider)).onChanged!(t);
      await tester.pump();
    }

    // Fracture ROI includes the entire plate and a margin, never UI text.
    final sceneRect = tester.getRect(sceneFinder);
    final scale = sceneRect.width / 390;
    final base = sceneRect.height / scale * .82 - 220;
    final roi = Rect.fromLTRB(
      sceneRect.left + 165 * scale,
      sceneRect.top + (base - 138) * scale,
      sceneRect.left + 280 * scale,
      sceneRect.top + (base - 13) * scale,
    );
    final export = Platform.environment['ECLOSION_EXPORT_CAPTURES'] == '1';
    final reports = <Map<String, Object?>>[];
    var worstArrivalDifference = 0;
    const samples = [
      .480,
      .490,
      .494,
      .495,
      .496,
      .499,
      .500,
      .501,
      .505,
      .510,
      .524,
      .600,
      .720,
      .880,
    ];

    Future<List<int>> capture(String mode, bool shadows, double target) async {
      final painter = scene();
      expect(painter.progress, closeTo(target, 1e-7));
      expect(painter.thickness, 2.5);
      expect(painter.motion, 1.5);
      expect(painter.showEgg, isTrue);
      expect(painter.shadow, shadows);
      expect(tester.getRect(sceneFinder), sceneRect);
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        painter.progress,
      );
      final geometry = painter.debugGeometry();
      final copyButton = find
          .ancestor(
            of: find.text('Copier les réglages'),
            matching: find.byWidgetPredicate((w) => w is OutlinedButton),
          )
          .first;
      tester.widget<OutlinedButton>(copyButton).onPressed!();
      await tester.pump();
      final report =
          jsonDecode(copied!.split('\n').last) as Map<String, dynamic>;
      expect(report['paintedProgress'], painter.progress);
      expect(report['devicePixelRatio'], 1);
      expect(
        report['visibleInteriorAreaSampled'],
        lessThanOrEqualTo(report['openingAreaSampled'] as num),
      );
      if (target <= .495) expect(report['visibleInteriorAreaSampled'], 0);
      if (target < .524) expect(geometry.holds, everyElement(1.0));
      final row = <String, Object?>{
        ...report,
        ..._poseMetrics(geometry),
        'arrival': mode,
        'target': target,
      };
      reports.add(row);
      debugPrint(
        'LAB $mode shadows=$shadows p=${painter.progress}: '
        'opening=${report['openingAreaSampled']}, visible=${report['visibleInteriorAreaSampled']}, '
        'maxGap=${report['maxBorderGap']}, holds=${report['holds']}',
      );
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      return (await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final pixels = <int>[];
          for (var y = roi.top.floor(); y < roi.bottom.ceil(); y++) {
            for (var x = roi.left.floor(); x < roi.right.ceil(); x++) {
              final offset = (y * image.width + x) * 4;
              pixels.addAll([
                bytes.getUint8(offset),
                bytes.getUint8(offset + 1),
                bytes.getUint8(offset + 2),
              ]);
            }
          }
          if (export && [.494, .495, .496, .500, .510, .524].contains(target)) {
            final recorder = ui.PictureRecorder();
            Canvas(recorder).drawImageRect(
              image,
              sceneRect,
              Rect.fromLTWH(0, 0, sceneRect.width, sceneRect.height),
              Paint(),
            );
            final picture = recorder.endRecording();
            final preview = await picture.toImage(
              sceneRect.width.ceil(),
              sceneRect.height.ceil(),
            );
            try {
              final png = (await preview.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              final file = File(
                'build/fragment_lab_diagnostics/${shadows ? 'shadow' : 'no_shadow'}_${mode}_${target.toStringAsFixed(3)}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(png.buffer.asUint8List());
            } finally {
              preview.dispose();
              picture.dispose();
            }
          }
          return pixels;
        } finally {
          image.dispose();
        }
      }))!;
    }

    // The app has no scene image assets; geometry, shaders and seeded grain
    // are the production ones. Native flutter_tester, not the Chrome engine.
    tester
        .widget<CheckboxListTile>(
          find.widgetWithText(CheckboxListTile, 'Repères de cadrage'),
        )
        .onChanged!(false);
    await tester.pump();
    for (final shadows in [false, true]) {
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Afficher les ombres'),
          )
          .onChanged!(shadows);
      await tester.pump();
      final direct = <double, List<int>>{};
      List<int>? previous;
      double? previousT;
      for (final t in samples) {
        await seek(t);
        final pixels = await capture('direct', shadows, t);
        direct[t] = pixels;
        if (previous != null && t <= .524) {
          var total = 0, maximum = 0;
          for (var i = 0; i < pixels.length; i++) {
            final difference = (pixels[i] - previous[i]).abs();
            total += difference;
            maximum = math.max(maximum, difference);
          }
          debugPrint(
            'LAB raster shadows=$shadows $previousT->$t: meanRGB=${total / pixels.length}, maxRGB=$maximum',
          );
        }
        previous = pixels;
        previousT = t;
      }
      await seek(samples.first);
      await tester.tap(find.text('Lire'));
      await tester.pump();
      for (final t in samples) {
        while (true) {
          final remaining = ((t - scene().progress) * 6000000).round();
          if (remaining <= 0) break;
          await tester.pump(Duration(microseconds: math.min(16000, remaining)));
        }
        final automatic = await capture('automatic', shadows, t);
        var maxDifference = 0;
        for (var i = 0; i < automatic.length; i++) {
          maxDifference = math.max(
            maxDifference,
            (automatic[i] - direct[t]![i]).abs(),
          );
        }
        // Only 8-bit rounding tolerance for sub-ulp accumulated clock error;
        // a stale paint, changed geometry or phase mapping cannot pass this.
        expect(
          maxDifference,
          lessThanOrEqualTo(1),
          reason: 'Direct/automatic image mismatch at $t, shadows=$shadows',
        );
        worstArrivalDifference = math.max(
          worstArrivalDifference,
          maxDifference,
        );
        reports.last['arrivalMaxChannelDifference'] = maxDifference;
      }
      await tester.tap(find.text('Pause'));
      await tester.pump();
      for (final t in [.494, .495, .496, .500, .510, .524]) {
        await seek(t);
        final geometry = scene().debugGeometry();
        final identityControl = find.widgetWithText(
          CheckboxListTile,
          'Identifier les surfaces',
        );
        tester.widget<CheckboxListTile>(identityControl).onChanged!(true);
        await tester.pump();
        expect(scene().identifySurfaces, isTrue);
        expect(scene().debugGeometry().positions, geometry.positions);
        final pixels = await capture('surfaces', shadows, t);
        final counts = <String, int>{};
        for (final entry in {
          'outer': FragmentSurfaceColors.outer,
          'inner': FragmentSurfaceColors.inner,
          'rim': FragmentSurfaceColors.rim,
          'cavity': FragmentSurfaceColors.cavity,
          'shell': FragmentSurfaceColors.shell,
          'background': FragmentSurfaceColors.background,
        }.entries) {
          final argb = entry.value.toARGB32();
          var count = 0;
          for (var i = 0; i < pixels.length; i += 3) {
            if ((pixels[i] - ((argb >> 16) & 255)).abs() <= 1 &&
                (pixels[i + 1] - ((argb >> 8) & 255)).abs() <= 1 &&
                (pixels[i + 2] - (argb & 255)).abs() <= 1) {
              count++;
            }
          }
          counts[entry.key] = count;
        }
        expect(counts['inner'], 0, reason: 'No back face at $t');
        expect(
          counts['outer'],
          greaterThan(0),
          reason: 'Outer mesh is painted at $t',
        );
        reports.last['surfacePixels'] = counts;
        debugPrint('SURFACES shadows=$shadows $t: $counts');
        tester.widget<CheckboxListTile>(identityControl).onChanged!(false);
        await tester.pump();
        final restored = await capture('restored', shadows, t);
        expect(
          restored,
          direct[t],
          reason: 'Diagnostic must not alter normal rendering at $t',
        );
      }
    }
    if (export) {
      await tester.runAsync(
        () => File('build/fragment_lab_diagnostics/measurements.json')
            .writeAsString(const JsonEncoder.withIndent('  ').convert(reports)),
      );
    }
    expect(tester.takeException(), isNull);
    debugPrint(
      'LAB direct/automatic maximum channel difference: $worstArrivalDifference',
    );
  });
}
