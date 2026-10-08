import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_shell_fragment_mesh.dart';
import 'package:egg_timer/lab/egg_shell_model.dart';
import 'package:egg_timer/lab/egg_stationary_bowl_boundary.dart';
import 'package:egg_timer/lab/egg_stationary_bowl_mesh.dart';

void main() {
  final network = EggFractureNetwork.fixed();
  final regions = EggFragmentRegionPlan.fromNetwork(network);
  final boundary = EggStationaryBowlBoundary.fromRegions(regions);

  test('V11.4: original cut samples remain in the triangulated bowl', () {
    final patch = EggStationaryBowlMeshBuilder.build(boundary).surface;
    final original = boundary.sampledFrontPerimeter();
    expect(patch.triangles, isNotEmpty);
    expect(patch.vertices.length, greaterThan(200));
    // The lateral silhouette is sampled anew for each call, so object
    // identity is not meaningful there. Check the real 3D coordinates.
    for (final p in original.take(original.length - 1)) {
      expect(patch.vertices.any((v) =>
          (v.x - p.x).abs() < 1e-7 &&
          (v.y - p.y).abs() < 1e-7 &&
          (v.z - p.z).abs() < 1e-7), isTrue);
    }
    // The original, stored material crack samples themselves still
    // reach the mesh unchanged, not redrawn from approximate geometry.
    final originalCrack = boundary.cutEdges.first.samples(network);
    for (final p in originalCrack.skip(1)) {
      expect(patch.vertices.any((v) => identical(v, p)), isTrue);
    }
    for (final p in patch.vertices) {
      final onShell = network.model.surfaceAt(p.x, p.y);
      expect(p.x, closeTo(onShell.x, 1e-7));
      expect(p.y, closeTo(onShell.y, 1e-7));
      expect(p.z, closeTo(onShell.z, 1e-6));
    }
  });

  test('V11.4: positive triangles exactly cover the new bowl polygon', () {
    final patch = EggStationaryBowlMeshBuilder.build(boundary).surface;
    var trianglesArea = 0.0;
    for (final t in patch.triangles) {
      final a = patch.vertices[t.a], b = patch.vertices[t.b];
      final c = patch.vertices[t.c];
      final double area2 = (b.x - a.x) * (c.y - a.y) -
          (b.y - a.y) * (c.x - a.x);
      expect(area2, greaterThan(1e-8));
      trianglesArea += area2 / 2;
    }
    // Refinement places new points back onto the curved shell, which can
    // move the projected silhouette slightly versus its initial chords.
    // The EXACT area invariant therefore uses the actual refined rim.
    var refinedDoubleArea = 0.0;
    for (var i = 0; i < patch.rim.length; i++) {
      final a = patch.vertices[patch.rim[i]];
      final b = patch.vertices[
        patch.rim[(i + 1) % patch.rim.length]
      ];
      refinedDoubleArea += a.x * b.y - b.x * a.y;
    }
    expect(trianglesArea, closeTo(refinedDoubleArea.abs() / 2, 1e-4));

    final original = boundary.sampledFrontPerimeter();
    var originalDoubleArea = 0.0;
    for (var i = 0; i < original.length - 1; i++) {
      originalDoubleArea += original[i].x * original[i + 1].y -
          original[i + 1].x * original[i].y;
    }
    final originalArea = originalDoubleArea.abs() / 2;
    expect((trianglesArea - originalArea).abs(),
        lessThan(originalArea * 5e-6),
        reason: 'Curved boundary refinement must not appreciably drift');
  });

  test('V11.4: exactly one manifold disk boundary remains', () {
    final patch = EggStationaryBowlMeshBuilder.build(boundary).surface;
    String key(int a, int b) =>
        '${math.min(a, b)}:${math.max(a, b)}';
    final counts = <String, int>{};
    for (final t in patch.triangles) {
      for (final (a, b) in <(int, int)>[
        (t.a, t.b), (t.b, t.c), (t.c, t.a),
      ]) {
        counts.update(key(a, b), (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final rimEdges = <String>{
      for (var i = 0; i < patch.rim.length; i++)
        key(patch.rim[i], patch.rim[(i + 1) % patch.rim.length]),
    };
    expect(counts.entries.where((e) => e.value == 1)
        .map((e) => e.key).toSet(), rimEdges);
    expect(counts.values.every((count) => count == 1 || count == 2),
        isTrue);
    expect(patch.vertices.length - counts.length +
        patch.triangles.length, 1);
  });

  test('V11.4: bowl and panels agree on every original cut coordinate', () {
    final patch = EggStationaryBowlMeshBuilder.build(boundary).surface;
    final panels = EggShellPanelMeshBuilder.build(regions);
    final samples = [
      for (final step in boundary.cutEdges)
        ...step.samples(network),
    ];
    bool identicalPosition(EggShellPoint3 a, EggShellPoint3 b) =>
        (a.x - b.x).abs() <= 1e-7 &&
        (a.y - b.y).abs() <= 1e-7 &&
        (a.z - b.z).abs() <= 1e-7;
    for (final sample in samples) {
      expect(patch.vertices.any((p) => identicalPosition(p, sample)),
          isTrue);
      expect(panels.any((mesh) => mesh.outer.any(
        (p) => identicalPosition(p, sample),
      )), isTrue);
    }
    expect(boundary.cutEdges.length, 15);
  });

  test('V11.4: deterministic and no change to F1 or parameters', () {
    final a = EggStationaryBowlMeshBuilder.build(
      boundary, sideSegments: 24,
    ).surface;
    final b = EggStationaryBowlMeshBuilder.build(
      boundary, sideSegments: 24,
    ).surface;
    expect(a.vertices.length, b.vertices.length);
    expect(a.rim, b.rim);
    final normalSampling = EggStationaryBowlMeshBuilder.build(
      boundary, sideSegments: 64,
    ).surface;
    expect(a.vertices.length, normalSampling.vertices.length,
        reason: 'Coarse requests must receive curvature-safe sampling');
    final minimalSampling = EggStationaryBowlMeshBuilder.build(
      boundary, sideSegments: 2,
    ).surface;
    expect(minimalSampling.triangles.length, a.triangles.length);
    expect(a.triangles.map((t) => (t.a, t.b, t.c)).toList(),
        b.triangles.map((t) => (t.a, t.b, t.c)).toList());
    expect(boundary.remainingCrownEdges.map((s) => s.edgeId),
        [6, 16, 17]);
    expect(network.edges.length, 52);
    expect(network.nodes.length, 50);
    expect(
      () => EggStationaryBowlMeshBuilder.build(
        boundary, sideSegments: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => EggStationaryBowlMeshBuilder.build(
        boundary, maxEdgeXY: -1,
      ),
      throwsArgumentError,
    );
  });
}
