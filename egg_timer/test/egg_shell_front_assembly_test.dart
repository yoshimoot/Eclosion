import 'package:flutter_test/flutter_test.dart';
import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_shell_front_assembly.dart';
import 'package:egg_timer/lab/egg_shell_fragment_mesh.dart';

void main() {
  final network = EggFractureNetwork.fixed();
  final regions = EggFragmentRegionPlan.fromNetwork(network);

  int passes(int refined, int original) {
    expect(refined % original, 0);
    var multiplier = refined ~/ original;
    var level = 0;
    while (multiplier > 1 && multiplier.isEven) {
      multiplier ~/= 2;
      level++;
    }
    expect(multiplier, 1);
    return level;
  }

  test('V11.5: all three surfaces use one boundary subdivision count', () {
    final a = EggShellFrontAssemblyBuilder.build(regions);
    expect(a.panels.length, 2);
    expect(a.refinementPasses, inInclusiveRange(0, 5));
    for (var i = 0; i < 2; i++) {
      final original =
          regions.regions[i].sampledPerimeter(network).length - 1;
      expect(passes(a.panels[i].rim.length, original), a.refinementPasses);
      expect(a.panels[i].thickness, 2.5);
      expect(a.panels[i].sideTriangles.length, a.panels[i].rim.length * 2);
    }
    final originalBowl =
        a.bowl.boundary.sampledFrontPerimeter().length - 1;
    expect(passes(a.bowl.surface.rim.length, originalBowl),
        a.refinementPasses);
  });

  test('V11.5: all 15 bowl cuts and 3 central edges are verified', () {
    final a = EggShellFrontAssemblyBuilder.build(regions);
    expect(a.bowl.boundary.cutEdges.length, 15);
    expect(regions.regions[0].sharedEdgeIds(regions.regions[1]).toSet(),
        {28, 29, 30});
    final material = {
      for (final r in regions.regions)
        for (final s in r.boundary)
          if (network.edges[s.edgeId].kind != EggCrackKind.crown)
            s.edgeId,
    };
    expect(material.length, 18);
    expect(a.panels[0].outer, isNotEmpty);
    expect(a.bowl.surface.triangles, isNotEmpty);
  });

  test('V11.5: deterministic for coarse valid silhouette settings', () {
    final a = EggShellFrontAssemblyBuilder.build(
      regions, sideSegments: 2,
    );
    final b = EggShellFrontAssemblyBuilder.build(
      regions, sideSegments: 24,
    );
    expect(a.refinementPasses, b.refinementPasses);
    for (var i = 0; i < 2; i++) {
      expect(a.panels[i].rim.length, b.panels[i].rim.length);
    }
    expect(a.bowl.surface.rim.length, b.bowl.surface.rim.length);
  });

  test('V11.5: invalid parameters are rejected', () {
    expect(
      () => EggShellPanelMeshBuilder.build(
        regions, refinementPasses: -1,
      ), throwsArgumentError,
    );
    expect(
      () => EggShellFrontAssemblyBuilder.build(
        regions, thickness: 0,
      ), throwsArgumentError,
    );
    expect(
      () => EggShellFrontAssemblyBuilder.build(
        regions, maxEdgeXY: double.nan,
      ), throwsArgumentError,
    );
  });
}
