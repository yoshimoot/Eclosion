import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:egg_timer/lab/fragment_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Independent-depth differential: fixed-shell strokes must never replace the
// opaque material in front. Mobile cracks remain present in both renders.
void fragmentOcclusionTests() {
  testWidgets('Levre fixe: epaisseur, exposition et occlusion', (tester) async {
    for (final t in [0.0, .495, .600, .620]) {
      await tester.runAsync(() async {
        FragmentPaintDiagnostics? report;
        final recorder = ui.PictureRecorder();
        FragmentScene(
          progress: t,
          thickness: 2.5,
          motion: 1.5,
          guides: false,
          showEgg: true,
          shadow: false,
          identifySurfaces: true,
          onDiagnostics: (value) => report = value,
        ).paint(Canvas(recorder)..scale(2), const Size(390, 390 * 16 / 9));
        final picture = recorder.endRecording();
        final image = await picture.toImage(780, (390 * 16 / 9 * 2).ceil());
        picture.dispose();
        FragmentPaintDiagnostics? normalReport;
        final normalRecorder = ui.PictureRecorder();
        FragmentScene(
          progress: t,
          thickness: 2.5,
          motion: 1.5,
          guides: false,
          showEgg: true,
          shadow: false,
          identifySurfaces: false,
          onDiagnostics: (value) => normalReport = value,
        ).paint(
          Canvas(normalRecorder)..scale(2),
          const Size(390, 390 * 16 / 9),
        );
        final normalPicture = normalRecorder.endRecording();
        final normalImage = await normalPicture.toImage(
          780,
          (390 * 16 / 9 * 2).ceil(),
        );
        normalPicture.dispose();
        try {
          final probe = report!.probe!;
          expect(normalReport!.fixedLipFaces, report!.fixedLipFaces);
          final normalBytes = (await normalImage.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          var orange = 0, green = 0, lipSamples = 0;
          var contactLength = 0.0;
          final zones = <String, int>{};
          var minX = double.infinity, maxX = double.negativeInfinity;
          var minY = double.infinity, maxY = double.negativeInfinity;
          for (var i = 0; i < bytes.lengthInBytes; i += 4) {
            final r = bytes.getUint8(i),
                g = bytes.getUint8(i + 1),
                b = bytes.getUint8(i + 2);
            if (r == 255 && g == 120 && b == 0) orange++;
            if (r == 0 && g == 224 && b == 80) {
              green++;
              // The validated green footprint must be actual shell material
              // in normal paint, never the green marker or bare dark cavity.
              expect(normalBytes.getUint8(i), greaterThan(105));
            }
          }
          for (final wall in report!.fixedLipFaces) {
            for (final (a, b) in [(wall[0], wall[3]), (wall[1], wall[2])]) {
              final length = math.sqrt(
                math.pow(a.$1 - b.$1, 2) +
                    math.pow(a.$2 - b.$2, 2) +
                    math.pow(a.$3 - b.$3, 2),
              );
              expect(length, closeTo(2.5, 1e-10));
              expect(b.$3, lessThan(a.$3));
            }
            final a = Offset(wall[0].$1, wall[0].$2),
                b = Offset(wall[1].$1, wall[1].$2);
            final innerA = Offset(wall[3].$1, wall[3].$2),
                innerB = Offset(wall[2].$1, wall[2].$2);
            for (var i = 0; i < 20; i++) {
              final u = (i + .5) / 20;
              final p = Offset.lerp(
                Offset.lerp(a, b, u),
                Offset.lerp(innerA, innerB, u),
                .01,
              )!;
              if (probe.fixedLip!.contains(p)) {
                contactLength += (b - a).distance / 20;
              }
            }
          }
          // Area in egg coordinates, independent of antialiasing at a thin lip.
          for (var y = -140.0; y < 0; y += .1) {
            for (var x = -25.0; x < 110; x += .1) {
              final p = Offset(x, y);
              if (!probe.fixedLip!.contains(p)) continue;
              lipSamples++;
              final zone = x < 35
                  ? 'gauche'
                  : y < -90
                  ? 'haut-droit'
                  : 'droit-bas';
              zones.update(zone, (v) => v + 1, ifAbsent: () => 1);
              expect(probe.opening.contains(p), isTrue);
              expect(probe.aperture.contains(p), isTrue);
              expect(
                probe.faces.any((face) => face.$2.contains(p)) &&
                    probe.visibility!.contains(p),
                isFalse,
              );
              minX = math.min(minX, x);
              maxX = math.max(maxX, x);
              minY = math.min(minY, y);
              maxY = math.max(maxY, y);
            }
          }
          debugPrint(
            'FIXED_LIP p=$t mobilePixels=$orange fixedPixels=$green area=${lipSamples * .01} contactLength=$contactLength zones=$zones bounds=[$minX,$minY,$maxX,$maxY]',
          );
          if (t <= .495) {
            expect(lipSamples, 0);
            expect(green, 0);
          } else {
            expect(lipSamples, greaterThan(0));
            expect(green, greaterThan(0));
          }
        } finally {
          image.dispose();
          normalImage.dispose();
        }
      });
    }
  });

  testWidgets('Cavite: paroi concave continue et composition de ouverture', (
    tester,
  ) async {
    final spans = <int>[];
    final materialSamples = <Offset, List<List<int>>>{};
    for (final t in [.59, .60, .62, .65]) {
      await tester.runAsync(() async {
        Future<(ui.Image, ByteData, FragmentPaintDiagnostics)> render(
          bool identify,
          bool shadow,
        ) async {
          FragmentPaintDiagnostics? report;
          final recorder = ui.PictureRecorder();
          FragmentScene(
            progress: t,
            thickness: 2.5,
            motion: 1.5,
            guides: false,
            showEgg: true,
            shadow: shadow,
            identifySurfaces: identify,
            onDiagnostics: (value) => report = value,
          ).paint(Canvas(recorder)..scale(2), const Size(390, 390 * 16 / 9));
          final picture = recorder.endRecording();
          final image = await picture.toImage(780, (390 * 16 / 9 * 2).ceil());
          picture.dispose();
          return (
            image,
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!,
            report!,
          );
        }

        final diagnostic = await render(true, false);
        final normal = await render(false, false);
        final shadowed = await render(false, true);
        try {
          final probe = diagnostic.$3.probe!;
          final counts = <String, int>{};
          var minRed = 255,
              maxRed = 0,
              shadowChanges = 0,
              cavityShadowChanges = 0;
          var cavitySamples = 0;
          bool cavity(int x, int y) {
            final i = 4 * (y * diagnostic.$1.width + x);
            return diagnostic.$2.getUint8(i) == 40 &&
                diagnostic.$2.getUint8(i + 1) == 80 &&
                diagnostic.$2.getUint8(i + 2) == 255;
          }

          for (var y = 350; y < 720; y++) {
            for (var x = 290; x < 610; x++) {
              final p = probe.toEgg(Offset((x + .5) / 2, (y + .5) / 2));
              if (!probe.aperture.contains(p)) continue;
              final i = 4 * (y * diagnostic.$1.width + x);
              final owner = FragmentSurfaceColors.classify([
                for (var c = 0; c < 3; c++) diagnostic.$2.getUint8(i + c),
              ]);
              counts.update(owner, (v) => v + 1, ifAbsent: () => 1);
              final changed = List.generate(
                3,
                (c) => (normal.$2.getUint8(i + c) - shadowed.$2.getUint8(i + c))
                    .abs(),
              ).any((v) => v > 2);
              if (changed) shadowChanges++;
              if (!cavity(x, y) ||
                  !cavity(x - 2, y) ||
                  !cavity(x + 2, y) ||
                  !cavity(x, y - 2) ||
                  !cavity(x, y + 2)) {
                continue;
              }
              cavitySamples++;
              if (changed) cavityShadowChanges++;
              minRed = math.min(minRed, normal.$2.getUint8(i));
              maxRed = math.max(maxRed, normal.$2.getUint8(i));
            }
          }
          debugPrint(
            'CAVITY p=$t aperturePixels=$counts shadowChanges=$shadowChanges cavityShadowChanges=$cavityShadowChanges core=$cavitySamples red=$minRed..$maxRed',
          );
          // The same inner-wall location must retain its lighting as the egg
          // moves and the fragment uncovers it. No progress-driven color ramp.
          for (var y = -116.0; y < -24; y += 4) {
            for (var x = -12.0; x < 96; x += 4) {
              final material = Offset(x, y),
                  screen = probe.toCanvas(Offset(x, y));
              final px = (screen.dx * 2).floor(), py = (screen.dy * 2).floor();
              if (!cavity(px, py) ||
                  !cavity(px - 2, py) ||
                  !cavity(px + 2, py) ||
                  !cavity(px, py - 2) ||
                  !cavity(px, py + 2)) {
                continue;
              }
              final index = 4 * (py * normal.$1.width + px);
              (materialSamples[material] ??= []).add([
                for (var c = 0; c < 3; c++) normal.$2.getUint8(index + c),
              ]);
            }
          }
          expect(counts['background'] ?? 0, 0);
          expect(cavitySamples, greaterThan(100));
          spans.add(maxRed - minRed);
        } finally {
          diagnostic.$1.dispose();
          normal.$1.dispose();
          shadowed.$1.dispose();
        }
      });
    }
    // Lighting of a curved inner wall must vary spatially without relying on
    // the fragment shadow, a progress-dependent fade or a screen-space patch.
    expect(
      spans.every((span) => span >= 6),
      isTrue,
      reason: 'Uniform cavity fill: $spans',
    );
    var sharedPoints = 0;
    for (final colors in materialSamples.values) {
      if (colors.length != 4) continue;
      sharedPoints++;
      for (var c = 0; c < 3; c++) {
        final channels = colors.map((color) => color[c]);
        expect(
          channels.reduce(math.max) - channels.reduce(math.min),
          lessThanOrEqualTo(2),
        );
      }
    }
    expect(sharedPoints, greaterThan(10));
  });

  testWidgets('Clip Chrome: conservation de la face a progression exacte', (
    tester,
  ) async {
    FragmentPaintDiagnostics? report;
    final recorder = ui.PictureRecorder();
    FragmentScene(
      progress: .5413907284768212,
      thickness: 2.5,
      motion: 1.5,
      guides: false,
      showEgg: true,
      shadow: false,
      identifySurfaces: true,
      onDiagnostics: (value) => report = value,
    ).paint(Canvas(recorder), const Size(390, 390 * 16 / 9));
    recorder.endRecording().dispose();
    final probe = report!.probe!;
    // Installed CanvasKit CkPathBuilder.combine calls fromSkPath(result,
    // path1.fillType), which resets Skia's result to the first operand's fill.
    // Emulate this backend contract without launching Chrome. Apply the same
    // production normalization after EACH of the three boolean operations.
    Path webCombine(PathOperation op, Path a, Path b) =>
        combineFragmentOcclusionPaths(
          op,
          a,
          b,
          combine: (operation, first, second) =>
              Path.combine(operation, first, second)..fillType = first.fillType,
        );
    final shell = Path.combine(
      PathOperation.difference,
      probe.egg,
      probe.aperture,
    );
    final webShell = webCombine(
      PathOperation.difference,
      probe.egg,
      probe.aperture,
    );
    final depths = probe.depthChanges();
    final behind = Path();
    for (var i = 0; i < probe.indices.length; i += 3) {
      final polygon = <Offset>[];
      for (var j = 0; j < 3; j++) {
        final a = probe.indices[i + j], b = probe.indices[i + (j + 1) % 3];
        if (depths[a] < 0) polygon.add(probe.positions[a]);
        if ((depths[a] < 0) != (depths[b] < 0)) {
          polygon.add(
            Offset.lerp(
              probe.positions[a],
              probe.positions[b],
              depths[a] / (depths[a] - depths[b]),
            )!,
          );
        }
      }
      if (polygon.length >= 3) behind.addPolygon(polygon, true);
    }
    final webClip = webCombine(
      PathOperation.difference,
      Path()..addRect(const Rect.fromLTRB(-1000, -1000, 1000, 1000)),
      webCombine(PathOperation.intersect, behind, webShell),
    );
    var extraShell = 0;
    var lost = 0;
    Offset? witness;
    var trulyOccluded = 0;
    var leakedOcclusion = 0;
    for (var y = -135.75; y < -15; y += .5) {
      for (var x = -19.75; x < 105; x += .5) {
        final p = Offset(x, y);
        if (probe.aperture.contains(p) && webShell.contains(p)) extraShell++;
        if (probe.aperture.contains(p) &&
            probe.outer.contains(p) &&
            !webClip.contains(p)) {
          lost++;
          witness ??= p;
        }
        if (probe.egg.contains(p) &&
            !probe.aperture.contains(p) &&
            behind.contains(p) &&
            probe.outer.contains(p)) {
          if (webClip.contains(p)) leakedOcclusion++;
          trulyOccluded++;
        }
      }
    }
    debugPrint(
      'WEB_CLIP nativeFill=${probe.visibility!.fillType} lost=$lost extraShell=$extraShell witness=$witness trueOcclusion=$trulyOccluded leaked=$leakedOcclusion',
    );
    // Replay the affected composition with CanvasKit's combine semantics.
    // The fixed shell mesh has no triangles in the aperture: use its geometric
    // domain here, not the broken Web boolean that is only used for clipping.
    await tester.runAsync(() async {
      final recording = ui.PictureRecorder();
      final canvas = Canvas(recording)..scale(2);
      canvas.drawColor(const Color(0xff606060), BlendMode.src);
      canvas.transform(probe.eggToCanvas.storage);
      canvas.drawPath(shell, Paint()..color = const Color(0xffffd700));
      canvas.drawPath(probe.opening, Paint()..color = const Color(0xff2850ff));
      canvas.save();
      canvas.clipPath(webClip);
      canvas.drawVertices(
        ui.Vertices(
          ui.VertexMode.triangles,
          probe.positions,
          textureCoordinates: probe.textureCoordinates,
          indices: probe.indices,
        ),
        BlendMode.srcOver,
        Paint()..color = const Color(0xff00dcdc),
      );
      canvas.restore();
      final picture = recording.endRecording();
      final image = await picture.toImage(780, (390 * 16 / 9 * 2).ceil());
      picture.dispose();
      try {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        // Fixed witness from the initial red run, not selected by the new clip.
        final center = probe.toCanvas(const Offset(51.75, -104.75));
        probe.visibility = webClip;
        final roi = probe.rasterReport(
          bytes,
          image.width,
          image.height,
          2,
          center,
        );
        debugPrint('WEB_ROI ${jsonEncode(roi)}');
        final point = roi['point'] as Map;
        expect(point['insideOuterTriangles'], isTrue);
        expect(point['behindFixedShell'], isFalse);
        expect(point['expectedOuterVisibility'], isTrue);
        expect(point['expectedSurface'], 'outer');
        expect(roi['backgroundWhereSurfaceExpected'], 0);
        expect(point['insideFragmentClip'], isTrue);
        expect(point['finalRenderedSurface'], 'outer');
        final trace = await probe.tracePixel(center, 2);
        debugPrint(
          'WEB_WITNESS ${jsonEncode(trace['primitiveCoverageAlpha'])}',
        );
        expect(
          (trace['primitiveCoverageAlpha'] as Map)['outerTrianglesAfterClip'],
          greaterThan(0),
        );
      } finally {
        image.dispose();
      }
    });
    expect(trulyOccluded, greaterThan(0));
    expect(leakedOcclusion, 0);
    expect(
      extraShell,
      0,
      reason: 'CanvasKit must not restore fixed shell inside its aperture',
    );
    expect(lost, 0);
  });

  testWidgets('Face entiere: seuil 49-50, rendu normal et diagnostic', (
    tester,
  ) async {
    // Select witnesses from the solo raster BEFORE consulting the egg clip.
    // Otherwise a faulty clip could exclude its own missing pixels from a test.
    var compared = 0;
    for (final (width, ratio) in [(390.0, 2.0), (317.25, 1.25)]) {
      final size = Size(width, width * 16 / 9);
      for (final t in [
        .49,
        .4949,
        .495,
        .4951,
        .499,
        .500,
        .501,
        .505,
        .5073,
        .51,
        .514,
        .5371,
        .5413907284768212,
        .552,
        .5699,
      ]) {
        await tester.runAsync(() async {
          Future<(ui.Image, ByteData, FragmentPaintDiagnostics)> render(
            bool egg,
            bool identify,
          ) async {
            FragmentPaintDiagnostics? report;
            final recorder = ui.PictureRecorder();
            FragmentScene(
              progress: t,
              thickness: 2.5,
              motion: 1.5,
              guides: false,
              showEgg: egg,
              shadow: false,
              identifySurfaces: identify,
              onDiagnostics: (value) => report = value,
            ).paint(Canvas(recorder)..scale(ratio), size);
            final picture = recorder.endRecording();
            final image = await picture.toImage(
              (size.width * ratio).ceil(),
              (size.height * ratio).ceil(),
            );
            picture.dispose();
            return (
              image,
              (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!,
              report!,
            );
          }

          final solo = await render(false, true);
          final egg = await render(true, true);
          final normalSolo = await render(false, false);
          final normalEgg = await render(true, false);
          try {
            final probe = solo.$3.probe!;
            final bounds = probe.outer.getBounds();
            var witnesses = 0;
            final violations = <String>[];
            // Compare all opaque face pixels inside the aperture, including
            // both sides of any putative diagonal. No depth/visibility filter.
            // A two-pixel margin excludes legitimate edge antialiasing.
            bool cyan(int x, int y) {
              if (x < 0 || y < 0 || x >= solo.$1.width || y >= solo.$1.height) {
                return false;
              }
              final i = 4 * (y * solo.$1.width + x);
              return solo.$2.getUint8(i) == 0 &&
                  solo.$2.getUint8(i + 1) == 220 &&
                  solo.$2.getUint8(i + 2) == 220;
            }

            final top = probe.toCanvas(bounds.topLeft);
            final bottom = probe.toCanvas(bounds.bottomRight);
            for (
              var y = (math.min(top.dy, bottom.dy) * ratio).floor() - 8;
              y <= (math.max(top.dy, bottom.dy) * ratio).ceil() + 8;
              y++
            ) {
              for (
                var x = (math.min(top.dx, bottom.dx) * ratio).floor() - 8;
                x <= (math.max(top.dx, bottom.dx) * ratio).ceil() + 8;
                x++
              ) {
                if (!cyan(x, y)) continue;
                var safe = true;
                for (final d in [
                  const Offset(-2, -2),
                  const Offset(2, -2),
                  const Offset(-2, 2),
                  const Offset(2, 2),
                  Offset.zero,
                ]) {
                  final local = Offset(
                    (x + .5 + d.dx) / ratio,
                    (y + .5 + d.dy) / ratio,
                  );
                  if (!cyan(x + d.dx.toInt(), y + d.dy.toInt()) ||
                      !probe.aperture.contains(probe.toEgg(local))) {
                    safe = false;
                    break;
                  }
                }
                if (!safe) continue;
                witnesses++;
                final i = 4 * (y * solo.$1.width + x);
                for (final (name, a, b) in [
                  ('diagnostic', solo.$2, egg.$2),
                  ('normal', normalSolo.$2, normalEgg.$2),
                ]) {
                  for (var channel = 0; channel < 4; channel++) {
                    if ((a.getUint8(i + channel) - b.getUint8(i + channel))
                            .abs() >
                        2) {
                      if (violations.length < 5) {
                        violations.add('$name: pixel ($x,$y), canal $channel');
                      }
                      break;
                    }
                  }
                }
              }
            }
            expect(witnesses, greaterThan(1000));
            expect(
              violations,
              isEmpty,
              reason: 'Face perdue a progress=$t, largeur=$width, DPR=$ratio',
            );
            expect(egg.$3.surfaces, normalEgg.$3.surfaces);
            expect(solo.$3.surfaces, normalSolo.$3.surfaces);
            compared += witnesses;
          } finally {
            for (final raster in [solo, egg, normalSolo, normalEgg]) {
              raster.$1.dispose();
            }
          }
        });
      }
    }
    debugPrint(
      'FACE_DIFFERENTIAL: $compared pixels, 30 poses/resolutions, '
      'normal + diagnostic',
    );
  });

  testWidgets(
    'Occlusion: showEgg differential et attribution des traits tardifs',
    (tester) async {
      const size = Size(390, 390 * 16 / 9), ratio = 2.0;
      final reports = <Map<String, Object>>[];
      var fixedShellViolationWitnesses = 0;
      for (final t in [
        .495,
        .500,
        .514,
        .524,
        .542,
        .5413907284768212,
        .552,
        .570,
        .583,
        .600,
        .620,
        .660,
        .720,
      ]) {
        await tester.runAsync(() async {
          Future<(ui.Image, ByteData, FragmentPaintDiagnostics)> render(
            bool egg,
          ) async {
            FragmentPaintDiagnostics? report;
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder)..scale(ratio);
            FragmentScene(
              progress: t,
              thickness: 2.5,
              motion: 1.5,
              guides: false,
              showEgg: egg,
              shadow: false,
              identifySurfaces: true,
              onDiagnostics: (v) => report = v,
            ).paint(canvas, size);
            final picture = recorder.endRecording();
            final image = await picture.toImage(
              (size.width * ratio).ceil(),
              (size.height * ratio).ceil(),
            );
            picture.dispose();
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            return (image, bytes, report!);
          }

          final solo = await render(false), egg = await render(true);
          final probe = egg.$3.probe!, alone = solo.$3.probe!;
          expect(probe.positions, alone.positions);
          expect(probe.indices, alone.indices);
          expect(probe.textureCoordinates, alone.textureCoordinates);
          expect(probe.depthChanges(), alone.depthChanges());
          expect(egg.$3.surfaces, solo.$3.surfaces);
          expect(probe.eggToCanvas.storage, alone.eggToCanvas.storage);
          expect(alone.visibility, isNull);
          expect(alone.overlays, isNotEmpty);
          expect(
            alone.overlays.every((stroke) => stroke.owner == 'fragmentOuter'),
            isTrue,
          );
          expect(probe.visibility, isNotNull);
          // This bend is a known material vertex on the fracture boundary.
          // It must follow that vertex, not its old screen position or a rigid
          // approximation that would ignore the retained mesh near attachments.
          final mobile = alone.overlays.singleWhere(
            (s) => s.primitive == 'mainCrack[3]',
          );
          final materialIndex = alone.textureCoordinates.indexWhere(
            (p) => (p - const Offset(72, -94)).distance < 1e-8,
          );
          expect(materialIndex, greaterThanOrEqualTo(0));
          final mobileStart = mobile.path
              .computeMetrics()
              .first
              .getTangentForOffset(0)!
              .position;
          expect(
            (mobileStart - alone.positions[materialIndex]).distance,
            lessThan(1e-4),
          );
          if (t >= .514) {
            expect(
              (mobileStart - const Offset(72, -94)).distance,
              greaterThan(.01),
            );
          }
          final withEggMobile = probe.overlays.singleWhere(
            (s) => s.primitive == mobile.primitive,
          );
          expect(withEggMobile.owner, 'fragmentOuter');
          expect(withEggMobile.path.getBounds(), mobile.path.getBounds());
          // Also cover a pinned vertex and the deforming neighborhood of a
          // retained attachment; a rigid-only transport cannot pass these.
          for (final fixture in [
            ('mainCrack[0]', const Offset(9, -108)),
            ('mainCrack[9]', const Offset(4, -60)),
          ]) {
            final stroke = alone.overlays.singleWhere(
              (s) => s.primitive == fixture.$1,
            );
            final index = alone.textureCoordinates.indexWhere(
              (p) => (p - fixture.$2).distance < 1e-8,
            );
            expect(index, greaterThanOrEqualTo(0));
            final start = stroke.path
                .computeMetrics()
                .first
                .getTangentForOffset(0)!
                .position;
            expect((start - alone.positions[index]).distance, lessThan(1e-4));
            if (fixture.$1 == 'mainCrack[0]' && t <= .600) {
              expect((start - fixture.$2).distance, lessThan(1e-4));
            }
          }
          // Replay ONLY the recorded late strokes over the intact solo image.
          // Matching changed pixels proves which primitive family introduced them.
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)
            ..drawImage(solo.$1, Offset.zero, Paint())
            ..scale(ratio)
            ..transform(probe.eggToCanvas.storage);
          for (final stroke in probe.overlays) {
            if (stroke.owner == 'fixedShell') stroke.replay(canvas);
          }
          final picture = recorder.endRecording();
          final replay = await picture.toImage(solo.$1.width, solo.$1.height);
          picture.dispose();
          try {
            final replayData = (await replay.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final bounds = MatrixUtils.transformRect(
              probe.eggToCanvas,
              probe.outer.getBounds(),
            );
            var front = 0, changed = 0, gray = 0, clipped = 0, unexplained = 0;
            final examples = <String, (int, Offset, Map<String, Object>)>{};
            for (
              var y = (bounds.top * ratio).floor();
              y < (bounds.bottom * ratio).ceil();
              y++
            ) {
              for (
                var x = (bounds.left * ratio).floor();
                x < (bounds.right * ratio).ceil();
                x++
              ) {
                final offset = 4 * (y * solo.$1.width + x);
                final soloRgb = [
                  for (var c = 0; c < 3; c++) solo.$2.getUint8(offset + c),
                ];
                final local = Offset((x + .5) / ratio, (y + .5) / ratio);
                final point = probe.at(probe.toEgg(local));
                if (point['insideFragmentClip'] == false) clipped++;
                if (point['expectedSurface'] != 'outer') continue;
                if (alone.at(alone.toEgg(local))['expectedSurface'] !=
                    'outer') {
                  continue;
                }
                final rgb = [
                  for (var c = 0; c < 3; c++) egg.$2.getUint8(offset + c),
                ];
                var difference = 0, replayDifference = 0;
                for (var c = 0; c < 3; c++) {
                  difference = math.max(
                    difference,
                    (rgb[c] - soloRgb[c]).abs(),
                  );
                  replayDifference = math.max(
                    replayDifference,
                    (rgb[c] - replayData.getUint8(offset + c)).abs(),
                  );
                }
                if (difference > 2) {
                  // Exclude pixel footprints straddling a real occlusion edge;
                  // this leaves only opaque portions genuinely in front.
                  final interior =
                      [
                        const Offset(-1, -1),
                        const Offset(1, -1),
                        const Offset(-1, 1),
                        const Offset(1, 1),
                      ].every(
                        (d) =>
                            probe.at(
                              probe.toEgg(local + d / ratio),
                            )['expectedSurface'] ==
                            'outer',
                      );
                  if (!interior) continue;
                }
                front++;
                expect(
                  point['clipDisagreesWithDepth'],
                  isFalse,
                  reason: 'p=$t $point',
                );
                if (FragmentSurfaceColors.classify(rgb) == 'background') gray++;
                if (difference <= 2) continue;
                changed++;
                if (replayDifference > 2) unexplained++;
                final key = point['insideAperture'] == true
                    ? 'insideAperture'
                    : 'overFixedShell';
                if (difference > (examples[key]?.$1 ?? 0)) {
                  examples[key] = (
                    difference,
                    local,
                    {
                      ...point,
                      'rgbSolo': soloRgb,
                      'rgbEgg': rgb,
                      'replayMaxChannelDifference': replayDifference,
                    },
                  );
                }
              }
            }
            final traced = <Map<String, Object>>[];
            for (final entry in examples.entries) {
              final (_, local, point) = entry.value;
              final trace = await probe.tracePixel(local, ratio);
              final coverage =
                  trace['primitiveCoverageAlpha'] as Map<String, int>;
              expect(coverage['fragmentDepthClip'], 255);
              expect(coverage['outerTrianglesBeforeClip'], 255);
              expect(coverage['outerTrianglesAfterClip'], 255);
              expect(trace['lateStrokeContributions'], isNotEmpty);
              final lastStroke = trace['lastLateStroke'] as String;
              if (entry.key == 'overFixedShell' &&
                  (point['interpolatedOuterDepths'] as List<double>).every(
                    (d) => d > 0,
                  ) &&
                  (lastStroke.startsWith('shellBranch[') ||
                      lastStroke.startsWith('microCrack[') ||
                      lastStroke.startsWith('attachmentScar['))) {
                fixedShellViolationWitnesses++;
              }
              traced.add({
                'region': entry.key,
                'canvasPoint': [local.dx, local.dy],
                ...point,
                ...trace,
              });
            }
            expect(front, greaterThan(100));
            expect(
              changed,
              0,
              reason:
                  'Fixed details overwrite opaque mobile material at $t: $traced',
            );
            if (t == .600) {
              const witness = Offset(224.75, 222.25);
              final offset =
                  4 *
                  ((witness.dy * ratio).floor() * egg.$1.width +
                      (witness.dx * ratio).floor());
              expect(
                probe.at(probe.toEgg(witness))['expectedSurface'],
                'outer',
              );
              expect(
                [for (var c = 0; c < 3; c++) egg.$2.getUint8(offset + c)],
                [0, 220, 220],
              );
              final trace = await probe.tracePixel(witness, ratio);
              expect(trace['lateStrokeContributions'], isEmpty);
              expect(
                probe.overlays
                    .singleWhere((s) => s.primitive == 'shellBranch[3]')
                    .clip
                    .contains(probe.toEgg(witness)),
                isFalse,
              );
            }
            if (t == .600 || t == .720) {
              // An uncovered fixed branch must remain visible, not be removed
              // globally to make the foreground differential pass.
              final branch = probe.overlays.singleWhere(
                (s) => s.primitive == 'shellBranch[2]',
              );
              final metric = branch.path.computeMetrics().first;
              final center =
                  probe.toCanvas(
                    metric.getTangentForOffset(metric.length * .85)!.position,
                  ) *
                  ratio;
              Offset? witness;
              var strongest = 0;
              for (var dy = -2; dy <= 2; dy++) {
                for (var dx = -2; dx <= 2; dx++) {
                  final x = center.dx.floor() + dx, y = center.dy.floor() + dy;
                  final local = Offset((x + .5) / ratio, (y + .5) / ratio);
                  if (probe.at(probe.toEgg(local))['expectedSurface'] !=
                      'shell') {
                    continue;
                  }
                  final red = egg.$2.getUint8(4 * (y * egg.$1.width + x));
                  if (255 - red > strongest) {
                    strongest = 255 - red;
                    witness = local;
                  }
                }
              }
              expect(strongest, greaterThan(30));
              expect(witness, isNotNull);
              final trace = await probe.tracePixel(witness!, ratio);
              expect(
                (trace['lateStrokeContributions'] as List).any(
                  (s) => (s as Map)['primitive'] == 'shellBranch[2]',
                ),
                isTrue,
              );
            }
            expect(
              gray,
              0,
              reason: 'Gray removes an opaque front fragment at $t',
            );
            expect(
              unexplained,
              0,
              reason: 'Unattributed occlusion/composition change at $t',
            );
            final row = <String, Object>{
              'progress': t,
              'frontPixels': front,
              // Main cracks on coincident material at rest are legitimate;
              // only the independent fixed-shell witnesses prove the defect.
              'lateStrokeChanges': changed,
              'grayOnFront': gray,
              'depthClippedPixels': clipped,
              'unexplainedPixels': unexplained,
              'examples': traced,
            };
            reports.add(row);
            debugPrint('OCCLUSION ${jsonEncode(row)}');
          } finally {
            solo.$1.dispose();
            egg.$1.dispose();
            replay.dispose();
          }
        });
      }
      expect(
        fixedShellViolationWitnesses,
        0,
        reason: 'Fixed-shell strokes must not cover the foreground fragment',
      );
      if (Platform.environment['ECLOSION_EXPORT_CAPTURES'] == '1') {
        await tester.runAsync(() async {
          final file = File('build/fragment_lab_diagnostics/occlusion.json');
          await file.parent.create(recursive: true);
          await file.writeAsString(
            const JsonEncoder.withIndent('  ').convert(reports),
          );
        });
      }
    },
  );
}
