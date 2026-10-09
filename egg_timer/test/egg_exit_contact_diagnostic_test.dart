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
import 'package:flutter_test/flutter_test.dart';

/// V11.21 read-only diagnosis of the EXACT V11.19/20 Chrome exit trajectory.
/// No movement, geometry, drawing or collision response is modified.
/// A sampled clear frame NEVER certifies clearance between samples.
void main() {
  test('V11.21: report contact of the actual Chrome release path', () {
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
      // Printing explicit budgets guards against false clearance claims.
      print('V11.21 t=${seconds.toStringAsFixed(2)} s '
          'gauche/bol: ${verdict(
            hasIntersection: a.hasIntersection,
            hasContact: a.hasContact,
            complete: a.complete,
          )} (${a.testedPairs} paires); '
          'droite/bol: ${verdict(
            hasIntersection: b.hasIntersection,
            hasContact: b.hasContact,
            complete: b.complete,
          )} (${b.testedPairs} paires); '
          'panneaux: ${verdict(
            hasIntersection: pair.hasIntersection,
            hasContact: pair.hasContact,
            complete: pair.complete,
          )} (${pair.testedPairs} paires)');
    }
    print('V11.21 : aucun échantillon libre ne certifie '
        "l'absence de collision entre les instants vérifiés.");
  });
}
