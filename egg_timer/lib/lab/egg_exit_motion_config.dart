import 'egg_panel_hinge_pose.dart';
import 'egg_panel_release_motion.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

/// The single source of parameters for the experimental Chrome "Sortie"
/// movement and all of its diagnostic collision/framing tests.
///
/// Production callers of [EggPanelReleaseMotion.fromHinge] retain the
/// backwards-compatible, zero-gravity and zero-clearance defaults.
/// This class does NOT imply collision-free continuous trajectories.
final class EggExitMotionConfig {
  const EggExitMotionConfig._();

  static const double circumferentialAcceleration = 115;
  // V11.30: both panels use the same gravity up to actual first ground
  // contact. The rigid-body collision response prevents penetration.
  // The additional acceleration is active only in this preview.
  static const double gravityAcceleration = 220;
  static const double clearanceThicknesses = 3;

  // V11.31: after first contact, rotate the SAME 3D solid away from the
  // egg around a world-horizontal axis. No geometry edits or 2D warping.
  static const double groundSettlingRadians = 1.0;
  static const double groundSettlingDuration = .45;

  static EggPanelReleaseMotion build({
    required EggShellPanelMesh panel,
    required EggPanelHingePose hinge,
    required EggShellModel model,
  }) =>
      EggPanelReleaseMotion.fromHinge(
        panel: panel,
        hinge: hinge,
        model: model,
        circumferentialAcceleration: circumferentialAcceleration,
        minimumOutwardClearance: clearanceThicknesses * panel.thickness,
        gravityAcceleration: gravityAcceleration,
        // The physical ground lies below the validated egg silhouette.
        // Match the plane already used for the original shadow projection.
        floorY: model.halfHeight + 8,
        settlingRadians: groundSettlingRadians,
        settlingDuration: groundSettlingDuration,
      );
}
