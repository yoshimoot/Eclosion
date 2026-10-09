import 'dart:math' as math;

import 'egg_panel_hinge_pose.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

/// V11.13: deterministic rigid motion AFTER a shell panel is released.
///
/// At t=0 every vertex is exactly where EggPanelHingePose left it.
/// Subsequently a push along the rotated outward material normal is combined
/// with rotation around the panel's OWN surface-area centroid. No new shell
/// faces, geometry masks, shrinkage, fake translations, gravity or animation
/// clock are introduced. Attachment failure is an INPUT, not simulated here.
///
/// This is a kinematic model; it does NOT yet guarantee collision clearance
/// against the fixed bowl or other moving pieces.
class EggPanelReleaseMotion {
  const EggPanelReleaseMotion._({
    required this.hinge,
    required this.materialCenter,
    required this.releaseCenter,
    required this.outward,
    required this.initialSpeed,
    required this.outwardAcceleration,
    required this.spinDegreesPerSecond,
    required this.spinSign,
  });

  /// The hinge pose is frozen at the instant its last attachment releases.
  final EggPanelHingePose hinge;

  /// Physical area-weighted midpoint of the exterior curved shell patch,
  /// before the hinged pose.
  final EggShellPoint3 materialCenter;

  /// Same point after the final attached rotation; rigid free spin origin.
  final EggShellPoint3 releaseCenter;

  /// Outward direction from the actual shell surface, after hinge rotation.
  final EggShellPoint3 outward;

  /// Model units per second, applied along outward. Diagnostic constants.
  final double initialSpeed;
  final double outwardAcceleration;
  final double spinDegreesPerSecond;
  final double spinSign;

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

  factory EggPanelReleaseMotion.fromHinge({
    required EggShellPanelMesh panel,
    required EggPanelHingePose hinge,
    required EggShellModel model,
    double initialSpeed = 12,
    double outwardAcceleration = 35,
    double spinDegreesPerSecond = 28,
  }) {
    if (!initialSpeed.isFinite || initialSpeed < 0 ||
        !outwardAcceleration.isFinite || outwardAcceleration < 0 ||
        !spinDegreesPerSecond.isFinite || spinDegreesPerSecond < 0 ||
        (initialSpeed == 0 && outwardAcceleration == 0)) {
      throw ArgumentError('Release rates must be finite and outward');
    }
    if (!hinge.openingDegrees.isFinite ||
        hinge.openingDegrees <= 0 ||
        hinge.signedRadians.abs() <= 1e-10) {
      throw ArgumentError.value(
        hinge.openingDegrees, 'hinge', 'Release needs an opened hinge',
      );
    }
    if (panel.outer.length != panel.inner.length ||
        panel.outerTriangles.isEmpty ||
        panel.regionId.isEmpty ||
        !panel.outer.any((p) => identical(p, hinge.anchorA)) ||
        !panel.outer.any((p) => identical(p, hinge.anchorB))) {
      throw StateError('Hinge does not belong to the complete source panel');
    }
    var weightedCenter = const EggShellPoint3(0, 0, 0);
    var weightedNormal = const EggShellPoint3(0, 0, 0);
    var totalArea = 0.0;
    for (final face in panel.outerTriangles) {
      final a = panel.outer[face.a];
      final b = panel.outer[face.b];
      final c = panel.outer[face.c];
      final cross = _cross(b - a, c - a);
      final area = cross.length / 2;
      if (!area.isFinite || area <= 1e-14) {
        throw StateError('Degenerate material triangle in release panel');
      }
      final centroid = (a + b + c) * (1 / 3);
      weightedCenter = weightedCenter + centroid * area;
      weightedNormal = weightedNormal +
          model.normalAt(centroid) * area;
      totalArea += area;
    }
    if (!totalArea.isFinite || totalArea <= 0 ||
        weightedNormal.length < 1e-8) {
      throw StateError('Release cannot determine outward shell direction');
    }
    final center = weightedCenter * (1 / totalArea);
    final direction = hinge.rotateNormal(
      weightedNormal.normalized,
    ).normalized;
    return EggPanelReleaseMotion._(
      hinge: hinge,
      materialCenter: center,
      releaseCenter: hinge.transform(center),
      outward: direction,
      initialSpeed: initialSpeed,
      outwardAcceleration: outwardAcceleration,
      spinDegreesPerSecond: spinDegreesPerSecond,
      spinSign: hinge.signedRadians > 0 ? 1 : -1,
    );
  }

  static void _checkTime(double seconds) {
    // A bounded local diagnostic after release, not a timer duration.
    if (!seconds.isFinite || seconds < 0 || seconds > 2) {
      throw ArgumentError.value(seconds, 'seconds');
    }
  }

  double outwardDistanceAt(double seconds) {
    _checkTime(seconds);
    return initialSpeed * seconds +
        outwardAcceleration * seconds * seconds / 2;
  }

  double spinRadiansAt(double seconds) {
    _checkTime(seconds);
    return spinSign * spinDegreesPerSecond * math.pi / 180 * seconds;
  }

  EggShellPoint3 centerAt(double seconds) =>
      releaseCenter + outward * outwardDistanceAt(seconds);

  /// The exact hinged state at t=0; later, a rigid body around its
  /// release-time centre plus a translation along the outward normal.
  EggShellPoint3 transform(EggShellPoint3 point, double seconds) {
    final angle = spinRadiansAt(seconds);
    final atRelease = hinge.transform(point);
    return centerAt(seconds) +
        _rotate(atRelease - releaseCenter, hinge.axis, angle);
  }

  EggShellPoint3 rotateNormal(EggShellPoint3 normal, double seconds) =>
      _rotate(
        hinge.rotateNormal(normal), hinge.axis, spinRadiansAt(seconds),
      );

  List<EggShellPoint3> transformAll(
    List<EggShellPoint3> points, double seconds,
  ) {
    _checkTime(seconds);
    return List<EggShellPoint3>.unmodifiable([
      for (final point in points) transform(point, seconds),
    ]);
  }
}
