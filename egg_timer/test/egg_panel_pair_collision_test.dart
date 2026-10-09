import 'package:flutter_test/flutter_test.dart';

import 'package:egg_timer/lab/egg_exit_motion_config.dart';
import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_panel_hinge_pose.dart';
import 'package:egg_timer/lab/egg_panel_pair_collision.dart';
import 'package:egg_timer/lab/egg_panel_release_motion.dart';
import 'package:egg_timer/lab/egg_shell_front_assembly.dart';

void main() {
  final network = EggFractureNetwork.fixed();
  final regions = EggFragmentRegionPlan.fromNetwork(network);
  late EggShellFrontAssembly assembly;
  late List<EggPanelReleaseMotion> motions;
  late EggPanelPairCollisionInspector inspector;

  setUpAll(() {
    assembly = EggShellFrontAssemblyBuilder.build(regions);
    motions = [
      for (var i = 0; i < 2; i++)
        EggPanelReleaseMotion.fromHinge(
          panel: assembly.panels[i],
          model: network.model,
          hinge: EggPanelHingePose.fromGraph(
            panel: assembly.panels[i],
            region: regions.regions[i],
            neighbor: regions.regions[1 - i],
            network: network,
            openingDegrees: 30,
          ),
        ),
    ];
    inspector = EggPanelPairCollisionInspector(
      first: assembly.panels[0],
      second: assembly.panels[1],
      firstMotion: motions[0],
      secondMotion: motions[1],
    );
  });

  test('V11.15: first rigid motion inverts into its material frame', () {
    final points = assembly.panels.first.outer;
    for (final t in [0.0, .2, 1.0, 1.8]) {
      for (var i = 0; i < points.length; i += 47) {
        final world = motions.first.transform(points[i], t);
        final restored = inspector.toFirstMaterialSpace(world, t);
        expect((restored - points[i]).length, lessThan(1e-8));
      }
    }
  });

  test('V11.31: post-impact inverse matches exact rendered rigid mesh', () {
    final grounded = [
      for (var i = 0; i < 2; i++)
        EggExitMotionConfig.build(
          panel: assembly.panels[i],
          model: network.model,
          hinge: motions[i].hinge,
        ),
    ];
    for (var firstIndex = 0; firstIndex < 2; firstIndex++) {
      final otherIndex = 1 - firstIndex;
      final check = EggPanelPairCollisionInspector(
        first: assembly.panels[firstIndex],
        second: assembly.panels[otherIndex],
        firstMotion: grounded[firstIndex],
        secondMotion: grounded[otherIndex],
      );
      final motion = grounded[firstIndex];
      final impact = motion.floorImpactSeconds;
      expect(impact, isNotNull);
      final tHit = impact!;
      for (final t in [
        0.0, .12, tHit,
        tHit + .01,
        tHit + .12,
        (tHit + 2.0) / 2,
        2.0,
      ]) {
        if (t > 2.0) continue;
        for (final vertices in [
          assembly.panels[firstIndex].outer,
          assembly.panels[firstIndex].inner,
        ]) {
          for (var i = 0; i < vertices.length; i += 41) {
            final vertex = vertices[i];
            final world = motion.transform(vertex, t);
            final recovered = check.toFirstMaterialSpace(world, t);
            expect((recovered - vertex).length, lessThan(1e-7),
                reason: 'Wrong inverse for material vertex $i of '
                    'panel $firstIndex at t=$t');
          }
        }
        // The independent panel's WORLD vertices must also roundtrip
        // through the inverse of the FIRST panel's pose, even when one
        // panel has landed and the other is still in flight.
        final secondTime = t > .10 ? t - .10 : t;
        final otherVertex = assembly.panels[otherIndex].outer[21];
        final otherWorld = grounded[otherIndex].transform(
          otherVertex, secondTime,
        );
        final relative = check.toFirstMaterialSpace(otherWorld, t);
        expect((motion.transform(relative, t) - otherWorld).length,
            lessThan(1e-7),
            reason: 'The pair collision frame must agree with Chrome '
                'after ground roll');
      }
    }
  });

  test('V11.15: world-to-material conversion also handles second panel', () {
    final point = assembly.panels[1].outer[21];
    final world = motions[1].transform(point, .7);
    final local = inspector.toFirstMaterialSpace(world, .3);
    expect((motions[0].transform(local, .3) - world).length,
        lessThan(1e-8));
  });

  test('V11.15: independent release clocks and bounded work report', () {
    final frame = inspector.inspect(
      firstSeconds: .25, secondSeconds: .8, maxPairs: 32,
    );
    expect(frame.firstSeconds, .25);
    expect(frame.secondSeconds, .8);
    expect(frame.testedPairs, inInclusiveRange(0, 32));
    expect(frame.touchingPairs + frame.intersectingPairs,
        lessThanOrEqualTo(frame.testedPairs));
    expect(frame.complete || frame.testedPairs == 32, isTrue);
    expect(frame.sampledFrameClear,
        frame.complete && !frame.hasContact);
    if (frame.firstTouchingTrianglePair case final pair?) {
      expect(pair.$1, greaterThanOrEqualTo(0));
      expect(pair.$2, greaterThanOrEqualTo(0));
      expect(frame.touchingPairs, greaterThan(0));
    }
    if (frame.firstIntersectingTrianglePair case final pair?) {
      expect(pair.$1, greaterThanOrEqualTo(0));
      expect(pair.$2, greaterThanOrEqualTo(0));
      expect(frame.intersectingPairs, greaterThan(0));
    }
  });

  test('V11.15: same instant and reversed query order are deterministic', () {
    final a = inspector.inspect(
      firstSeconds: .4, secondSeconds: .4, maxPairs: 16,
    );
    final b = inspector.inspect(
      firstSeconds: .4, secondSeconds: .4, maxPairs: 16,
    );
    expect((a.testedPairs, a.touchingPairs, a.intersectingPairs, a.complete),
        (b.testedPairs, b.touchingPairs, b.intersectingPairs, b.complete));
    final reverse = EggPanelPairCollisionInspector(
      first: assembly.panels[1],
      second: assembly.panels[0],
      firstMotion: motions[1],
      secondMotion: motions[0],
    );
    final reverseFrame = reverse.inspect(
      firstSeconds: .4, secondSeconds: .4, maxPairs: 16,
    );
    expect(reverseFrame.testedPairs, inInclusiveRange(0, 16));
    expect(reverseFrame.touchingPairs + reverseFrame.intersectingPairs,
        lessThanOrEqualTo(reverseFrame.testedPairs));
  });

  test('V11.15: invalid time and budget cannot yield a clear verdict', () {
    expect(() => inspector.inspect(
      firstSeconds: -1, secondSeconds: 0,
    ), throwsArgumentError);
    expect(() => inspector.inspect(
      firstSeconds: 0, secondSeconds: 2.1,
    ), throwsArgumentError);
    expect(() => inspector.inspect(
      firstSeconds: double.nan, secondSeconds: .2,
    ), throwsArgumentError);
    expect(() => inspector.inspect(
      firstSeconds: 0, secondSeconds: 0, maxPairs: 0,
    ), throwsArgumentError);
  });

  test('V11.15: reversed motion owner and invalid tolerance are rejected', () {
    expect(() => EggPanelPairCollisionInspector(
      first: assembly.panels[0],
      second: assembly.panels[1],
      firstMotion: motions[1],
      secondMotion: motions[0],
    ), throwsStateError);
    expect(() => EggPanelPairCollisionInspector(
      first: assembly.panels[0],
      second: assembly.panels[0],
      firstMotion: motions[0],
      secondMotion: motions[0],
    ), throwsArgumentError);
    expect(() => EggPanelPairCollisionInspector(
      first: assembly.panels[0],
      second: assembly.panels[1],
      firstMotion: motions[0],
      secondMotion: motions[1],
      tolerance: double.infinity,
    ), throwsArgumentError);
  });
}
