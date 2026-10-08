import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_shell_fragment_mesh.dart';

void main() {
  final network = EggFractureNetwork.fixed();
  final plan = EggFragmentRegionPlan.fromNetwork(network);

  test('V11.2: outer, inner and thickness rim exist for both candidates', () {
    final meshes = EggShellPanelMeshBuilder.build(plan);
    expect(meshes.map((e) => e.regionId), ['left', 'right']);
    for (final mesh in meshes) {
      expect(mesh.thickness, 2.5);
      expect(mesh.outer, isNotEmpty);
      expect(mesh.outer.length, mesh.inner.length);
      expect(mesh.outerTriangles, isNotEmpty);
      expect(mesh.innerTriangles.length, mesh.outerTriangles.length);
      expect(mesh.sideTriangles.length, mesh.rim.length * 2);
    }
  });

  test('V11.2: all edge incidences are manifold and volume is closed', () {
    for (final mesh in EggShellPanelMeshBuilder.build(plan)) {
      final incidence = <String, int>{};
      void add(EggShellTriangle t) {
        for (final pair in <(int, int)>[
          (t.a, t.b), (t.b, t.c), (t.c, t.a),
        ]) {
          final a = math.min(pair.$1, pair.$2);
          final b = math.max(pair.$1, pair.$2);
          expect(a, isNot(b));
          final key = '$a:$b';
          incidence[key] = (incidence[key] ?? 0) + 1;
        }
      }
      for (final t in mesh.outerTriangles) { add(t); }
      for (final t in mesh.innerTriangles) { add(t); }
      for (final t in mesh.sideTriangles) { add(t); }
      expect(incidence.values.every((count) => count == 2), isTrue);
      expect(mesh.vertexCount - incidence.length +
          mesh.triangleCount, 2);
    }
  });

  test('V11.2: true surface projection and 2.5 inward thickness', () {
    for (final mesh in EggShellPanelMeshBuilder.build(plan)) {
      for (var i = 0; i < mesh.outer.length; i++) {
        final outer = mesh.outer[i], inner = mesh.inner[i];
        final surface = network.model.surfaceAt(outer.x, outer.y);
        expect(outer.x, closeTo(surface.x, 1e-7));
        expect(outer.y, closeTo(surface.y, 1e-7));
        expect(outer.z, closeTo(surface.z, 1e-6));
        expect((inner - outer).length, closeTo(2.5, 1e-7));
      }
      for (final tri in mesh.outerTriangles) {
        final a = mesh.outer[tri.a], b = mesh.outer[tri.b];
        final c = mesh.outer[tri.c];
        final area2 = (b.x - a.x) * (c.y - a.y) -
            (b.y - a.y) * (c.x - a.x);
        expect(area2, greaterThan(0));
      }
    }
  });

  test('V11.2: original crack sample objects are preserved on the rim', () {
    final meshes = EggShellPanelMeshBuilder.build(plan);
    for (var i = 0; i < meshes.length; i++) {
      final original = plan.regions[i].sampledPerimeter(network);
      for (final sample in original.take(original.length - 1)) {
        expect(
          meshes[i].outer.any((point) => identical(point, sample)),
          isTrue,
        );
      }
    }
  });

  test('V11.2: deterministic geometry and validation of inputs', () {
    final a = EggShellPanelMeshBuilder.build(plan);
    final b = EggShellPanelMeshBuilder.build(plan);
    for (var i = 0; i < a.length; i++) {
      expect(a[i].outer.length, b[i].outer.length);
      expect(a[i].rim, b[i].rim);
      expect(
        a[i].outerTriangles.map((t) => (t.a, t.b, t.c)).toList(),
        b[i].outerTriangles.map((t) => (t.a, t.b, t.c)).toList(),
      );
    }
    expect(() => EggShellPanelMeshBuilder.build(
      plan, thickness: 0,
    ), throwsArgumentError);
    expect(() => EggShellPanelMeshBuilder.build(
      plan, maxEdgeXY: double.nan,
    ), throwsArgumentError);
  });
}
