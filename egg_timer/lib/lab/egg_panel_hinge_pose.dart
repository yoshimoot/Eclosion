import 'dart:math' as math;

import 'egg_fragment_regions.dart';
import 'egg_fracture_network.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

/// V11.11: a rigid, *attached* rotation around one SHORT EXISTING 3D
/// fracture subsegment, with NO translation or free flight.
///
/// The two exact graph sample endpoints are fixed by the hinge axis.
/// An entire curved crack is not a straight rigid axis: other attachments
/// and their release must be modeled separately, never silently welded.
/// Diagnostic pose only, NOT the final timing/rupture mechanics.
class EggPanelHingePose {
  const EggPanelHingePose._({
    required this.edgeId,
    required this.anchorA,
    required this.anchorB,
    required this.axis,
    required this.openingDegrees,
    required this.signedRadians,
    required this.probeIndex,
  });

  final int edgeId;
  final EggShellPoint3 anchorA;
  final EggShellPoint3 anchorB;
  final EggShellPoint3 axis;
  final double openingDegrees;
  final double signedRadians;
  final int probeIndex;

  static double _dot(EggShellPoint3 a, EggShellPoint3 b) =>
      a.x * b.x + a.y * b.y + a.z * b.z;

  static EggShellPoint3 _cross(EggShellPoint3 a, EggShellPoint3 b) =>
      EggShellPoint3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x,
      );

  static EggShellPoint3 _rotate(
    EggShellPoint3 vector, EggShellPoint3 axis, double radians,
  ) {
    final c = math.cos(radians), s = math.sin(radians);
    return vector * c +
        _cross(axis, vector) * s +
        axis * (_dot(axis, vector) * (1 - c));
  }

  // Cache the chosen physical crack edge for each immutable panel. Its
  // selection is geometry-dependent, never based on animation progress.
  static final Expando<EggCrackEdge> _materialHinge =
      Expando<EggCrackEdge>('material lower hinge');

  static EggCrackEdge _chooseMaterialHinge(
    List<EggCrackEdge> candidates,
    EggShellPanelMesh panel,
    EggShellModel model,
  ) {
    // Candidates arrive ordered by their projected horizontality.
    // Keep the previous hinge unless a different REAL crack segment
    // substantially reduces the worst inward normal displacement.
    EggCrackEdge selected = candidates.first;
    var best = double.infinity;
    for (final edge in candidates) {
      if (edge.samples.length < 4) {
        throw StateError('Hinge must use an internal graph subsegment');
      }
      final j = edge.samples.length ~/ 2 - 1;
      final a = edge.samples[j], b = edge.samples[j + 1];
      if (!panel.outer.any((p) => identical(p, a)) ||
          !panel.outer.any((p) => identical(p, b))) {
        throw StateError('Hinge endpoints were lost from the panel rim');
      }
      final span = b - a;
      if (span.length < 1e-8) {
        throw StateError('Degenerate physical material hinge');
      }
      final axis = span.normalized;
      var probeIndex = -1;
      var largestLever = -1.0;
      for (var i = 0; i < panel.outer.length; i++) {
        final v = panel.outer[i] - a;
        final radial = v - axis * _dot(v, axis);
        if (radial.length > largestLever) {
          largestLever = radial.length;
          probeIndex = i;
        }
      }
      if (probeIndex < 0 || largestLever < 1e-6) {
        throw StateError('Panel has no valid lever around hinge');
      }
      final probe = panel.outer[probeIndex];
      final trial = a + _rotate(probe - a, axis, math.pi / 180);
      final probeNormal = model.normalAt(probe);
      final outward = _dot(trial - probe, probeNormal);
      if (outward.abs() < 1e-8) {
        throw StateError('Cannot determine outward hinge direction');
      }
      final sign = outward > 0 ? 1.0 : -1.0;

      double worstInwardAt(double degrees) {
        final radians = sign * degrees * math.pi / 180;
        final c = math.cos(radians), sn = math.sin(radians);
        var inward = 0.0;
        for (final point in panel.outer) {
          final v = point - a;
          final turned = a + v * c + _cross(axis, v) * sn +
              axis * (_dot(axis, v) * (1 - c));
          final projection = _dot(turned - point, model.normalAt(point));
          if (projection < -inward) inward = -projection;
        }
        return inward;
      }

      final penalty = worstInwardAt(30) + 2 * worstInwardAt(5);
      if (best == double.infinity || penalty < best - .02) {
        selected = edge;
        best = penalty;
      }
    }
    return selected;
  }

  /// Select a lower CONNECTION edge joining a panel to the stationary bowl,
  /// never an edge shared between the two panels. These connections cross
  /// the lower lip more horizontally than the long, near-vertical primary
  /// cracks, so an attached panel tips outwards instead of swinging sideways.
  ///
  /// Evaluate all ORIGINAL lower connection edges for inward material
  /// movement. Prefer the former horizontal chord on near-equal clearance.
  /// The actual rotation axis remains one short, real 3D graph subsegment.
  /// No crack vertices, face topology, or attachments are redrawn.
  factory EggPanelHingePose.fromGraph({
    required EggShellPanelMesh panel,
    required EggCandidateShellRegion region,
    required EggCandidateShellRegion neighbor,
    required EggFractureNetwork network,
    required double openingDegrees,
  }) {
    if (!openingDegrees.isFinite ||
        openingDegrees < 0 || openingDegrees > 55) {
      throw ArgumentError.value(openingDegrees, 'openingDegrees');
    }
    if (panel.regionId != region.id) {
      throw ArgumentError.value(panel.regionId, 'panel', 'Region mismatch');
    }
    final shared = region.sharedEdgeIds(neighbor).toSet();
    final candidates = <EggCrackEdge>[
      for (final segment in region.boundary)
        if (!shared.contains(segment.edgeId) &&
            network.edges[segment.edgeId].kind == EggCrackKind.connection)
          network.edges[segment.edgeId],
    ];
    if (candidates.isEmpty) {
      throw StateError('No lower fixed-bowl connection available for a hinge');
    }
    double verticalRatio(EggCrackEdge edge) {
      final first = edge.samples.first, last = edge.samples.last;
      final dx = last.x - first.x, dy = last.y - first.y;
      final projectedLength = math.sqrt(dx * dx + dy * dy);
      if (projectedLength < 1e-8) {
        throw StateError('Degenerate lower connection');
      }
      return dy.abs() / projectedLength;
    }
    candidates.sort((a, b) {
      final byAlignment =
          verticalRatio(a).compareTo(verticalRatio(b));
      return byAlignment != 0 ? byAlignment : a.id.compareTo(b.id);
    });
    final edge = _materialHinge[panel] ??= _chooseMaterialHinge(
      candidates, panel, network.model,
    );
    if (edge.samples.length < 4) {
      throw StateError('Hinge must use an internal graph subsegment');
    }
    final j = edge.samples.length ~/ 2 - 1;
    final a = edge.samples[j], b = edge.samples[j + 1];
    // The tessellator preserves all original graph points by identity.
    if (!panel.outer.any((p) => identical(p, a)) ||
        !panel.outer.any((p) => identical(p, b))) {
      throw StateError('Hinge endpoints were lost from the panel rim');
    }
    final direction = b - a;
    if (direction.length <= 1e-8) {
      throw StateError('Degenerate material hinge');
    }
    final axis = direction.normalized;

    // Choose the point with the greatest perpendicular lever arm and
    // determine which sign of rotation moves it outward from EggShellModel.
    var lever = -1.0;
    var probe = -1;
    for (var i = 0; i < panel.outer.length; i++) {
      final v = panel.outer[i] - a;
      final radial = v - axis * _dot(v, axis);
      if (radial.length > lever) {
        lever = radial.length;
        probe = i;
      }
    }
    if (probe < 0 || lever < 1e-6) {
      throw StateError('Panel has no lever arm around its hinge');
    }
    final probePoint = panel.outer[probe];
    final trial = a + _rotate(
      probePoint - a, axis, math.pi / 180,
    );
    final normal = network.model.normalAt(probePoint);
    final outward = _dot(trial - probePoint, normal);
    if (outward.abs() < 1e-8) {
      throw StateError('Cannot determine outward hinge direction');
    }
    final sign = outward > 0 ? 1.0 : -1.0;
    return EggPanelHingePose._(
      edgeId: edge.id,
      anchorA: a,
      anchorB: b,
      axis: axis,
      openingDegrees: openingDegrees,
      signedRadians: sign * openingDegrees * math.pi / 180,
      probeIndex: probe,
    );
  }

  EggShellPoint3 transform(EggShellPoint3 point) =>
      anchorA + _rotate(point - anchorA, axis, signedRadians);

  EggShellPoint3 rotateNormal(EggShellPoint3 normal) =>
      _rotate(normal, axis, signedRadians);

  List<EggShellPoint3> transformAll(List<EggShellPoint3> points) =>
      List<EggShellPoint3>.unmodifiable([
        for (final point in points) transform(point),
      ]);
}
