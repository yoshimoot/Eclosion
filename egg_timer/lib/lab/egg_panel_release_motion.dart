import 'dart:math' as math;

import 'egg_panel_hinge_pose.dart';
import 'egg_shell_fragment_mesh.dart';
import 'egg_shell_model.dart';

/// V11.13: deterministic rigid motion AFTER a shell panel is released.
///
/// At t=0 every vertex is exactly where EggPanelHingePose left it.
/// Subsequently a push along the rotated outward material normal is combined
/// with rotation around the panel's OWN surface-area centroid. No new shell
/// faces, geometry masks, shrinkage or fake translations are introduced.
/// Clock progression is defined outside this rigid material transform. Attachment failure is an INPUT, not simulated here.
/// An optional circumferential impulse (V11.19 diagnostic only) adds a real
/// 3D tangential acceleration, with zero extra velocity at release.
/// V11.25 optionally postpones that impulse and the material spin until
/// outward travel reaches a specified physical shell clearance. The default
/// (zero clearance) retains the exact V11.13/V11.19 kinematics.
/// V11.27 optionally adds true vertical world-space acceleration (positive
/// y is downward), beginning only after the shell clearance phase.
///
/// This is a kinematic model; it does NOT yet guarantee collision clearance
/// against the fixed bowl or other moving pieces.
class EggPanelReleaseMotion {
  const EggPanelReleaseMotion._({
    required this.hinge,
    required this.materialCenter,
    required this.releaseCenter,
    required this.outward,
    required this.circumferential,
    required this.circumferentialAcceleration,
    required this.gravityAcceleration,
    required this.floorY,
    required this.floorImpactSeconds,
    required this.minimumOutwardClearance,
    required this.clearanceStartSeconds,
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

  /// Signed circumferential unit tangent to the egg's material surface,
  /// perpendicular to the average outward normal. Zero when unused.
  final EggShellPoint3 circumferential;

  /// Additional sideways acceleration in model units/s². Default: zero.
  final double circumferentialAcceleration;

  /// Optional downward acceleration in the fixed world/model Y axis.
  /// Zero leaves all existing V11.13–V11.26 callers unchanged.
  final double gravityAcceleration;

  /// Optional fixed 3D ground plane (+Y points downward). Legacy callers
  /// leave it null, retaining exactly their ballistic V11.29 trajectory.
  final double? floorY;

  /// First contact of ANY real material vertex with that plane.
  /// Null if there is no floor, or no contact in the two-second window.
  final double? floorImpactSeconds;

  /// Model units of outward travel required before the panel begins to
  /// spin and travel circumferentially. Zero preserves legacy behavior.
  final double minimumOutwardClearance;

  /// Physical time when the early radial-only departure is complete.
  final double clearanceStartSeconds;

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
    double circumferentialAcceleration = 0,
    double gravityAcceleration = 0,
    double? floorY,
    double minimumOutwardClearance = 0,
  }) {
    if (!initialSpeed.isFinite || initialSpeed < 0 ||
        !outwardAcceleration.isFinite || outwardAcceleration < 0 ||
        !spinDegreesPerSecond.isFinite || spinDegreesPerSecond < 0 ||
        !circumferentialAcceleration.isFinite ||
        circumferentialAcceleration < 0 ||
        !gravityAcceleration.isFinite || gravityAcceleration < 0 ||
        (floorY != null && !floorY.isFinite) ||
        !minimumOutwardClearance.isFinite ||
        minimumOutwardClearance < 0 ||
        (initialSpeed == 0 && outwardAcceleration == 0)) {
      throw ArgumentError('Release rates must be finite and outward');
    }
    if (minimumOutwardClearance >
        initialSpeed * 2 + outwardAcceleration * 2) {
      throw ArgumentError('Clearance cannot be reached within two seconds');
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
    // Material circumference around the egg's vertical axis. The direction
    // is fixed by the actual centroid's side, never by a screen-space shift
    // or by the panel's index. Rotate with the hinged shell and remove its
    // normal component, so the added motion remains tangential in 3D.
    var tangent = const EggShellPoint3(0, 0, 0);
    if (circumferentialAcceleration > 0) {
      if (center.x.abs() < 1e-6) {
        throw StateError('Cannot choose a side for a centred panel');
      }
      final sign = center.x < 0 ? -1.0 : 1.0;
      final alongRing = EggShellPoint3(center.z, 0, -center.x) * sign;
      final turned = hinge.rotateNormal(alongRing);
      final inPlane = turned - direction * _dot(turned, direction);
      if (inPlane.length < 1e-8) {
        throw StateError('Degenerate circumferential material tangent');
      }
      tangent = inPlane.normalized;
    }
    final free = EggPanelReleaseMotion._(
      hinge: hinge,
      materialCenter: center,
      releaseCenter: hinge.transform(center),
      outward: direction,
      circumferential: tangent,
      circumferentialAcceleration: circumferentialAcceleration,
      gravityAcceleration: gravityAcceleration,
      floorY: null,
      floorImpactSeconds: null,
      minimumOutwardClearance: minimumOutwardClearance,
      // Positive root of v0*t + (a*t*t)/2 = physical clearance.
      // Rationalized form avoids cancellation for tiny clearances.
      clearanceStartSeconds: minimumOutwardClearance == 0
          ? 0
          : (2 * minimumOutwardClearance) /
              (initialSpeed +
                  math.sqrt(
                    initialSpeed * initialSpeed +
                        2 * outwardAcceleration *
                            minimumOutwardClearance,
                  )),
      initialSpeed: initialSpeed,
      outwardAcceleration: outwardAcceleration,
      spinDegreesPerSecond: spinDegreesPerSecond,
      spinSign: hinge.signedRadians > 0 ? 1 : -1,
    );
    final ground = floorY;
    if (ground == null) return free;

    // First physical vertex contact, not the centre or a projected contour.
    // Sweep the SAME rigid mesh and solve the first crossing by bisection.
    // Material coordinates after hinge do not depend on elapsed time.
    // Precompute them ONCE: contact search needs many time samples but must
    // not redo the costly hinge transform for every vertex at every sample.
    final hingedOffsets = [
      for (final p in [...panel.outer, ...panel.inner])
        hinge.transform(p) - free.releaseCenter,
    ];
    double lowestMaterialClearance(double t) {
      var maxY = double.negativeInfinity;
      final center = free.centerAt(t);
      final angle = free.spinRadiansAt(t);
      final c = math.cos(angle), si = math.sin(angle);
      final axis = hinge.axis;
      for (final offset in hingedOffsets) {
        // Rodrigues' rigid rotation; only the world Y component is needed.
        final crossY = axis.z * offset.x - axis.x * offset.z;
        final projection = _dot(axis, offset);
        final y = center.y + offset.y * c + crossY * si +
            axis.y * projection * (1 - c);
        maxY = math.max(maxY, y);
      }
      return ground - maxY;
    }
    if (lowestMaterialClearance(0) <= 0) {
      throw StateError('A released panel cannot start inside the ground');
    }
    double? impact;
    var previous = 0.0;
    for (var tick = 1; tick <= 200; tick++) {
      final now = tick / 100;
      if (lowestMaterialClearance(now) <= 0) {
        var lo = previous, hi = now;
        for (var iteration = 0; iteration < 30; iteration++) {
          final mid = (lo + hi) / 2;
          if (lowestMaterialClearance(mid) > 0) {
            lo = mid;
          } else {
            hi = mid;
          }
        }
        impact = hi;
        break;
      }
      previous = now;
    }
    return EggPanelReleaseMotion._(
      hinge: hinge,
      materialCenter: free.materialCenter,
      releaseCenter: free.releaseCenter,
      outward: free.outward,
      circumferential: free.circumferential,
      circumferentialAcceleration: free.circumferentialAcceleration,
      gravityAcceleration: free.gravityAcceleration,
      floorY: ground,
      floorImpactSeconds: impact,
      minimumOutwardClearance: free.minimumOutwardClearance,
      clearanceStartSeconds: free.clearanceStartSeconds,
      initialSpeed: free.initialSpeed,
      outwardAcceleration: free.outwardAcceleration,
      spinDegreesPerSecond: free.spinDegreesPerSecond,
      spinSign: free.spinSign,
    );
  }

  // Shared with conservative continuous-time collision inspectors.
  // The initial radial movement is immediate, whereas tangential travel,
  // gravity and angular spin start only at the actual release clearance.
  // Using the original full-time acceleration for all three components
  // overestimates early swept envelopes and creates false broad-phase hits.
  static const double spinRampSeconds = .15;

  /// A conservative upper bound for the WORLD-space linear speed of the
  /// material centre at a specified physical time. Acceleration components
  /// add by the triangle inequality; no unsafe cancellation is assumed.
  double linearSpeedUpperBoundAt(double seconds) {
    _checkTime(seconds);
    final elapsed = math.max(0.0, seconds - clearanceStartSeconds);
    return initialSpeed + outwardAcceleration * seconds +
        (circumferentialAcceleration + gravityAcceleration) * elapsed;
  }

  /// A conservative upper bound on the rigid body's angular speed.
  /// The exact quadratic spin ramp in [spinRadiansAt] has instantaneous
  /// angular speed omega * elapsed/spinRampSeconds until full rate.
  double angularSpeedUpperBoundAt(double seconds) {
    _checkTime(seconds);
    final rated = spinDegreesPerSecond * math.pi / 180;
    if (clearanceStartSeconds == 0) return rated;
    final elapsed = math.max(0.0, seconds - clearanceStartSeconds);
    return rated * math.min(1.0, elapsed / spinRampSeconds);
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
    // An inelastic impact arrests the angular spin without changing
    // shell geometry. The pre-impact orientation is continuous.
    final impact = floorImpactSeconds;
    if (impact != null && seconds >= impact) {
      return _freeSpinRadiansAt(impact);
    }
    return _freeSpinRadiansAt(seconds);
  }

  double _freeSpinRadiansAt(double seconds) {
    // The zero-clearance path must remain identical to V11.13.
    if (clearanceStartSeconds == 0) {
      return spinSign * spinDegreesPerSecond * math.pi / 180 * seconds;
    }
    final elapsed = math.max(0.0, seconds - clearanceStartSeconds);
    // No jump in angular velocity when the cleared panel starts to turn:
    // omega grows linearly to the existing rated speed over 0.15 s.
    final spinClock = elapsed < spinRampSeconds
        ? elapsed * elapsed / (2 * spinRampSeconds)
        : elapsed - spinRampSeconds / 2;
    return spinSign * spinDegreesPerSecond * math.pi / 180 * spinClock;
  }

  double circumferentialDistanceAt(double seconds) {
    _checkTime(seconds);
    final elapsed = math.max(0.0, seconds - clearanceStartSeconds);
    return circumferentialAcceleration * elapsed * elapsed / 2;
  }

  /// The fall is postponed until radial clearance of the centre. This
  /// avoids immediate downward travel against the still-attached cut rim.
  /// Its displacement and velocity are exactly zero at the threshold.
  double fallDistanceAt(double seconds) {
    _checkTime(seconds);
    final elapsed = math.max(0.0, seconds - clearanceStartSeconds);
    return gravityAcceleration * elapsed * elapsed / 2;
  }

  EggShellPoint3 _freeCenterAt(double seconds) =>
      releaseCenter +
      outward * outwardDistanceAt(seconds) +
      circumferential * circumferentialDistanceAt(seconds) +
      EggShellPoint3(0, fallDistanceAt(seconds), 0);

  EggShellPoint3 centerAt(double seconds) {
    _checkTime(seconds);
    final impact = floorImpactSeconds;
    if (impact == null || seconds <= impact) return _freeCenterAt(seconds);

    // Inelastic floor reaction: the real material contact point stays at
    // floorY, with no vertical penetration or change in shell orientation.
    // A short frictional slide dissipates the existing horizontal velocity
    // continuously instead of freezing the shell's XY screen coordinates.
    const slideDamping = 8.0;
    final elapsed = seconds - impact;
    final weight = (1 - math.exp(-slideDamping * elapsed)) / slideDamping;
    final radialSpeed = initialSpeed + outwardAcceleration * impact;
    final lateralTime = math.max(0.0, impact - clearanceStartSeconds);
    final lateralSpeed = circumferentialAcceleration * lateralTime;
    final velocity = outward * radialSpeed +
        circumferential * lateralSpeed;
    final hit = _freeCenterAt(impact);
    return EggShellPoint3(
      hit.x + velocity.x * weight,
      hit.y,
      hit.z + velocity.z * weight,
    );
  }

  /// The exact hinged state at t=0; later, a rigid body around its
  /// release-time centre plus outward and optional 3D tangential motion.
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
