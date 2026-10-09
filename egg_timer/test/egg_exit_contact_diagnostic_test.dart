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

/// V11.21 read-only diagnosis of the EXACT V11.19/20 Chrome exit trajectory.
/// No movement, geometry, drawing or collision response is modified.
/// A sampled clear frame NEVER certifies clearance between samples.
void main() {
  test('V11.22: locate the first physical 3D contact per panel', () {
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
          circumferentialAcceleration: 115,
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

    // t = 0 starts at the LAST attached pose, i.e. 55% on the UI.
    // These are physical seconds since separation, not player seconds.
    for (final seconds in [0.0, .12, .3, .55, .8, 1.0, 1.2]) {
      final a = againstBowl[0].inspect(seconds, maxPairs: 15000);
      final b = againstBowl[1].inspect(seconds, maxPairs: 15000);
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
      debugPrintSynchronously('V11.22 t=${seconds.toStringAsFixed(2)} s '
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
    }
    debugPrintSynchronously('V11.22 : aucun échantillon libre ne certifie '
        "l'absence de collision entre les instants vérifiés.");
  });
}
