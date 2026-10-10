import 'egg_organic_release_seed.dart';
import 'egg_organic_rigid_free_flight.dart';
import 'egg_organic_staged_assembly.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

enum EggOrganicMotionPhase { attached, flying, landed }

/// One real double-sided 3D shell fragment at one deterministic timeline
/// position. Rendering/collision code can consume the SAME vertices.
class EggOrganicMaterialSnapshot {
  const EggOrganicMaterialSnapshot({
    required this.mesh,
    required this.phase,
    required this.outer,
    required this.inner,
  });

  final EggShellPanelMesh mesh;
  final EggOrganicMotionPhase phase;
  final List<EggShellPoint3> outer;
  final List<EggShellPoint3> inner;
}

/// V11.39 — continuity bridge between the V11.35 rupture graph,
/// V11.36 last-attachment hinge and V11.38 actual rigid free flight.
/// It deliberately does NOT render itself or claim that its moving
/// polygons cannot hit the parent panels or the remaining front bowl.
class EggOrganicContinuousPoseCoordinator {
  const EggOrganicContinuousPoseCoordinator._(
    this.staged, this.seeds, this.flights,
  );

  final EggOrganicStagedAssembly staged;
  final List<EggOrganicReleaseSeed> seeds;
  final List<EggOrganicRigidFreeFlight> flights;

  factory EggOrganicContinuousPoseCoordinator.fixed() {
    final staged = EggOrganicStagedAssembly.fixed();
    final seeds = List<EggOrganicReleaseSeed>.unmodifiable([
      for (var i = 0; i < staged.hinges.length; i++)
        EggOrganicReleaseSeed.fromStaged(staged, i),
    ]);
    return EggOrganicContinuousPoseCoordinator._(
      staged, seeds,
      List<EggOrganicRigidFreeFlight>.unmodifiable([
        for (final seed in seeds)
          EggOrganicRigidFreeFlight.fromSeed(seed),
      ]),
    );
  }

  /// Shading counterpart to poseAt: attached normal rotation, then
  /// the identical release hinge pose plus actual post-release spin.
  /// The source normal is always computed on the ORIGINAL material mesh.
  EggShellPoint3 materialNormalAt(
    int childIndex,
    EggShellPoint3 sourceNormal,
    double progress, {
    double afterZeroSeconds = 0,
  }) {
    if (childIndex < 0 || childIndex >= flights.length) {
      throw RangeError.index(childIndex, flights);
    }
    if (!progress.isFinite || progress < 0 || progress > 1 ||
        !afterZeroSeconds.isFinite || afterZeroSeconds < 0 ||
        (progress != 1 && afterZeroSeconds != 0)) {
      throw ArgumentError('Invalid normal lighting timeline');
    }
    final hinge = staged.hinges[childIndex];
    if (progress < seeds[childIndex].releaseProgress) {
      return hinge.normalAttachedAt(sourceNormal, progress);
    }
    final t = flights[childIndex].elapsedAtProgress(progress) +
        afterZeroSeconds;
    return flights[childIndex].rotateNormalAt(
      hinge.releaseNormalOf(sourceNormal), t,
    );
  }

  EggOrganicMaterialSnapshot poseAt(
    int childIndex,
    double progress, {
    double afterZeroSeconds = 0,
  }) {
    if (childIndex < 0 || childIndex >= flights.length) {
      throw RangeError.index(childIndex, flights);
    }
    if (!progress.isFinite || progress < 0 || progress > 1 ||
        !afterZeroSeconds.isFinite || afterZeroSeconds < 0 ||
        (progress != 1 && afterZeroSeconds != 0)) {
      throw ArgumentError('Invalid countdown or post-zero film time');
    }
    final mesh = staged.meshes.children[childIndex];
    final seed = seeds[childIndex];
    final flight = flights[childIndex];

    if (progress < seed.releaseProgress) {
      final held = staged.heldPoseAt(childIndex, progress)!;
      return EggOrganicMaterialSnapshot(
        mesh: mesh,
        phase: EggOrganicMotionPhase.attached,
        outer: held.outer,
        inner: held.inner,
      );
    }
    final seconds = flight.elapsedAtProgress(progress) +
        afterZeroSeconds;
    if (seconds > 3) {
      throw ArgumentError('Organic film exceeds proven three-second range');
    }
    final onGround = flight.impactSeconds != null &&
        seconds >= flight.impactSeconds!;
    return EggOrganicMaterialSnapshot(
      mesh: mesh,
      phase: onGround ? EggOrganicMotionPhase.landed
          : EggOrganicMotionPhase.flying,
      outer: flight.transformAll(seed.outer, seconds),
      inner: flight.transformAll(seed.inner, seconds),
    );
  }
}
