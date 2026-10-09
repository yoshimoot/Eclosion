import 'package:egg_timer/lab/egg_exit_motion_config.dart';
import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_geometry_preview.dart';
import 'package:egg_timer/lab/egg_panel_hinge_pose.dart';
import 'package:egg_timer/lab/egg_panel_release_motion.dart';
import 'package:egg_timer/lab/egg_shell_front_assembly.dart';
import 'package:egg_timer/lab/egg_shell_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final network = EggFractureNetwork.fixed();
  final regions = EggFragmentRegionPlan.fromNetwork(network);

  test('V11.18: pivot and release have exact endpoints', () {
    expect(EggExitTimeline.hingeAngle(0), 0);
    expect(EggExitTimeline.hingeAngle(.55), 30);
    expect(EggExitTimeline.hingeAngle(1), 30);
    expect(EggExitTimeline.freeSeconds(.55), 0);
    expect(EggExitTimeline.freeSeconds(1), 2.0);
    expect(EggExitTimeline.freeSeconds(.775), closeTo(1.0, 1e-12));
    expect(EggExitTimeline.released(.55), isFalse);
    expect(EggExitTimeline.released(.56), isTrue);
  });

  test('V11.18: hinge progression stays monotonic', () {
    var previous = 0.0;
    for (var i = 0; i <= 55; i++) {
      final angle = EggExitTimeline.hingeAngle(i / 100);
      expect(angle, greaterThanOrEqualTo(previous));
      expect(angle, inInclusiveRange(0, 30));
      previous = angle;
    }
  });

  test('V11.18: exact geometry at break, plus solid thickness', () {
    final assembly = EggShellFrontAssemblyBuilder.build(regions);
    for (var i = 0; i < 2; i++) {
      final panel = assembly.panels[i];
      final hinge = EggPanelHingePose.fromGraph(
        panel: panel,
        region: regions.regions[i],
        neighbor: regions.regions[1 - i],
        network: network,
        openingDegrees: EggExitTimeline.hingeAngle(.55),
      );
      final release = EggPanelReleaseMotion.fromHinge(
        panel: panel, hinge: hinge, model: network.model,
      );
      final time = EggExitTimeline.freeSeconds(.8);
      for (var j = 0; j < panel.outer.length; j += 31) {
        expect((hinge.transform(panel.outer[j]) -
                release.transform(panel.outer[j], 0)).length,
            lessThan(1e-8));
        expect((hinge.transform(panel.inner[j]) -
                release.transform(panel.inner[j], 0)).length,
            lessThan(1e-8));
        expect((release.transform(panel.outer[j], time) -
                release.transform(panel.inner[j], time)).length,
            closeTo(2.5, 1e-7));
      }
    }
  });

  test('V11.20: depth raster follows negative and positive vertices', () {
    final bounds = EggDepthRasterBounds.fromPoints([
      const EggShellPoint3(-239.7, -183, 28),
      const EggShellPoint3(218.4, 154, -65),
      const EggShellPoint3(0, 0, 0),
    ]);
    expect(bounds.left, lessThan(-239));
    expect(bounds.top, lessThan(-183));
    expect(bounds.width, greaterThan(450));
    expect(bounds.height, greaterThan(335));
    for (final p in [
      const EggShellPoint3(-239.7, -183, 28),
      const EggShellPoint3(218.4, 154, -65),
      const EggShellPoint3(0, 0, 0),
    ]) {
      expect(bounds.contains(p), isTrue);
    }
    expect(() => EggDepthRasterBounds.fromPoints([]),
        throwsArgumentError);
    expect(() => EggDepthRasterBounds.fromPoints([
      const EggShellPoint3(double.nan, 0, 0),
    ]), throwsArgumentError);
  });

  test('V11.20: static exit camera contains both complete panels', () {
    final assembly = EggShellFrontAssemblyBuilder.build(regions);
    final motions = [
      for (var i = 0; i < 2; i++)
        EggExitMotionConfig.build(
          panel: assembly.panels[i],
          model: network.model,
          hinge: EggPanelHingePose.fromGraph(
            panel: assembly.panels[i],
            region: regions.regions[i],
            neighbor: regions.regions[1 - i],
            network: network,
            openingDegrees: EggExitTimeline.finalHingeDegrees,
          ),
        ),
    ];
    // Lock the exact experimental Chrome configuration as a visible
    // contract: diagnostics should not accidentally test a different run.
    expect(EggExitMotionConfig.circumferentialAcceleration, 115);
    expect(EggExitMotionConfig.gravityAcceleration, 220);
    expect(EggExitMotionConfig.clearanceThicknesses, 3);
    for (var i = 0; i < 2; i++) {
      final motion = motions[i];
      expect(motion.circumferentialAcceleration, 115);
      expect(motion.gravityAcceleration, 220);
      expect(motion.minimumOutwardClearance,
          closeTo(3 * assembly.panels[i].thickness, 1e-12));
      expect(motion.fallDistanceAt(motion.clearanceStartSeconds), 0);
    }
    final extent = EggExitFraming.horizontalExtent(
      stationaryRadius: network.model.maxRadius,
      panels: assembly.panels,
      motions: motions,
    );
    expect(extent, greaterThan(network.model.maxRadius));
    // Check intermediate times offset from the framing samples, to
    // catch end-point-only assumptions or a frame-dependent camera.
    for (var i = 0; i < 2; i++) {
      for (final group in [
        assembly.panels[i].outer,
        assembly.panels[i].inner,
      ]) {
        for (final p in group) {
          for (var s = 0; s < 24; s++) {
            final t = EggExitTimeline.freeDuration * (s + .5) / 24;
            expect(motions[i].transform(p, t).x.abs(),
                lessThan(extent));
          }
        }
      }
    }
    final verticalExtent = EggExitFraming.verticalExtent(
      stationaryHalfHeight: network.model.halfHeight,
      panels: assembly.panels,
      motions: motions,
    );
    expect(verticalExtent, greaterThan(network.model.halfHeight));
    for (var i = 0; i < 2; i++) {
      for (final group in [
        assembly.panels[i].outer,
        assembly.panels[i].inner,
      ]) {
        for (final p in group) {
          for (var sample = 0; sample < 24; sample++) {
            final time =
                EggExitTimeline.freeDuration * (sample + .5) / 24;
            expect(motions[i].transform(p, time).y.abs(),
                lessThan(verticalExtent));
          }
        }
      }
    }
    // V11.30: the exact outer + inner shell meshes must contact the
    // physical floor and remain above it after the first material impact.
    const floorTolerance = 1e-5;
    for (var i = 0; i < 2; i++) {
      final motion = motions[i];
      expect(motion.floorImpactSeconds, isNotNull,
          reason: 'Panel $i must reach the ground by the end of the exit');
      final impact = motion.floorImpactSeconds!;
      expect(impact, inExclusiveRange(.40, 2.0));
      expect(motion.floorY, network.model.halfHeight + 8);
      final preContact = EggPanelReleaseMotion.fromHinge(
        panel: assembly.panels[i],
        model: network.model,
        hinge: motion.hinge,
        circumferentialAcceleration:
            EggExitMotionConfig.circumferentialAcceleration,
        minimumOutwardClearance:
            EggExitMotionConfig.clearanceThicknesses *
                assembly.panels[i].thickness,
        gravityAcceleration: EggExitMotionConfig.gravityAcceleration,
      );
      for (final t in [0.0, .12, .30, impact * .9, impact]) {
        final p = assembly.panels[i].outer[0];
        expect((motion.transform(p, t) - preContact.transform(p, t)).length,
            lessThan(1e-8));
      }
      // Contact changes motion, not material dimensions: outside,
      // interior and original 2.5-thick walls share one rigid transform.
      for (final t in [0.0, .4, impact, (impact + 2) / 2, 2.0]) {
        var maxY = double.negativeInfinity;
        final panel = assembly.panels[i];
        for (final group in [panel.outer, panel.inner]) {
          for (final v in group) {
            final placed = motion.transform(v, t);
            if (placed.y > maxY) maxY = placed.y;
          }
        }
        expect(maxY,
            lessThanOrEqualTo(motion.floorY! + floorTolerance),
            reason: 'Rigid panel $i crosses floor at t=$t');
        if (t >= impact) {
          expect(maxY, closeTo(motion.floorY!, floorTolerance));
        }
        for (var j = 0; j < panel.outer.length; j += 30) {
          final wallThickness =
              (motion.transform(panel.outer[j], t) -
                      motion.transform(panel.inner[j], t)).length;
          expect(wallThickness, closeTo(panel.thickness, 1e-7));
        }
      }
      final last = motion.centerAt(2.0);
      final justAfter = motion.centerAt(impact + 1e-6);
      final atImpact = motion.centerAt(impact);
      expect((atImpact - justAfter).length, lessThan(.01));
      expect(motion.spinRadiansAt(2),
          closeTo(motion.spinRadiansAt(impact), 1e-12));
      expect(last.y, closeTo(atImpact.y, 1e-8));
    }
    expect(() => EggExitFraming.verticalExtent(
      stationaryHalfHeight: -1, panels: assembly.panels, motions: motions,
    ), throwsArgumentError);
    expect(() => EggExitFraming.horizontalExtent(
      stationaryRadius: -1, panels: assembly.panels, motions: motions,
    ), throwsArgumentError);
  });

  test('V11.18: malformed progress is refused', () {
    for (final value in [double.nan, double.infinity, -.01, 1.01]) {
      expect(() => EggExitTimeline.hingeAngle(value), throwsArgumentError);
      expect(() => EggExitTimeline.freeSeconds(value), throwsArgumentError);
      expect(() => EggExitTimeline.released(value), throwsArgumentError);
    }
  });
}
