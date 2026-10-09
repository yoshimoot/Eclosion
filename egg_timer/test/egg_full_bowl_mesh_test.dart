import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_full_bowl_mesh.dart';
import 'package:egg_timer/lab/egg_rear_bowl_boundary.dart';
import 'package:egg_timer/lab/egg_rear_bowl_mesh.dart';
import 'package:egg_timer/lab/egg_shell_front_assembly.dart';
import 'package:egg_timer/lab/egg_shell_fragment_mesh.dart';
import 'package:egg_timer/lab/egg_stationary_bowl_shell.dart';

void main() {
  final network = EggFractureNetwork.fixed();
  final plan = EggFragmentRegionPlan.fromNetwork(network);
  late EggStationaryBowlShell front;
  late EggRearBowlMesh rear;
  late EggFullBowlMesh combined;

  setUpAll(() {
    front = EggStationaryBowlShellBuilder.build(
      EggShellFrontAssemblyBuilder.build(plan),
    );
    rear = EggRearBowlMeshBuilder.build(
      EggRearBowlBoundaryBuilder.build(front),
    );
    combined = EggFullBowlMeshBuilder.build(front, rear);
  });

  String key(int a, int b) =>
      '${math.min(a, b)}:${math.max(a, b)}';

  test('V11.9: every exact lateral vertex is welded without moving it', () {
    final sides = {
      ...rear.boundary.rightFrontIndices,
      ...rear.boundary.leftFrontIndices,
    };
    expect(combined.sharedSideVertexCount, sides.length);
    expect(sides.length, front.openSilhouetteEdgeCount + 1);
    expect(combined.outer.length,
        front.exterior.length + rear.exterior.length - sides.length);
    expect(combined.inner.length, combined.outer.length);
    for (var i = 0; i < front.exterior.length; i++) {
      expect(identical(combined.outer[i], front.exterior[i]), isTrue);
      expect(identical(combined.inner[i], front.interior[i]), isTrue);
    }
  });

  test('V11.9: every material triangle edge is manifold and oriented', () {
    final count = <String, int>{};
    final orientation = <String, int>{};
    var faceCount = 0;
    for (final t in combined.allFaces) {
      faceCount++;
      for (final (int a, int b) in [
        (t.a, t.b), (t.b, t.c), (t.c, t.a),
      ]) {
        expect(a, isNot(b));
        expect(a, inInclusiveRange(0, combined.vertexCount - 1));
        expect(b, inInclusiveRange(0, combined.vertexCount - 1));
        final edge = key(a, b);
        count.update(edge, (value) => value + 1, ifAbsent: () => 1);
        orientation.update(
          edge, (value) => value + (a < b ? 1 : -1),
          ifAbsent: () => a < b ? 1 : -1,
        );
      }
    }
    expect(faceCount, combined.triangleCount);
    expect(count, isNotEmpty);
    expect(count.values.every((n) => n == 2), isTrue,
        reason: 'No open edges, overlapping faces or fake side walls');
    expect(orientation.values.every((n) => n == 0), isTrue,
        reason: 'Both adjacent triangles must oppose across every edge');
    expect(combined.vertexCount - count.length + faceCount, 2,
        reason: 'Closed single-shell surface has Euler characteristic 2');
  });

  test('V11.9: upper cuts alone have walls; no meridian wall exists', () {
    final expected = front.upperCutWalls.length +
        rear.rearCrownWalls.length;
    expect(combined.cutWalls.length, expected);
    expect(combined.cutWalls.length,
        (front.upperRim.length - 1 + rear.crownEdgeCount) * 2);
    expect(combined.outerFaces.length,
        front.outerFaces.length + rear.outerFaces.length);
    expect(combined.innerFaces.length,
        front.innerFaces.length + rear.innerFaces.length);
    expect(rear.crownEdgeCount, 192);
  });

  test('V11.9: all outer points retain the 2.5 inward thickness', () {
    for (var i = 0; i < combined.outer.length; i++) {
      final outer = combined.outer[i];
      final inner = combined.inner[i];
      expect((inner - outer).length, closeTo(2.5, 1e-7));
      final n = network.model.normalAt(outer);
      final inward = inner - outer;
      final dot = n.x * inward.x + n.y * inward.y + n.z * inward.z;
      expect(dot, closeTo(-2.5, 1e-7));
    }
  });

  test('V11.9: deterministic indices; rejects unrelated assembly', () {
    final again = EggFullBowlMeshBuilder.build(front, rear);
    expect(again.vertexCount, combined.vertexCount);
    expect(again.triangleCount, combined.triangleCount);
    expect(
      again.cutWalls.map((t) => (t.a, t.b, t.c)).toList(),
      combined.cutWalls.map((t) => (t.a, t.b, t.c)).toList(),
    );
    final differentFront = EggStationaryBowlShellBuilder.build(
      EggShellFrontAssemblyBuilder.build(plan),
    );
    expect(
      () => EggFullBowlMeshBuilder.build(differentFront, rear),
      throwsStateError,
    );
  });
}
