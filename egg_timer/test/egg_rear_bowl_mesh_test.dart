import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_rear_bowl_boundary.dart';
import 'package:egg_timer/lab/egg_rear_bowl_mesh.dart';
import 'package:egg_timer/lab/egg_shell_front_assembly.dart';
import 'package:egg_timer/lab/egg_shell_fragment_mesh.dart';
import 'package:egg_timer/lab/egg_shell_model.dart';
import 'package:egg_timer/lab/egg_stationary_bowl_shell.dart';

void main() {
  final network = EggFractureNetwork.fixed();
  final regions = EggFragmentRegionPlan.fromNetwork(network);
  late EggStationaryBowlShell front;
  late EggRearBowlBoundary boundary;
  late EggRearBowlMesh mesh;

  setUpAll(() {
    front = EggStationaryBowlShellBuilder.build(
      EggShellFrontAssemblyBuilder.build(regions),
    );
    boundary = EggRearBowlBoundaryBuilder.build(front);
    mesh = EggRearBowlMeshBuilder.build(boundary);
  });

  String edgeKey(int a, int b) =>
      '${math.min(a, b)}:${math.max(a, b)}';

  test('V11.8: exact rear boundary and no seam midpoint insertion', () {
    final original = boundary.closedPerimeter;
    expect(mesh.perimeterLength, original.length - 1);
    expect(mesh.crownEdgeCount, 12 * 16);
    for (var i = 0; i < mesh.perimeterLength; i++) {
      expect(identical(mesh.exterior[i], original[i]), isTrue);
    }
    for (final right in boundary.rightSide) {
      expect(mesh.exterior.any((p) => identical(p, right)), isTrue);
    }
    for (final left in boundary.leftSide) {
      expect(mesh.exterior.any((p) => identical(p, left)), isTrue);
    }
    expect(mesh.sideSeamEdgeCount, front.openSilhouetteEdgeCount);
  });

  test('V11.8: rear outer/inner vertices lie on same curved egg', () {
    expect(mesh.thickness, 2.5);
    expect(mesh.interior.length, mesh.exterior.length);
    expect(mesh.outerFaces.length, mesh.innerFaces.length);
    expect(mesh.vertexCount, mesh.exterior.length * 2);
    for (var i = 0; i < mesh.exterior.length; i++) {
      final p = mesh.exterior[i];
      final r = network.model.radiusAt(p.y);
      final z = network.model.depthRadiusAt(p.y);
      if (r > 1e-7) {
        final ellipse = p.x * p.x / (r * r) + p.z * p.z / (z * z);
        expect(ellipse, closeTo(1, 1e-6));
      }
      final offset = mesh.interior[i] - p;
      expect(offset.length, closeTo(2.5, 1e-7));
      final n = network.model.normalAt(p);
      final dot = n.x * offset.x + n.y * offset.y + n.z * offset.z;
      expect(dot, closeTo(-2.5, 1e-7));
    }
  });

  test('V11.8: outer and inner patch remain disks with one crown wall', () {
    final edges = <String, int>{};
    void add(EggShellTriangle t) {
      for (final (a, b) in <(int, int)>[
        (t.a, t.b), (t.b, t.c), (t.c, t.a),
      ]) {
        expect(a, isNot(b));
        edges.update(edgeKey(a, b), (n) => n + 1, ifAbsent: () => 1);
      }
    }
    for (final t in mesh.outerFaces) { add(t); }
    for (final t in mesh.innerFaces) { add(t); }
    for (final t in mesh.rearCrownWalls) { add(t); }
    expect(edges.values.every((n) => n == 1 || n == 2), isTrue);

    final offset = mesh.exterior.length;
    final expectedOpen = <String>{};
    for (var i = mesh.crownEdgeCount; i < mesh.perimeterLength; i++) {
      final next = (i + 1) % mesh.perimeterLength;
      expectedOpen.add(edgeKey(i, next));
      expectedOpen.add(edgeKey(i + offset, next + offset));
    }
    // Crown cut-wall endpoints remain exposed until they meet the front
    // cut walls at node 18 and node 6.
    expectedOpen.add(edgeKey(0, offset));
    expectedOpen.add(edgeKey(mesh.crownEdgeCount,
        mesh.crownEdgeCount + offset));
    final actualOpen = edges.entries.where((e) => e.value == 1)
        .map((e) => e.key).toSet();
    expect(actualOpen, expectedOpen);
    expect(mesh.rearCrownWalls.length, mesh.crownEdgeCount * 2);
  });

  test('V11.8: no unexpected folds of rear outer triangles', () {
    final p = mesh.exterior;
    for (final triangle in mesh.outerFaces) {
      final a = p[triangle.a], b = p[triangle.b], c = p[triangle.c];
      final ab = b - a, ac = c - a;
      final normal = EggShellPoint3(
        ab.y * ac.z - ab.z * ac.y,
        ab.z * ac.x - ab.x * ac.z,
        ab.x * ac.y - ab.y * ac.x,
      );
      expect(normal.length, greaterThan(1e-8));
      final reference = network.model.normalAt(
        EggShellPoint3(
          (a.x + b.x + c.x) / 3,
          (a.y + b.y + c.y) / 3,
          (a.z + b.z + c.z) / 3,
        ),
      );
      final dot = normal.x * reference.x +
          normal.y * reference.y + normal.z * reference.z;
      expect(dot, greaterThan(0),
          reason: 'Curved rear triangles must face outward');
    }
  });

  test('V11.8: deterministic rear mesh and parameter validation', () {
    final again = EggRearBowlMeshBuilder.build(boundary);
    expect(mesh.exterior.length, again.exterior.length);
    expect(mesh.outerFaces.length, again.outerFaces.length);
    for (var i = 0; i < mesh.exterior.length; i++) {
      expect(mesh.exterior[i].x, closeTo(again.exterior[i].x, 1e-9));
      expect(mesh.exterior[i].y, closeTo(again.exterior[i].y, 1e-9));
      expect(mesh.exterior[i].z, closeTo(again.exterior[i].z, 1e-9));
    }
    expect(
      () => EggRearBowlMeshBuilder.build(boundary, interiorBands: 0),
      throwsArgumentError,
    );
    expect(
      () => EggRearBowlMeshBuilder.build(boundary, thickness: 3),
      throwsStateError,
    );
    expect(
      () => EggRearBowlMeshBuilder.build(boundary,
          centerY: double.nan),
      throwsArgumentError,
    );
  });
}
