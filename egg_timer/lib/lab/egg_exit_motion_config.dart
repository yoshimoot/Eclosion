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
  // V11.29: a single physical gravity for BOTH panels. At 70 the lowest
  // material points still floated well above the egg's base at 100%.
  // The shell meshes, release impulse and rigid spin remain unchanged.
  // The floor is a diagnostic reference plane, not yet a contact solver.
  static const double gravityAcceleration = 135;
  static const double clearanceThicknesses = 3;

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
      );
}
