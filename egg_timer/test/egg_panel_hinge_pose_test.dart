import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_panel_hinge_pose.dart';
import 'package:egg_timer/lab/egg_shell_front_assembly.dart';
import 'package:egg_timer/lab/egg_shell_fragment_mesh.dart';
import 'package:egg_timer/lab/egg_shell_model.dart';

void main() {
  final network = EggFractureNetwork.fixed();
  final plan = EggFragmentRegionPlan.fromNetwork(network);
  late List<EggShellPanelMesh> panels;

  setUpAll(() {
    panels = EggShellFrontAssemblyBuilder.build(plan).panels;
  });

  EggPanelHingePose hinge(int i, double angle) =>
      EggPanelHingePose.fromGraph(
        panel: panels[i],
        region: plan.regions[i],
        neighbor: plan.regions[1 - i],
        network: network,
        openingDegrees: angle,
      );

  double dot(EggShellPoint3 a, EggShellPoint3 b) =>
      a.x * b.x + a.y * b.y + a.z * b.z;

  test('V11.12: hinges follow lower bowl connections, not side cracks', () {
    for (var i = 0; i < 2; i++) {
      final pose = hinge(i, 30);
      final region = plan.regions[i];
      expect(network.edges[pose.edgeId].kind, EggCrackKind.connection);
      expect(region.boundary.any((s) => s.edgeId == pose.edgeId), isTrue);
      expect(region.sharedEdgeIds(plan.regions[1 - i])
          .contains(pose.edgeId), isFalse);
      expect(network.edges[pose.edgeId].samples
          .any((p) => identical(p, pose.anchorA)), isTrue);
      expect(network.edges[pose.edgeId].samples
          .any((p) => identical(p, pose.anchorB)), isTrue);
      expect(panels[i].outer.any((p) => identical(p, pose.anchorA)), isTrue);
      expect(panels[i].outer.any((p) => identical(p, pose.anchorB)), isTrue);
      expect(pose.axis.length, closeTo(1, 1e-10));
      final candidates = <EggCrackEdge>[
        for (final step in region.boundary)
          if (network.edges[step.edgeId].kind ==
                  EggCrackKind.connection &&
              !region.sharedEdgeIds(plan.regions[1 - i])
                  .contains(step.edgeId))
            network.edges[step.edgeId],
      ];
      expect(candidates, isNotEmpty);
      double verticalRatio(EggCrackEdge edge) {
        final a = edge.samples.first, b = edge.samples.last;
        return (b.y - a.y).abs() /
            math.sqrt(math.pow(b.x - a.x, 2) +
                math.pow(b.y - a.y, 2));
      }
      final best = candidates.map(verticalRatio).reduce(math.min);
      expect(verticalRatio(network.edges[pose.edgeId]),
          closeTo(best, 1e-12));
    }
  });

  test('V11.11: both hinge endpoints stay fixed throughout the pivot', () {
    for (var i = 0; i < 2; i++) {
      for (final angle in <double>[0, 15, 30, 55]) {
        final pose = hinge(i, angle);
        final a = pose.transform(pose.anchorA);
        final b = pose.transform(pose.anchorB);
        expect((a - pose.anchorA).length, lessThan(1e-8));
        expect((b - pose.anchorB).length, lessThan(1e-8));
      }
    }
  });

  test('V11.11: rigid shell retains edge distances and 2.5 thickness', () {
    for (var i = 0; i < 2; i++) {
      final p = panels[i];
      final pose = hinge(i, 37);
      final outside = pose.transformAll(p.outer);
      final inside = pose.transformAll(p.inner);
      final stride = math.max(1, outside.length ~/ 17);
      for (var j = 0; j < outside.length; j += stride) {
        expect((outside[j] - inside[j]).length,
            closeTo(p.thickness, 1e-8));
        final k = (j + stride) % outside.length;
        expect((outside[j] - outside[k]).length,
            closeTo((p.outer[j] - p.outer[k]).length, 1e-8));
        final originalNormal = network.model.normalAt(p.outer[j]);
        expect(pose.rotateNormal(originalNormal).length,
            closeTo(1, 1e-9));
      }
      expect(p.outerTriangles, isNotEmpty);
      expect(p.sideTriangles.length, p.rim.length * 2);
    }
  });

  test('V11.12: lower-lip rotation opens outwards without translation', () {
    for (var i = 0; i < 2; i++) {
      final pose = hinge(i, 30);
      final probe = panels[i].outer[pose.probeIndex];
      final normal = network.model.normalAt(probe);
      expect(dot(pose.transform(probe) - probe, normal),
          greaterThan(0));
      final resting = hinge(i, 0);
      for (var k = 0; k < panels[i].outer.length; k += 47) {
        expect((resting.transform(panels[i].outer[k]) -
            panels[i].outer[k]).length, lessThan(1e-8));
      }
    }
  });

  test('V11.11: invalid inputs and mismatched ownership are rejected', () {
    expect(() => hinge(0, double.nan), throwsArgumentError);
    expect(() => hinge(0, -1), throwsArgumentError);
    expect(() => hinge(0, 70), throwsArgumentError);
    expect(
      () => EggPanelHingePose.fromGraph(
        panel: panels[0],
        region: plan.regions[1],
        neighbor: plan.regions[0],
        network: network,
        openingDegrees: 20,
      ), throwsArgumentError,
    );
  });
}
