import 'package:flutter_test/flutter_test.dart';

import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_full_bowl_mesh.dart';
import 'package:egg_timer/lab/egg_panel_hinge_pose.dart';
import 'package:egg_timer/lab/egg_panel_release_motion.dart';
import 'package:egg_timer/lab/egg_rear_bowl_boundary.dart';
import 'package:egg_timer/lab/egg_rear_bowl_mesh.dart';
import 'package:egg_timer/lab/egg_shell_collision_diagnostic.dart';
import 'package:egg_timer/lab/egg_shell_front_assembly.dart';
import 'package:egg_timer/lab/egg_shell_model.dart';
import 'package:egg_timer/lab/egg_stationary_bowl_shell.dart';

void main() {
  const p0 = EggShellPoint3(0, 0, 0);
  const p1 = EggShellPoint3(2, 0, 0);
  const p2 = EggShellPoint3(0, 2, 0);

  test('V11.14: two separated triangles are not a collision', () {
    expect(EggTriangleCollision.classify(
      p0, p1, p2,
      const EggShellPoint3(0, 0, 3),
      const EggShellPoint3(2, 0, 3),
      const EggShellPoint3(0, 2, 3),
    ), EggTriangleContact.separated);
  });

  test('V11.14: interior penetration in 3D is detected', () {
    expect(EggTriangleCollision.classify(
      p0, p1, p2,
      const EggShellPoint3(.5, .5, -1),
      const EggShellPoint3(.5, .5, 1),
      const EggShellPoint3(1, 1, 1),
    ), EggTriangleContact.intersecting);
  });

  test('V11.14: shared edge is touching, not penetrating', () {
    expect(EggTriangleCollision.classify(
      p0, p1, p2,
      const EggShellPoint3(2, 0, 0),
      const EggShellPoint3(0, 2, 0),
      const EggShellPoint3(2, 2, 0),
    ), EggTriangleContact.touching);
  });

  test('V11.14: coplanar overlapping patches count as touching', () {
    expect(EggTriangleCollision.classify(
      p0, p1, p2,
      const EggShellPoint3(.5, .5, 0),
      const EggShellPoint3(1.5, .5, 0),
      const EggShellPoint3(.5, 1.5, 0),
    ), EggTriangleContact.touching);
  });

  test('V11.14: disjoint coplanar triangles are separated', () {
    expect(EggTriangleCollision.classify(
      p0, p1, p2,
      const EggShellPoint3(5, 5, 0),
      const EggShellPoint3(6, 5, 0),
      const EggShellPoint3(5, 6, 0),
    ), EggTriangleContact.separated);
  });

  test('V11.14: bad tolerance and degenerate geometry are rejected', () {
    expect(() => EggTriangleCollision.classify(
      p0, p1, p2, p0, p1, p2, tolerance: -1,
    ), throwsArgumentError);
    expect(() => EggTriangleCollision.classify(
      p0, p0, p0, p0, p1, p2,
    ), throwsStateError);
  });

  test('V11.14: actual bowl and released panel allow bounded diagnostics', () {
    final network = EggFractureNetwork.fixed();
    final regions = EggFragmentRegionPlan.fromNetwork(network);
    final assembly = EggShellFrontAssemblyBuilder.build(regions);
    final front = EggStationaryBowlShellBuilder.build(assembly);
    final rear = EggRearBowlMeshBuilder.build(
      EggRearBowlBoundaryBuilder.build(front),
    );
    final bowl = EggFullBowlMeshBuilder.build(front, rear);
    final panel = assembly.panels.first;
    final hinge = EggPanelHingePose.fromGraph(
      panel: panel,
      region: regions.regions.first,
      neighbor: regions.regions.last,
      network: network,
      openingDegrees: 30,
    );
    final motion = EggPanelReleaseMotion.fromHinge(
      panel: panel, hinge: hinge, model: network.model,
    );
    final scanner = EggBowlCollisionInspector(
      bowl: bowl, panel: panel, motion: motion,
    );
    final frame = scanner.inspect(.25, maxPairs: 32);
    expect(frame.seconds, .25);
    expect(frame.testedPairs, inInclusiveRange(0, 32));
    expect(frame.touchingPairs + frame.intersectingPairs,
        lessThanOrEqualTo(frame.testedPairs));
    expect(frame.complete || frame.testedPairs == 32, isTrue);
    // Collision results on these real meshes are not assumed a priori:
    // this is a bounded diagnostic, not a clearance certificate.
    expect(() => scanner.inspect(-1), throwsArgumentError);
    expect(() => scanner.inspect(0, maxPairs: 0), throwsArgumentError);
  });
}
