import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_shell_front_assembly.dart';
import 'package:egg_timer/lab/egg_shell_fragment_mesh.dart';
import 'package:egg_timer/lab/egg_stationary_bowl_shell.dart';

void main() {
  final network = EggFractureNetwork.fixed();
  final regions = EggFragmentRegionPlan.fromNetwork(network);
  late EggShellFrontAssembly assembly;
  late EggStationaryBowlShell shell;

  setUpAll(() {
    assembly = EggShellFrontAssemblyBuilder.build(regions);
    shell = EggStationaryBowlShellBuilder.build(assembly);
  });

  test('V11.6: same outer patch plus a curved inward 2.5-thick face', () {
    final outer = shell.exterior;
    expect(identical(outer, assembly.bowl.surface.vertices), isTrue);
    expect(shell.thickness, 2.5);
    expect(shell.interior.length, outer.length);
    expect(shell.vertexCount, outer.length * 2);
    expect(shell.innerFaces.length, shell.outerFaces.length);

    for (var i = 0; i < outer.length; i++) {
      final displacement = shell.interior[i] - outer[i];
      expect(displacement.length, closeTo(2.5, 1e-7));
      final n = network.model.normalAt(outer[i]);
      final dot = displacement.x * n.x +
          displacement.y * n.y + displacement.z * n.z;
      expect(dot, closeTo(-2.5, 1e-7));
    }
    for (var i = 0; i < shell.outerFaces.length; i++) {
      final outerFace = shell.outerFaces[i];
      final innerFace = shell.innerFaces[i];
      final shift = outer.length;
      expect(innerFace.a, outerFace.a + shift);
      expect(innerFace.b, outerFace.c + shift);
      expect(innerFace.c, outerFace.b + shift);
    }
  });

  test('V11.6: cut-wall count follows F1 and all shared fissure samples', () {
    final top = <Object>[];
    for (final segment in assembly.bowl.boundary.frontUpperBoundary) {
      final samples = segment.samples(network);
      top.addAll(top.isEmpty ? samples : samples.skip(1));
    }
    final expectedUpperVertices = (top.length - 1) *
        (1 << assembly.refinementPasses) + 1;
    expect(assembly.bowl.boundary.cutEdges.length, 15);
    expect(assembly.bowl.boundary.frontUpperBoundary.length, 18);
    expect(shell.upperRim.length, expectedUpperVertices);
    expect(shell.upperCutWalls.length, (shell.upperRim.length - 1) * 2);
    expect(shell.openSilhouetteEdgeCount, greaterThan(0));
    expect(shell.upperRim.toSet().length, shell.upperRim.length);
    expect(shell.upperRim.every(assembly.bowl.surface.rim.contains), isTrue);
  });

  test('V11.6: interior and cut walls share manifold edges only', () {
    final counts = <String, int>{};
    String edgeKey(int a, int b) =>
        '${math.min(a, b)}:${math.max(a, b)}';
    void accumulate(EggShellTriangle t) {
      for (final (a, b) in <(int, int)>[
        (t.a, t.b), (t.b, t.c), (t.c, t.a),
      ]) {
        expect(a, isNot(b));
        counts.update(edgeKey(a, b), (old) => old + 1, ifAbsent: () => 1);
      }
    }

    for (final tri in shell.outerFaces) {
      accumulate(tri);
    }
    for (final tri in shell.innerFaces) {
      accumulate(tri);
    }
    for (final tri in shell.upperCutWalls) {
      accumulate(tri);
    }
    expect(counts.values.every((n) => n == 1 || n == 2), isTrue,
        reason: 'No non-manifold edges, duplicate walls, or missing rim joins');

    // There are two open silhouette arcs, one on each shell surface.
    // Since the upper cut has a finite thickness, the left and right
    // endpoints ALSO expose one short outer-to-inner edge each until
    // the front and rear halves are physically connected.
    final upperMaterialEdges = <String>{
      for (var i = 0; i + 1 < shell.upperRim.length; i++)
        edgeKey(shell.upperRim[i], shell.upperRim[i + 1]),
    };
    final rim = assembly.bowl.surface.rim;
    final offset = shell.exterior.length;
    final expectedOpenEdges = <String>{};
    for (var i = 0; i < rim.length; i++) {
      final a = rim[i];
      final b = rim[(i + 1) % rim.length];
      if (upperMaterialEdges.contains(edgeKey(a, b))) continue;
      expectedOpenEdges.add(edgeKey(a, b));
      expectedOpenEdges.add(edgeKey(a + offset, b + offset));
    }
    final leftTip = shell.upperRim.first;
    final rightTip = shell.upperRim.last;
    expectedOpenEdges.add(edgeKey(leftTip, leftTip + offset));
    expectedOpenEdges.add(edgeKey(rightTip, rightTip + offset));

    final actualOpenEdges = counts.entries
        .where((e) => e.value == 1)
        .map((e) => e.key)
        .toSet();
    expect(actualOpenEdges, expectedOpenEdges,
        reason: 'Only both silhouette arcs and their two vertical '
            'end contacts may remain open');
    expect(actualOpenEdges.length,
        shell.openSilhouetteEdgeCount * 2 + 2,
        reason: 'Each of the two upper-rim endpoints has one exposed '
            'thickness edge until the rear shell is assembled');
  });

  test('V11.6: cut walls have exactly the same outer and inner rim', () {
    final offset = shell.exterior.length;
    final expectedRim = shell.upperRim.toSet();
    final cutVertices = <int>{};
    for (final tri in shell.upperCutWalls) {
      for (final vertex in [tri.a, tri.b, tri.c]) {
        cutVertices.add(vertex >= offset ? vertex - offset : vertex);
        expect(vertex, inInclusiveRange(0, shell.vertexCount - 1));
      }
    }
    expect(cutVertices, expectedRim);

    for (final index in shell.upperRim) {
      final outer = shell.exterior[index];
      final inner = shell.interior[index];
      final inward = network.model.inset(outer, shell.thickness);
      expect(inner.x, closeTo(inward.x, 1e-9));
      expect(inner.y, closeTo(inward.y, 1e-9));
      expect(inner.z, closeTo(inward.z, 1e-9));
    }
  });

  test('V11.6: deterministic with coarse requests and invalid thickness', () {
    final coarse = EggShellFrontAssemblyBuilder.build(
      regions, sideSegments: 2,
    );
    final other = EggStationaryBowlShellBuilder.build(coarse);
    expect(other.upperRim.length, shell.upperRim.length);
    expect(other.upperCutWalls.length, shell.upperCutWalls.length);
    expect(
      other.upperRim.map((i) => (
        other.exterior[i].x, other.exterior[i].y, other.exterior[i].z,
      )).toList(),
      shell.upperRim.map((i) => (
        shell.exterior[i].x, shell.exterior[i].y, shell.exterior[i].z,
      )).toList(),
    );
    expect(
      () => EggStationaryBowlShellBuilder.build(assembly, thickness: 0),
      throwsArgumentError,
    );
    expect(
      () => EggStationaryBowlShellBuilder.build(
        assembly, thickness: double.nan,
      ),
      throwsArgumentError,
    );
    expect(
      () => EggStationaryBowlShellBuilder.build(assembly, thickness: 3),
      throwsStateError,
      reason: 'The bol and its fragments must use identical thickness',
    );
  });
}
