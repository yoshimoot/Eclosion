import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_panel_hinge_pose.dart';
import 'package:egg_timer/lab/egg_panel_release_motion.dart';
import 'package:egg_timer/lab/egg_shell_front_assembly.dart';
import 'package:egg_timer/lab/egg_shell_fragment_mesh.dart';
import 'package:egg_timer/lab/egg_shell_model.dart';

void main() {
  final graph = EggFractureNetwork.fixed();
  final regions = EggFragmentRegionPlan.fromNetwork(graph);
  late List<EggShellPanelMesh> panels;

  setUpAll(() {
    panels = EggShellFrontAssemblyBuilder.build(regions).panels;
  });

  EggPanelReleaseMotion motion(int i, {double angle = 30}) {
    final hinge = EggPanelHingePose.fromGraph(
      panel: panels[i],
      region: regions.regions[i],
      neighbor: regions.regions[1 - i],
      network: graph,
      openingDegrees: angle,
    );
    return EggPanelReleaseMotion.fromHinge(
      panel: panels[i], hinge: hinge, model: graph.model,
    );
  }

  double dot(EggShellPoint3 a, EggShellPoint3 b) =>
      a.x * b.x + a.y * b.y + a.z * b.z;

  test('V11.13: no jump at attachment release, for both panels', () {
    for (var i = 0; i < 2; i++) {
      final release = motion(i);
      final panel = panels[i];
      for (final vertices in [panel.outer, panel.inner]) {
        for (var j = 0; j < vertices.length; j += 29) {
          final hinged = release.hinge.transform(vertices[j]);
          final newlyReleased = release.transform(vertices[j], 0);
          expect((hinged - newlyReleased).length, lessThan(1e-8));
        }
      }
      final near = release.transform(panel.outer[0], 1e-6);
      expect(
        (near - release.hinge.transform(panel.outer[0])).length,
        lessThan(1e-3),
      );
      expect((release.centerAt(0) - release.releaseCenter).length,
          lessThan(1e-10));
    }
  });

  test('V11.13: outward travel is monotonic and follows one physical normal', () {
    for (var i = 0; i < 2; i++) {
      final release = motion(i);
      expect(release.outward.length, closeTo(1, 1e-10));
      expect(release.outwardDistanceAt(0), 0);
      final d1 = release.outwardDistanceAt(.2);
      final d2 = release.outwardDistanceAt(.5);
      final d3 = release.outwardDistanceAt(1);
      expect(0 < d1 && d1 < d2 && d2 < d3, isTrue);
      for (final t in [.2, .5, 1.0]) {
        final delta = release.centerAt(t) - release.releaseCenter;
        expect(delta.length, closeTo(release.outwardDistanceAt(t), 1e-8));
        expect(dot(delta, release.outward),
            closeTo(release.outwardDistanceAt(t), 1e-8));
      }
    }
  });

  test('V11.13: combined push and spin keep all shell distances', () {
    for (var i = 0; i < 2; i++) {
      final release = motion(i);
      final p = panels[i];
      final stride = math.max(1, p.outer.length ~/ 25);
      for (final t in [0.0, .3, .8, 1.5]) {
        final outer = release.transformAll(p.outer, t);
        final inner = release.transformAll(p.inner, t);
        for (var j = 0; j < outer.length; j += stride) {
          expect((outer[j] - inner[j]).length,
              closeTo(p.thickness, 1e-7));
          final k = (j + stride) % outer.length;
          expect((outer[j] - outer[k]).length,
              closeTo((p.outer[j] - p.outer[k]).length, 1e-7));
          expect(release.rotateNormal(
                  graph.model.normalAt(p.outer[j]), t).length,
              closeTo(1, 1e-9));
        }
      }
      expect(release.spinRadiansAt(.8).abs(), greaterThan(0));
      expect(p.sideTriangles.length, p.rim.length * 2);
    }
  });

  test('V11.13: spin originates at the release-time material centre', () {
    for (var i = 0; i < 2; i++) {
      final release = motion(i);
      for (final t in [0.0, .4, 1.2]) {
        expect(
          (release.transform(release.materialCenter, t) -
              release.centerAt(t)).length,
          lessThan(1e-8),
        );
        expect(release.spinRadiansAt(t),
            closeTo(release.spinSign * 28 * math.pi / 180 * t, 1e-12));
      }
    }
  });

  test('V11.19: optional 3D circumferential release preserves material', () {
    for (var i = 0; i < 2; i++) {
      final original = motion(i);
      final panel = panels[i];
      final biased = EggPanelReleaseMotion.fromHinge(
        panel: panel,
        hinge: original.hinge,
        model: graph.model,
        circumferentialAcceleration: 115,
      );
      expect(biased.circumferential.length, closeTo(1, 1e-9));
      expect(dot(biased.circumferential, biased.outward),
          closeTo(0, 1e-9));
      expect(biased.circumferential.x * biased.materialCenter.x,
          greaterThan(0));
      for (final t in [0.0, .15, .45, 1.2]) {
        final added = biased.centerAt(t) - original.centerAt(t);
        expect(added.length,
            closeTo(115 * t * t / 2, 1e-8));
        expect(dot(added, biased.outward), closeTo(0, 1e-8));
        final point = panel.outer[0];
        final inner = panel.inner[0];
        expect((biased.transform(point, t) -
                biased.transform(inner, t)).length,
            closeTo(panel.thickness, 1e-7));
      }
      expect(
        (biased.transform(panel.outer[0], 0) -
            original.transform(panel.outer[0], 0)).length,
        lessThan(1e-9),
      );
      expect(original.circumferentialAcceleration, 0);
      expect(original.circumferentialDistanceAt(1.2), 0);
      expect(() => EggPanelReleaseMotion.fromHinge(
        panel: panel, hinge: original.hinge, model: graph.model,
        circumferentialAcceleration: -1,
      ), throwsArgumentError);
    }
  });

  test('V11.25: clear by material thickness before sideways spin', () {
    for (var i = 0; i < 2; i++) {
      final baseline = motion(i);
      final panel = panels[i];
      final staged = EggPanelReleaseMotion.fromHinge(
        panel: panel,
        hinge: baseline.hinge,
        model: graph.model,
        circumferentialAcceleration: 115,
        minimumOutwardClearance: 3 * panel.thickness,
      );
      final start = staged.clearanceStartSeconds;
      expect(start, inExclusiveRange(.3, .5));
      expect(staged.outwardDistanceAt(start),
          closeTo(3 * panel.thickness, 1e-8));
      for (final t in [0.0, start / 2, start]) {
        expect(staged.spinRadiansAt(t), 0);
        expect(staged.circumferentialDistanceAt(t), 0);
        expect(
          (staged.centerAt(t) -
                  staged.releaseCenter -
                  staged.outward * staged.outwardDistanceAt(t))
              .length,
          lessThan(1e-8),
        );
      }
      // Spin and translation both begin at zero velocity at the threshold.
      final shortlyAfter = start + .00001;
      expect(staged.spinRadiansAt(shortlyAfter).abs(),
          lessThan(1e-7));
      expect(staged.circumferentialDistanceAt(shortlyAfter),
          lessThan(1e-7));
      expect(staged.spinRadiansAt(1.2).abs(), greaterThan(0));
      expect(staged.circumferentialDistanceAt(1.2),
          greaterThan(0));
      for (final t in [0.0, .12, start, .7, 1.2]) {
        final surface = staged.transform(panel.outer[0], t);
        final inner = staged.transform(panel.inner[0], t);
        expect((surface - inner).length,
            closeTo(panel.thickness, 1e-7));
      }
      expect(
        (staged.transform(panel.outer[0], 0) -
                baseline.hinge.transform(panel.outer[0]))
            .length,
        lessThan(1e-8),
      );
      expect(baseline.clearanceStartSeconds, 0);
      expect(() => EggPanelReleaseMotion.fromHinge(
        panel: panel, hinge: baseline.hinge, model: graph.model,
        minimumOutwardClearance: -1,
      ), throwsArgumentError);
      expect(() => EggPanelReleaseMotion.fromHinge(
        panel: panel, hinge: baseline.hinge, model: graph.model,
        minimumOutwardClearance: double.infinity,
      ), throwsArgumentError);
      expect(() => EggPanelReleaseMotion.fromHinge(
        panel: panel, hinge: baseline.hinge, model: graph.model,
        minimumOutwardClearance: 1e5,
      ), throwsArgumentError);
    }
  });

  test('V11.13: pure deterministic query, no frame-to-frame accumulation', () {
    for (var i = 0; i < 2; i++) {
      final release = motion(i);
      final point = panels[i].outer[0];
      final one = release.transform(point, .75);
      release.transform(point, 1.75);
      release.transform(point, .25);
      final again = release.transform(point, .75);
      expect((again - one).length, lessThan(1e-12));
      expect(release.hinge.openingDegrees, 30);
    }
  });

  test('V11.13: reject invalid release rate, time and closed hinge', () {
    for (var i = 0; i < 2; i++) {
      final release = motion(i);
      final p = panels[i];
      expect(() => release.centerAt(-.1), throwsArgumentError);
      expect(() => release.spinRadiansAt(double.nan), throwsArgumentError);
      expect(() => release.transformAll(p.outer, 3),
          throwsArgumentError);
      final zero = EggPanelHingePose.fromGraph(
        panel: p,
        region: regions.regions[i],
        neighbor: regions.regions[1 - i],
        network: graph,
        openingDegrees: 0,
      );
      expect(() => EggPanelReleaseMotion.fromHinge(
        panel: p, hinge: zero, model: graph.model,
      ), throwsArgumentError);
      expect(() => EggPanelReleaseMotion.fromHinge(
        panel: p, hinge: release.hinge, model: graph.model,
        initialSpeed: -1,
      ), throwsArgumentError);
      expect(() => EggPanelReleaseMotion.fromHinge(
        panel: p, hinge: release.hinge, model: graph.model,
        outwardAcceleration: double.infinity,
      ), throwsArgumentError);
      expect(() => EggPanelReleaseMotion.fromHinge(
        panel: p, hinge: release.hinge, model: graph.model,
        initialSpeed: 0, outwardAcceleration: 0,
      ), throwsArgumentError);
    }
  });
}
