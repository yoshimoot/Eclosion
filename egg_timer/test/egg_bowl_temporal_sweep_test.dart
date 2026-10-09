import 'package:flutter_test/flutter_test.dart';
import 'package:egg_timer/lab/egg_bowl_temporal_sweep.dart';
import 'package:egg_timer/lab/egg_exit_motion_config.dart';
import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_full_bowl_mesh.dart';
import 'package:egg_timer/lab/egg_panel_hinge_pose.dart';
import 'package:egg_timer/lab/egg_panel_release_motion.dart';
import 'package:egg_timer/lab/egg_rear_bowl_boundary.dart';
import 'package:egg_timer/lab/egg_rear_bowl_mesh.dart';
import 'package:egg_timer/lab/egg_shell_front_assembly.dart';
import 'package:egg_timer/lab/egg_stationary_bowl_shell.dart';

void main() {
  final network = EggFractureNetwork.fixed();
  final regions = EggFragmentRegionPlan.fromNetwork(network);
  late EggShellFrontAssembly assembly;
  late List<EggPanelReleaseMotion> motions;
  late List<EggBowlTemporalSweep> sweeps;
  late EggFullBowlMesh bowl;

  setUpAll(() {
    assembly = EggShellFrontAssemblyBuilder.build(regions);
    final front = EggStationaryBowlShellBuilder.build(assembly);
    final rear = EggRearBowlMeshBuilder.build(
      EggRearBowlBoundaryBuilder.build(front),
    );
    bowl = EggFullBowlMeshBuilder.build(front, rear);
    motions = <EggPanelReleaseMotion>[
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
    sweeps = [
      for (var i = 0; i < 2; i++)
        EggBowlTemporalSweep(
          bowl: bowl, panel: assembly.panels[i], motion: motions[i],
        ),
    ];
  });

  test('V11.17: zero window has zero displacement allowance', () {
    for (final sweep in sweeps) {
      expect(sweep.displacementBound(start: .2, duration: 0), 0);
      expect(sweep.displacementBound(start: .2, duration: .1),
          greaterThan(0));
    }
  });

  test('V11.17: every sampled vertex remains inside the swept bound', () {
    for (var i = 0; i < 2; i++) {
      final motion = motions[i];
      final panel = assembly.panels[i];
      const start = .3, span = .12, half = span / 2;
      final bound = sweeps[i].displacementBound(
        start: start, duration: span,
      );
      for (final group in [panel.outer, panel.inner]) {
        for (final p in group.skip(4).take(18)) {
          final middle = motion.transform(p, start + half);
          for (final fraction in [0.0, .15, .4, .7, 1.0]) {
            final moved = motion.transform(p, start + span * fraction);
            expect((moved - middle).length,
                lessThanOrEqualTo(bound + 1e-7));
          }
        }
      }
    }
  });

  test('V11.19: temporal envelope contains lateral 3D departure', () {
    for (var i = 0; i < 2; i++) {
      final panel = assembly.panels[i];
      final motion = EggPanelReleaseMotion.fromHinge(
        panel: panel, model: network.model, hinge: motions[i].hinge,
        circumferentialAcceleration: 115,
      );
      final sweep = EggBowlTemporalSweep(
        bowl: bowl, panel: panel, motion: motion,
      );
      const start = .5, duration = .12, half = duration / 2;
      final bound = sweep.displacementBound(
        start: start, duration: duration,
      );
      for (final point in panel.outer.skip(4).take(20)) {
        final atMiddle = motion.transform(point, start + half);
        for (final fraction in [0.0, .2, .5, .8, 1.0]) {
          expect((motion.transform(point, start + fraction * duration) -
                  atMiddle).length,
              lessThanOrEqualTo(bound + 1e-7));
        }
      }
    }
  });

  test('V11.28: staged gravity never escapes tighter swept bounds', () {
    for (var i = 0; i < 2; i++) {
      final panel = assembly.panels[i];
      final moving = EggExitMotionConfig.build(
        panel: panel,
        hinge: motions[i].hinge,
        model: network.model,
      );
      final sweep = EggBowlTemporalSweep(
        bowl: bowl, panel: panel, motion: moving,
      );
      for (final (start, span) in [
        (0.05, 0.22),
        (0.33, 0.13),
        (0.42, 0.18),
        (0.78, 0.32),
        (1.40, 0.60),
      ]) {
        final midpoint = start + span / 2;
        final bound = sweep.displacementBound(
          start: start, duration: span,
        );
        expect(bound, greaterThan(0));
        // Include the furthest real model points, not only a centre probe.
        for (final group in [panel.outer, panel.inner]) {
          final stride = (group.length ~/ 35).clamp(1, 100000);
          for (var k = 0; k < group.length; k += stride) {
            final point = group[k];
            final atMid = moving.transform(point, midpoint);
            for (final fraction in [0.0, .15, .4, .75, 1.0]) {
              final actual =
                  moving.transform(point, start + span * fraction);
              expect((actual - atMid).length,
                  lessThanOrEqualTo(bound + 1e-7));
            }
          }
        }
      }
    }
  });

  test('V11.17: same bounded diagnostic gives deterministic reports', () {
    for (final sweep in sweeps) {
      EggBowlSweepReport run() => sweep.inspect(
        start: .35, duration: .08, maxDepth: 2,
        maxFrames: 3, maxPairsPerFrame: 24,
      );
      final a = run(), b = run();
      expect(a.verdict, b.verdict);
      expect(a.sampledFrames, b.sampledFrames);
      expect(a.provenIntervals, b.provenIntervals);
      expect(a.unresolvedIntervals, b.unresolvedIntervals);
      expect(a.testedPairs, b.testedPairs);
      expect(a.sampledFrames, inInclusiveRange(0, 3));
      expect(a.testedPairs, lessThanOrEqualTo(72));
    }
  });

  test('V11.17: exhausted frames never claim unsupported clearance', () {
    for (final sweep in sweeps) {
      final result = sweep.inspect(
        start: 0, duration: .2, maxDepth: 0, maxFrames: 0,
      );
      expect(result.sampledFrames, 0);
      expect(result.hasObservedContact, isFalse);
      expect(result.verdict,
          result.unresolvedIntervals > 0
              ? EggBowlSweepVerdict.inconclusive
              : EggBowlSweepVerdict.certifiedClear);
    }
  });

  test('V11.17: zero duration cannot hide a candidate interval', () {
    for (final sweep in sweeps) {
      final result = sweep.inspect(
        start: .2, duration: 0, maxFrames: 1,
        maxPairsPerFrame: 16,
      );
      expect(result.sampledFrames, inInclusiveRange(0, 1));
      expect(result.testedPairs, inInclusiveRange(0, 16));
      if (result.hasObservedContact) {
        expect(result.firstObservedTime, 0);
        expect(result.firstObservedFrame?.hasContact, isTrue);
      }
      if (result.provenClear) {
        expect(result.unresolvedIntervals, 0);
      }
    }
  });

  test('V11.17: illegal time windows and budgets cannot be accepted', () {
    for (final sweep in sweeps) {
      expect(() => sweep.inspect(
        start: -1, duration: 0,
      ), throwsArgumentError);
      expect(() => sweep.inspect(
        start: 1.95, duration: .1,
      ), throwsArgumentError);
      expect(() => sweep.inspect(
        start: double.nan, duration: .1,
      ), throwsArgumentError);
      expect(() => sweep.inspect(
        start: .1, duration: .2, maxFrames: -1,
      ), throwsArgumentError);
      expect(() => sweep.inspect(
        start: .1, duration: .2, maxPairsPerFrame: 0,
      ), throwsArgumentError);
      expect(() => sweep.displacementBound(
        start: .1, duration: double.infinity,
      ), throwsArgumentError);
    }
  });
}
