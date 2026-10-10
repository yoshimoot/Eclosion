import 'dart:math' as math;

import 'egg_fracture_network.dart';
import 'egg_organic_attachment_plan.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

/// V11.36 — actual rigid 3D pose about the LAST material attachment.
///
/// Before the two side bonds break, the child remains precisely in its
/// original bowl position. Then its existing hinge segment holds TWO exact
/// shell points while the entire curved double-sided solid tips outward.
/// At hinge release, the pose becomes the initial state of FUTURE free
/// flight. No detachment/flight is synthesized here and nothing is painted.
class EggOrganicAttachedHingePose {
  EggOrganicAttachedHingePose._({
    required this.child,
    required this.mesh,
    required this.hingeEdge,
    required this.anchorA,
    required this.anchorB,
    required this.axis,
    required this.openingStartProgress,
    required this.releaseProgress,
    required this.signedMaxRadians,
  });

  final EggOrganicChildAttachmentPlan child;
  final EggShellPanelMesh mesh;
  final EggCrackEdge hingeEdge;
  final EggShellPoint3 anchorA;
  final EggShellPoint3 anchorB;
  final EggShellPoint3 axis;
  final double openingStartProgress;
  final double releaseProgress;
  final double signedMaxRadians;

  static EggShellPoint3 _cross(EggShellPoint3 a, EggShellPoint3 b) =>
      EggShellPoint3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x,
      );

  static double _dot(EggShellPoint3 a, EggShellPoint3 b) =>
      a.x * b.x + a.y * b.y + a.z * b.z;

  static EggShellPoint3 _rotate(
    EggShellPoint3 v, EggShellPoint3 axis, double angle,
  ) {
    final c = math.cos(angle), s = math.sin(angle);
    return v * c + _cross(axis, v) * s +
        axis * (_dot(axis, v) * (1 - c));
  }

  factory EggOrganicAttachedHingePose.build({
    required EggOrganicChildAttachmentPlan child,
    required EggShellPanelMesh mesh,
    required EggFractureNetwork graph,
    double maximumOpeningDegrees = 26,
  }) {
    if (!maximumOpeningDegrees.isFinite ||
        maximumOpeningDegrees <= 0 || maximumOpeningDegrees > 45) {
      throw ArgumentError.value(
        maximumOpeningDegrees, 'maximumOpeningDegrees',
      );
    }
    if (child.childId != mesh.regionId) {
      throw ArgumentError('Organic motion belongs to the wrong child mesh');
    }
    final hingeEdge = graph.edges[child.hinge.edgeId];
    if (hingeEdge.samples.length < 3) {
      throw StateError('Organic hinge has no physical short subsegment');
    }
    final left = hingeEdge.samples.length ~/ 2 - 1;
    final anchorA = hingeEdge.samples[left];
    final anchorB = hingeEdge.samples[left + 1];
    if (!mesh.outer.any((v) => identical(v, anchorA)) ||
        !mesh.outer.any((v) => identical(v, anchorB))) {
      throw StateError('Hinge anchors must be exact material rim vertices');
    }
    final span = anchorB - anchorA;
    if (span.length <= 1e-8) {
      throw StateError('Degenerate 3D hinge material segment');
    }
    final axis = span.normalized;
    EggShellPoint3? probe;
    var lever = 0.0;
    for (final v in mesh.outer) {
      final offset = v - anchorA;
      final radial = offset - axis * _dot(axis, offset);
      if (radial.length > lever) {
        lever = radial.length;
        probe = v;
      }
    }
    if (probe == null || lever < 1e-5) {
      throw StateError('No rigid lever around child hinge');
    }
    // Select the normal-outwards bending sign by the actual shell model.
    // No hardcoded left/right screen offset or child-index direction.
    final trial = anchorA + _rotate(
      probe - anchorA, axis, math.pi / 180,
    );
    final outward = _dot(trial - probe, graph.model.normalAt(probe));
    if (outward.abs() < 1e-9) {
      throw StateError('Ambiguous material outward hinge sign');
    }
    final sides = child.attachments.where(
      (e) => e.kind == EggOrganicAttachmentKind.bowlCrack,
    ).toList();
    if (sides.length != 2) {
      throw StateError('Opening needs two released side attachments');
    }
    final start = math.max(
      sides[0].ruptureProgress, sides[1].ruptureProgress,
    );
    final end = child.hinge.ruptureProgress;
    if (start >= end || end > 1) {
      throw StateError('Material hinge must remain after side cracks');
    }
    return EggOrganicAttachedHingePose._(
      child: child,
      mesh: mesh,
      hingeEdge: hingeEdge,
      anchorA: anchorA,
      anchorB: anchorB,
      axis: axis,
      openingStartProgress: start,
      releaseProgress: end,
      signedMaxRadians: (outward > 0 ? 1 : -1) *
          maximumOpeningDegrees * math.pi / 180,
    );
  }

  void _checkAttachedTime(double progress) {
    if (!progress.isFinite || progress < 0 || progress > 1) {
      throw ArgumentError.value(progress, 'progress');
    }
    if (progress > releaseProgress) {
      throw StateError('Cannot show an attached hinge AFTER material release');
    }
  }

  double angleAt(double progress) {
    _checkAttachedTime(progress);
    if (progress <= openingStartProgress) return 0;
    final u = ((progress - openingStartProgress) /
        (releaseProgress - openingStartProgress)).clamp(0.0, 1.0).toDouble();
    // Smooth angular velocity at initial bending and at actual release.
    return signedMaxRadians * u * u * (3 - 2 * u);
  }

  EggShellPoint3 transformAttached(EggShellPoint3 point, double progress) {
    final radians = angleAt(progress);
    if (radians == 0) return point;
    return anchorA + _rotate(point - anchorA, axis, radians);
  }

  List<EggShellPoint3> transformAllAttached(
    List<EggShellPoint3> materialVertices, double progress,
  ) {
    final radians = angleAt(progress);
    if (radians == 0) {
      return List<EggShellPoint3>.unmodifiable(materialVertices);
    }
    return List<EggShellPoint3>.unmodifiable([
      for (final v in materialVertices)
        anchorA + _rotate(v - anchorA, axis, radians),
    ]);
  }

  /// Rotate an exterior material normal with the SAME rigid hinge matrix
  /// as the real two-sided shell, without translating or scaling normals.
  EggShellPoint3 releaseNormalOf(EggShellPoint3 normal) =>
      _rotate(normal, axis, signedMaxRadians).normalized;

  /// Frozen last-attached coordinates, suitable as a continuous INPUT to a
  /// future collision-tested free-flight motor. Not a flight trajectory.
  EggShellPoint3 releasePositionOf(EggShellPoint3 materialVertex) =>
      transformAttached(materialVertex, releaseProgress);
}
