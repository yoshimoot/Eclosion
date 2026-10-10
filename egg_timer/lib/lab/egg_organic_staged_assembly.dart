import 'egg_organic_attachment_plan.dart';
import 'egg_organic_attached_hinge_pose.dart';
import 'egg_organic_partitioned_meshes.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

/// V11.36 — a read-only, material-identical preparation of three organic
/// attachments and their first rigid hinge poses.
///
/// The existing animated two-panel mode is NOT modified. A future free
/// flight + collision model will be required before these pieces may be
/// painted during or after detachment.
class EggOrganicStagedAssembly {
  const EggOrganicStagedAssembly._(
    this.meshes, this.attachments, this.hinges,
  );

  final EggOrganicPartitionedStaticMeshes meshes;
  final EggOrganicAttachmentPlan attachments;
  final List<EggOrganicAttachedHingePose> hinges;

  factory EggOrganicStagedAssembly.fixed() {
    final meshes = EggOrganicPartitionedStaticMeshes.build();
    // IMPORTANT: feed the *same* partition instance to the coordinator,
    // so hinge samples are identical to the material rim vertices.
    final attachments = EggOrganicAttachmentPlan.fixed(
      partition: meshes.partition,
    );
    final hinges = <EggOrganicAttachedHingePose>[
      for (var i = 0; i < meshes.children.length; i++)
        EggOrganicAttachedHingePose.build(
          child: attachments.children[i],
          mesh: meshes.children[i],
          graph: meshes.partition.organic.draft,
        ),
    ];
    return EggOrganicStagedAssembly._(
      meshes,
      attachments,
      List<EggOrganicAttachedHingePose>.unmodifiable(hinges),
    );
  }

  /// An isolated attached shell pose. Returns null if its physical hinge
  /// has broken: returning the last pose indefinitely would look like a
  /// floating fragment and would disguise an unimplemented free flight.
  ///
  /// No caller should blend it with parent geometry or the fixed bowl;
  /// the static partition must replace their old overlapping surfaces.
  EggOrganicHeldFragmentPose? heldPoseAt(
    int childIndex, double progress,
  ) {
    if (childIndex < 0 || childIndex >= hinges.length) {
      throw RangeError.index(childIndex, hinges);
    }
    final child = attachments.children[childIndex];
    final state = child.stateAt(progress);
    final pose = hinges[childIndex];
    if (state.fullyReleased) return null;
    final mesh = meshes.children[childIndex];
    return EggOrganicHeldFragmentPose(
      mesh: mesh,
      state: state,
      outer: pose.transformAllAttached(mesh.outer, progress),
      inner: pose.transformAllAttached(mesh.inner, progress),
    );
  }
}

class EggOrganicHeldFragmentPose {
  const EggOrganicHeldFragmentPose({
    required this.mesh,
    required this.state,
    required this.outer,
    required this.inner,
  });

  final EggShellPanelMesh mesh;
  final EggOrganicAttachmentState state;
  final List<EggShellPoint3> outer;
  final List<EggShellPoint3> inner;
}
