import 'package:egg_timer/lab/egg_exit_motion_config.dart';
import 'package:egg_timer/lab/egg_bowl_temporal_sweep.dart';
import 'package:egg_timer/lab/egg_pair_temporal_sweep.dart';
import 'package:egg_timer/lab/egg_fragment_regions.dart';
import 'package:egg_timer/lab/egg_fracture_network.dart';
import 'package:egg_timer/lab/egg_full_bowl_mesh.dart';
import 'package:egg_timer/lab/egg_panel_hinge_pose.dart';
import 'package:egg_timer/lab/egg_panel_pair_collision.dart';
import 'package:egg_timer/lab/egg_panel_release_motion.dart';
import 'package:egg_timer/lab/egg_rear_bowl_boundary.dart';
import 'package:egg_timer/lab/egg_rear_bowl_mesh.dart';
import 'package:egg_timer/lab/egg_shell_collision_diagnostic.dart';
import 'package:egg_timer/lab/egg_shell_front_assembly.dart';
import 'package:egg_timer/lab/egg_stationary_bowl_shell.dart';
import 'package:egg_timer/lab/egg_shell_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// V11.27: inspect the complete 2s radial, lateral and falling exit.
/// No movement, geometry, drawing or collision response is modified.
/// A sampled clear frame NEVER certifies clearance between samples.
void main() {
  test('V11.27: staged gravity exit and sampled material clearance', () {
    final network = EggFractureNetwork.fixed();
    final regions = EggFragmentRegionPlan.fromNetwork(network);
    final assembly = EggShellFrontAssemblyBuilder.build(regions);
    final front = EggStationaryBowlShellBuilder.build(assembly);
    final rear = EggRearBowlMeshBuilder.build(
      EggRearBowlBoundaryBuilder.build(front),
    );
    final bowl = EggFullBowlMeshBuilder.build(front, rear);
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
            openingDegrees: 30,
          ),
        ),
    ];
    final againstBowl = [
      for (var i = 0; i < 2; i++)
        EggBowlCollisionInspector(
          bowl: bowl,
          panel: assembly.panels[i],
          motion: motions[i],
        ),
    ];
    final betweenPanels = EggPanelPairCollisionInspector(
      first: assembly.panels[0],
      second: assembly.panels[1],
      firstMotion: motions[0],
      secondMotion: motions[1],
    );

    final fixedVertices = [...bowl.outer, ...bowl.inner];
    final fixedFaces = [...bowl.allFaces];

    String fixedSurface(int id) {
      var index = id;
      if (index < front.outerFaces.length) return 'bol avant extérieur';
      index -= front.outerFaces.length;
      if (index < rear.outerFaces.length) return 'bol arrière extérieur';
      index -= rear.outerFaces.length;
      if (index < front.innerFaces.length) return 'bol avant intérieur';
      index -= front.innerFaces.length;
      if (index < rear.innerFaces.length) return 'bol arrière intérieur';
      index -= rear.innerFaces.length;
      if (index < front.upperCutWalls.length) return 'bol avant tranche';
      return 'bol arrière tranche';
    }

    String movingSurface(int panelIndex, int id) {
      final panel = assembly.panels[panelIndex];
      if (id < panel.outerTriangles.length) return 'fragment extérieur';
      if (id < panel.outerTriangles.length + panel.innerTriangles.length) {
        return 'fragment intérieur';
      }
      return 'fragment tranche';
    }

    String formatPoint(EggShellPoint3 p) =>
        '(${p.x.toStringAsFixed(1)},'
        '${p.y.toStringAsFixed(1)},'
        '${p.z.toStringAsFixed(1)})';

    String witness({
      required int panelIndex,
      required double seconds,
      required EggBowlCollisionFrame frame,
    }) {
      // Prefer a material penetration; otherwise show the first contact.
      final crossing = frame.hasIntersection;
      final bowlId = crossing
          ? frame.firstIntersectingBowlTriangle
          : frame.firstTouchingBowlTriangle;
      final movingId = crossing
          ? frame.firstIntersectingMovingTriangle
          : frame.firstTouchingMovingTriangle;
      if (bowlId == null || movingId == null) {
        return 'aucune paire observée (ou inspection incomplète)';
      }
      final panel = assembly.panels[panelIndex];
      final triangles = [
        ...panel.outerTriangles,
        ...panel.innerTriangles,
        ...panel.sideTriangles,
      ];
      final points = [
        ...motions[panelIndex].transformAll(panel.outer, seconds),
        ...motions[panelIndex].transformAll(panel.inner, seconds),
      ];
      expect(movingId, inInclusiveRange(0, triangles.length - 1));
      expect(bowlId, inInclusiveRange(0, fixedFaces.length - 1));
      final moving = triangles[movingId];
      final fixed = fixedFaces[bowlId];
      final check = EggTriangleCollision.classify(
        points[moving.a], points[moving.b], points[moving.c],
        fixedVertices[fixed.a], fixedVertices[fixed.b],
        fixedVertices[fixed.c],
      );
      expect(
        check,
        crossing ? EggTriangleContact.intersecting
                 : EggTriangleContact.touching,
      );
      final mobileCentre =
          (points[moving.a] + points[moving.b] + points[moving.c]) *
              (1 / 3);
      final bowlCentre =
          (fixedVertices[fixed.a] + fixedVertices[fixed.b] +
              fixedVertices[fixed.c]) * (1 / 3);
      return '${crossing ? "traversée" : "contact"} : '
          '${movingSurface(panelIndex, movingId)} #$movingId '
          'centre ${formatPoint(mobileCentre)} / '
          '${fixedSurface(bowlId)} #$bowlId '
          'centre ${formatPoint(bowlCentre)}';
    }

    String verdict({
      required bool hasIntersection,
      required bool hasContact,
      required bool complete,
    }) {
      if (hasIntersection) return 'intersection observée';
      if (hasContact) return 'contact observé';
      return complete ? 'échantillon libre' : 'indéterminé (budget)';
    }

    // V11.23: before tuning any release speed, inspect the ACTUAL
    // connected hinge stage from small openings to the 30-degree release.
    // The current hinge sign is selected using a SINGLE extreme probe; its
    // direction cannot certify outward motion of the entire curved panel.
    // Reports are diagnostics, not pass/fail assertions of clearance.
    double dot(EggShellPoint3 a, EggShellPoint3 b) =>
        a.x * b.x + a.y * b.y + a.z * b.z;

    for (final degrees in [1.0, 5.0, 10.0, 20.0, 30.0]) {
      for (var panelIndex = 0; panelIndex < 2; panelIndex++) {
        final panel = assembly.panels[panelIndex];
        final pose = EggPanelHingePose.fromGraph(
          panel: panel,
          region: regions.regions[panelIndex],
          neighbor: regions.regions[1 - panelIndex],
          network: network,
          openingDegrees: degrees,
        );
        var minNormalShift = double.infinity;
        var inwardCount = 0;
        var observedCount = 0;
        for (var vertex = 0; vertex < panel.outer.length; vertex += 19) {
          final original = panel.outer[vertex];
          final displacement = pose.transform(original) - original;
          final shift = dot(displacement, network.model.normalAt(original));
          if (shift < minNormalShift) minNormalShift = shift;
          if (shift < -1e-5) inwardCount++;
          observedCount++;
        }
        final probe = panel.outer[pose.probeIndex];
        final probeOutward = dot(
          pose.transform(probe) - probe,
          network.model.normalAt(probe),
        );
        final trial = EggPanelReleaseMotion.fromHinge(
          panel: panel,
          model: network.model,
          hinge: pose,
          circumferentialAcceleration: 115,
        );
        final frame = EggBowlCollisionInspector(
          bowl: bowl, panel: panel, motion: trial,
        ).inspect(0, maxPairs: 15000);
        expect(frame.seconds, 0);
        debugPrintSynchronously(
          'V11.23 pivot=${degrees.toStringAsFixed(0)}° '
          'panneau=${panelIndex == 0 ? "gauche" : "droit"} '
          'arête=${pose.edgeId} '
          'sondeSortante=${probeOutward.toStringAsFixed(3)} '
          'sommetsEntrants=$inwardCount/$observedCount '
          'minDéplacementNormal=${minNormalShift.toStringAsFixed(3)} '
          'traversées=${frame.intersectingPairs} '
          'contacts=${frame.touchingPairs} '
          'comparaisons=${frame.testedPairs} '
          'fini=${frame.complete}',
        );
      }
    }

    debugPrintSynchronously(
      'V11.27 seuil dégagement gauche='
      '${motions[0].clearanceStartSeconds.toStringAsFixed(3)} s '
      'droite=${motions[1].clearanceStartSeconds.toStringAsFixed(3)} s',
    );

    // t = 0 starts at the LAST attached pose, i.e. 55% on the UI.
    // These are physical seconds since separation, not player seconds.
    for (final seconds in [0.0, .12, .3, .4, .5, .55, .65, .8, 1.0, 1.2, 1.4, 1.6, 1.8, 2.0]) {
      // The narrow initial departure remains inconclusive with 15k pairs.
      // Increase the budget only at that physical instant.
      final bowlBudget = seconds == .12 ? 150000 : 15000;
      final a = againstBowl[0].inspect(seconds, maxPairs: bowlBudget);
      final b = againstBowl[1].inspect(seconds, maxPairs: bowlBudget);
      final pair = betweenPanels.inspect(
        firstSeconds: seconds,
        secondSeconds: seconds,
        maxPairs: 15000,
      );
      expect(a.seconds, seconds);
      expect(b.seconds, seconds);
      expect(pair.firstSeconds, seconds);
      expect(pair.secondSeconds, seconds);
      // Reports describe ONLY sampled instants, not the entire interval.
      // Actual pair counts and completion prevent false clearance claims.
      debugPrintSynchronously('V11.27 t=${seconds.toStringAsFixed(2)} s '
          'gauche/bol: ${verdict(
            hasIntersection: a.hasIntersection,
            hasContact: a.hasContact,
            complete: a.complete,
          )} (${a.testedPairs} paires, fini=${a.complete}, '
          'traversées=${a.intersectingPairs}, contacts=${a.touchingPairs}); '
          'droite/bol: ${verdict(
            hasIntersection: b.hasIntersection,
            hasContact: b.hasContact,
            complete: b.complete,
          )} (${b.testedPairs} paires, fini=${b.complete}, '
          'traversées=${b.intersectingPairs}, contacts=${b.touchingPairs}); '
          'panneaux: ${verdict(
            hasIntersection: pair.hasIntersection,
            hasContact: pair.hasContact,
            complete: pair.complete,
          )} (${pair.testedPairs} paires, fini=${pair.complete})');
      if (a.hasContact) {
        debugPrintSynchronously(
          '  gauche: ${witness(panelIndex: 0, seconds: seconds, frame: a)}',
        );
      }
      if (b.hasContact) {
        debugPrintSynchronously(
          '  droite: ${witness(panelIndex: 1, seconds: seconds, frame: b)}',
        );
      }
      // From 0.30 s onward, the previous V11.26 sampled flight was
      // completely clear. Fail this targeted regression if gravity creates
      // a new intersection at ANY sampled instant. This deliberately does
      // not claim continuous-time collision certification.
      if (seconds >= .3) {
        expect(a.sampledFrameClear, isTrue,
            reason: 'Left panel not clear at t=$seconds s');
        expect(b.sampledFrameClear, isTrue,
            reason: 'Right panel not clear at t=$seconds s');
        expect(pair.sampledFrameClear, isTrue,
            reason: 'Panels not clear at t=$seconds s');
      }
    }
    debugPrintSynchronously('V11.27 : aucun échantillon libre ne certifie '
        "l'absence de collision entre les instants vérifiés.");
    // Second pass: conservative continuous-time checks over the same
    // physical motion. A certifiedClear verdict proves its interval,
    // observedContact is a regression, and inconclusive stays inconclusive.
    // Keep bounded work on the user's workstation: no renderer involved.
    for (final (start, duration) in [
      (0.30, 0.50),
      (0.80, 0.60),
      (1.40, 0.60),
    ]) {
      for (var i = 0; i < 2; i++) {
        final sweep = EggBowlTemporalSweep(
          bowl: bowl,
          panel: assembly.panels[i],
          motion: motions[i],
        ).inspect(
          start: start,
          duration: duration,
          maxDepth: 6,
          maxFrames: 8,
          maxPairsPerFrame: 15000,
        );
        debugPrintSynchronously(
          'V11.27 intervalle ${start.toStringAsFixed(2)}–'
          '${(start + duration).toStringAsFixed(2)} s '
          '${i == 0 ? "gauche" : "droite"}/bol: '
          '${sweep.verdict.name}, segmentsCertifies='
          '${sweep.provenIntervals}, nonResolus='
          '${sweep.unresolvedIntervals}, images='
          '${sweep.sampledFrames}',
        );
        expect(sweep.verdict,
            isNot(EggBowlSweepVerdict.observedContact),
            reason: 'Observed bowl contact in continuous-time '
                'diagnostic of panel $i, interval $start–'
                '${start + duration} seconds');
      }
      final pairSweep = EggPairTemporalSweep(
        first: assembly.panels[0],
        second: assembly.panels[1],
        firstMotion: motions[0],
        secondMotion: motions[1],
      ).inspect(
        firstStart: start,
        secondStart: start,
        duration: duration,
        maxDepth: 6,
        maxFrames: 8,
        maxPairsPerFrame: 15000,
      );
      debugPrintSynchronously(
        'V11.27 intervalle ${start.toStringAsFixed(2)}–'
        '${(start + duration).toStringAsFixed(2)} s '
        'panneaux: ${pairSweep.verdict.name}, '
        'segmentsCertifies=${pairSweep.provenIntervals}, '
        'nonResolus=${pairSweep.unresolvedIntervals}, '
        'images=${pairSweep.sampledFrames}',
      );
      expect(pairSweep.verdict,
          isNot(EggPairSweepVerdict.observedContact),
          reason: 'Observed inter-panel contact in interval '
              '$start–${start + duration} seconds');
    }
    debugPrintSynchronously(
      'V11.27 : les intervalles inconclusifs ne sont pas certifies; '
      'seul certifiedClear exclut tout contact sur son intervalle.',
    );

  });
}
