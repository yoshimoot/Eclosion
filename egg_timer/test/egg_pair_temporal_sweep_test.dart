import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:egg_timer/lab/egg_exit_motion_config.dart';
import 'package:egg_timer/lab/egg_exit_motion_config.dart';
import 'package:egg_timer/lab/egg_panel_pair_collision.dart';
import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_panel_hinge_pose.dart';
import 'package:egg_timer/lab/egg_panel_release_motion.dart';
import 'package:egg_timer/lab/egg_pair_temporal_sweep.dart';
import 'package:egg_timer/lab/egg_shell_front_assembly.dart';
import 'package:egg_timer/lab/egg_shell_model.dart';

void main() {
  final graph = EggFractureNetwork.fixed();
  final regions = EggFragmentRegionPlan.fromNetwork(graph);
  late EggShellFrontAssembly assembly;
  late List<EggPanelReleaseMotion> motions;
  late EggPairTemporalSweep sweep;

  setUpAll(() {
    assembly = EggShellFrontAssemblyBuilder.build(regions);
    motions = [
      for (var i = 0; i < 2; i++)
        EggPanelReleaseMotion.fromHinge(
          panel: assembly.panels[i],
          model: graph.model,
          hinge: EggPanelHingePose.fromGraph(
            panel: assembly.panels[i], region: regions.regions[i],
            neighbor: regions.regions[1 - i],
            network: graph, openingDegrees: 30,
          ),
        ),
    ];
    sweep = EggPairTemporalSweep(
      first: assembly.panels[0], second: assembly.panels[1],
      firstMotion: motions[0], secondMotion: motions[1],
    );
  });

  test('V11.16: zero-duration bound and valid finite interval bound', () {
    expect(sweep.displacementBound(
      firstStart: .2, secondStart: .3, duration: 0,
    ), 0);
    expect(sweep.displacementBound(
      firstStart: .2, secondStart: .3, duration: .15,
    ), greaterThan(0));
  });

  test('V11.16: independent inverse confirms conservative motion radius', () {
    final t1 = .3, t2 = .5, span = .12, h = span / 2;
    final bound = sweep.displacementBound(
      firstStart: t1, secondStart: t2, duration: span,
    );
    for (final dt in [0.0, .02, h, .1, span]) {
      for (final p in assembly.panels[1].outer.skip(3).take(12)) {
        final mid = _inverse(
          motions[1].transform(p, t2 + h), motions[0], t1 + h,
        );
        final other = _inverse(
          motions[1].transform(p, t2 + dt), motions[0], t1 + dt,
        );
        expect((other - mid).length, lessThan(bound + 1e-7));
      }
    }
  });

  test('V11.19: pairwise envelope covers lateral 3D departures', () {
    final laterals = [
      for (var i = 0; i < 2; i++)
        EggPanelReleaseMotion.fromHinge(
          panel: assembly.panels[i],
          hinge: motions[i].hinge,
          model: graph.model,
          circumferentialAcceleration: 115,
        ),
    ];
    final check = EggPairTemporalSweep(
      first: assembly.panels[0], second: assembly.panels[1],
      firstMotion: laterals[0], secondMotion: laterals[1],
    );
    const a = .3, b = .5, span = .12, h = span / 2;
    final bound = check.displacementBound(
      firstStart: a, secondStart: b, duration: span,
    );
    for (final dt in [0.0, .03, h, .09, span]) {
      for (final p in assembly.panels[1].outer.skip(3).take(12)) {
        final mid = _inverse(
          laterals[1].transform(p, b + h), laterals[0], a + h,
        );
        final other = _inverse(
          laterals[1].transform(p, b + dt), laterals[0], a + dt,
        );
        expect((other - mid).length, lessThan(bound + 1e-7));
      }
    }
  });

  test('V11.28: material-frame sweep bounds staged falling panels', () {
    final staged = [
      for (var i = 0; i < 2; i++)
        EggExitMotionConfig.build(
          panel: assembly.panels[i],
          hinge: motions[i].hinge,
          model: graph.model,
        ),
    ];
    final check = EggPairTemporalSweep(
      first: assembly.panels[0], second: assembly.panels[1],
      firstMotion: staged[0], secondMotion: staged[1],
    );
    for (final (startA, startB, duration) in [
      (0.20, 0.30, 0.18),
      (0.35, 0.43, 0.22),
      (0.65, 0.80, 0.30),
      (1.30, 1.36, 0.50),
    ]) {
      final midA = startA + duration / 2;
      final midB = startB + duration / 2;
      final bound = check.displacementBound(
        firstStart: startA, secondStart: startB, duration: duration,
      );
      expect(bound, greaterThan(0));
      for (final p in [
        ...assembly.panels[1].outer.skip(3).take(20),
        ...assembly.panels[1].inner.skip(3).take(20),
      ]) {
        final atMid = _inverse(staged[1].transform(p, midB),
            staged[0], midA);
        for (final fraction in [0.0, .25, .5, .75, 1.0]) {
          final offset = duration * fraction;
          final atTime = _inverse(
              staged[1].transform(p, startB + offset),
              staged[0], startA + offset);
          expect((atTime - atMid).length,
              lessThanOrEqualTo(bound + 1e-7));
        }
      }
    }
  });

  test('V11.31: conservative relative envelope while panels settle', () {
    final landed = [
      for (var i = 0; i < 2; i++)
        EggExitMotionConfig.build(
          panel: assembly.panels[i],
          model: graph.model,
          hinge: motions[i].hinge,
        ),
    ];
    for (var firstIndex = 0; firstIndex < 2; firstIndex++) {
      final otherIndex = 1 - firstIndex;
      final first = landed[firstIndex], second = landed[otherIndex];
      final inspector = EggPanelPairCollisionInspector(
        first: assembly.panels[firstIndex],
        second: assembly.panels[otherIndex],
        firstMotion: first,
        secondMotion: second,
      );
      final sweep = EggPairTemporalSweep(
        first: assembly.panels[firstIndex],
        second: assembly.panels[otherIndex],
        firstMotion: first,
        secondMotion: second,
      );
      expect(first.floorImpactSeconds, isNotNull);
      final contact = first.floorImpactSeconds!;
      for (final start in [
        .25,
        math.max(0.0, contact - .08),
        math.min(1.80, contact + .10),
      ]) {
        const duration = .16;
        final mid = start + duration / 2;
        final bound = sweep.displacementBound(
          firstStart: start, secondStart: start, duration: duration,
        );
        expect(bound.isFinite, isTrue);
        for (final point in [
          ...assembly.panels[otherIndex].outer.skip(4).take(20),
          ...assembly.panels[otherIndex].inner.skip(4).take(20),
        ]) {
          final middle = inspector.toFirstMaterialSpace(
            second.transform(point, mid), mid,
          );
          for (final fraction in [0.0, .25, .50, .75, 1.0]) {
            final t = start + duration * fraction;
            final relative = inspector.toFirstMaterialSpace(
              second.transform(point, t), t,
            );
            expect((relative - middle).length,
                lessThanOrEqualTo(bound + 1e-7),
                reason: 'The pair sweep must bound the two-axis '
                    'post-impact material motion at t=$t');
          }
        }
      }
    }
  });

  test('V11.16: deterministic conservative sweep with bounded work', () {
    EggPairSweepReport call() => sweep.inspect(
      firstStart: .3, secondStart: .5, duration: .08,
      maxDepth: 2, maxFrames: 3, maxPairsPerFrame: 24,
    );
    final a = call(), b = call();
    expect(a.verdict, b.verdict);
    expect(a.sampledFrames, b.sampledFrames);
    expect(a.provenIntervals, b.provenIntervals);
    expect(a.unresolvedIntervals, b.unresolvedIntervals);
    expect(a.testedPairs, b.testedPairs);
    expect(a.sampledFrames, inInclusiveRange(0, 3));
    expect(a.testedPairs, lessThanOrEqualTo(3 * 24));
  });

  test('V11.16: no frames cannot invent proof of possible contact', () {
    final result = sweep.inspect(
      firstStart: 0, secondStart: 0, duration: .2,
      maxDepth: 0, maxFrames: 0,
    );
    expect(result.sampledFrames, 0);
    expect(result.hasObservedContact, isFalse);
    if (result.unresolvedIntervals > 0) {
      expect(result.verdict, EggPairSweepVerdict.inconclusive);
    } else {
      expect(result.verdict, EggPairSweepVerdict.certifiedClear);
    }
  });

  test('V11.16: zero interval records a sample or conservative rejection', () {
    final result = sweep.inspect(
      firstStart: .1, secondStart: .2, duration: 0,
      maxFrames: 1, maxPairsPerFrame: 16,
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
  });

  test('V11.16: invalid windows and budgets are rejected', () {
    expect(() => sweep.inspect(
      firstStart: -1, secondStart: 0, duration: 0,
    ), throwsArgumentError);
    expect(() => sweep.inspect(
      firstStart: 1.9, secondStart: .1, duration: .2,
    ), throwsArgumentError);
    expect(() => sweep.inspect(
      firstStart: 0, secondStart: double.nan, duration: .1,
    ), throwsArgumentError);
    expect(() => sweep.inspect(
      firstStart: 0, secondStart: 0, duration: .1,
      maxFrames: -1,
    ), throwsArgumentError);
    expect(() => sweep.inspect(
      firstStart: 0, secondStart: 0, duration: .1,
      maxPairsPerFrame: 0,
    ), throwsArgumentError);
    expect(() => sweep.displacementBound(
      firstStart: 0, secondStart: 0, duration: double.infinity,
    ), throwsArgumentError);
  });
}

EggShellPoint3 _inverse(
  EggShellPoint3 world, EggPanelReleaseMotion motion, double seconds,
) {
  final a = motion.hinge.axis;
  final delta = world - motion.centerAt(seconds);
  final angle = -(motion.hinge.signedRadians +
      motion.spinRadiansAt(seconds));
  final c = math.cos(angle), s = math.sin(angle);
  final cross = EggShellPoint3(
    a.y * delta.z - a.z * delta.y,
    a.z * delta.x - a.x * delta.z,
    a.x * delta.y - a.y * delta.x,
  );
  final projection = a.x * delta.x + a.y * delta.y + a.z * delta.z;
  return motion.materialCenter +
      delta * c + cross * s + a * (projection * (1 - c));
}
